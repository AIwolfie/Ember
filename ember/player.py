r"""
player.py
PlaybackCore owns the queue, the media player and the thread pools.

Flow for one track:
    play(song)  ->  LoadJob (dedicated playback pool)  ->  QMediaPlayer.setSource
                \->  RadioJob (background pool)        ->  queue grows behind it

Stream resolution and queue building are executed on isolated thread pools so audio
playback starts the moment the stream is ready without waiting on recommendations.
"""

from __future__ import annotations

import logging
import math
import re
from typing import Any, Callable, Iterable, List, Optional, Set

from PyQt6.QtCore import QObject, QThreadPool, QTimer, QUrl, pyqtSignal
from PyQt6.QtMultimedia import QAudioOutput, QMediaPlayer

from .cache import AudioDiskCache
from .catalog import CatalogSource
from .config import (
    DEFAULT_VOLUME,
    RADIO_DEPTH,
    SEEK_MS_BACKSTEP,
    SWITCH_TIMEOUT_MS,
)
from .jobs import CacheTrackJob, LinkJob, LoadJob, RadioJob
from .models import Song
from .stream import StreamResolver

log = logging.getLogger(__name__)

# Every playback lifecycle event goes to this one logger. Filtering
# `ember.playback` is now enough to see a whole session's transitions in order.
playback_log = logging.getLogger("ember.playback")

MAX_AUTO_SKIP = 3  # consecutive dead tracks before we stop advancing
MAX_QUEUE_SIZE = 200  # prevent infinite queue growth from auto-radio

# A resolved stream URL is a working credential for its lifetime, so it must
# never reach a log record. The backend hands one back inside its own error
# strings — the failing URL *is* the message on a ResourceError — so redaction
# happens here rather than trusting every call site to strip it.
_SIGNED_URL_RE = re.compile(r"https?://[^\s\"']*googlevideo\.com[^\s\"']*")


def _redact(text: str) -> str:
    """Replace any signed stream URL embedded in `text` with a placeholder."""
    return _SIGNED_URL_RE.sub("<stream-url>", text)


class PlaybackCore(QObject):
    """Core engine controlling audio playback, thread pools, and the track queue."""

    song_changed = pyqtSignal(object)        # Song now loading / playing
    cursor_changed = pyqtSignal(int)         # index inside the queue
    queue_changed = pyqtSignal(list)         # whole queue replaced or extended
    playing_changed = pyqtSignal(bool)
    progress_changed = pyqtSignal(int)       # ms
    length_changed = pyqtSignal(int)         # ms
    loading_changed = pyqtSignal(bool)
    notice = pyqtSignal(str)                 # short human line for the status chip
    repeat_mode_changed = pyqtSignal(str)    # 'off', 'all', 'one'
    rate_changed = pyqtSignal(float)         # playback rate factor (1.0, 1.25, etc.)

    def __init__(
        self,
        catalog: CatalogSource,
        resolver: StreamResolver,
        disk_cache: Optional[AudioDiskCache] = None,
        parent: Optional[QObject] = None,
    ) -> None:
        super().__init__(parent)
        self.catalog = catalog
        self.resolver = resolver
        self.disk_cache = disk_cache
        if self.disk_cache and not self.resolver.disk_cache:
            self.resolver.disk_cache = self.disk_cache

        # Dedicated playback thread pool: audio resolution NEVER waits on background radio/art
        self.playback_pool = QThreadPool(self)
        self.playback_pool.setMaxThreadCount(2)

        # General background thread pool for recommendation graph & artwork
        self.pool = QThreadPool(self)
        self.pool.setMaxThreadCount(6)

        self.player = QMediaPlayer(self)
        self.output = QAudioOutput(self)
        self.player.setAudioOutput(self.output)

        self._raw_volume = DEFAULT_VOLUME
        self._normalize_volume = False
        self._apply_volume()

        self.queue: List[Song] = []
        self.cursor = -1
        self.auto_queue = True
        self.repeat_mode: str = "off"  # "off", "all", "one"
        self.playback_rate: float = 1.0
        self._fade_timer: Optional[QTimer] = None
        self._pre_fade_volume: Optional[int] = None

        self._wanted: Optional[str] = None
        # Identity of the source currently handed to the media player, and of the
        # one whose EndOfMedia we already acted on. Qt reports status for the
        # outgoing source mid-swap, so identity — not a timing flag — is what
        # separates a real track end from a stale one.
        self._loaded_id: Optional[str] = None
        self._ended_id: Optional[str] = None
        self._switching = False
        self._extending = False
        self._advance_after_extend = False
        self._radio_seed: Optional[str] = None
        self._failed_id: Optional[str] = None
        self._error_streak = 0
        self._active_load_job: Optional[LoadJob] = None
        self._active_radio_job: Optional[RadioJob] = None
        self._saved_position_ms: int = 0

        # Monotonic counter bumped once per play(). Every lifecycle log line
        # carries it, so a status arriving for generation 7 after generation 9
        # started is visible by eye instead of inferred from timestamps.
        self._generation = 0
        # Tracks the extractor will never serve (age gate, members-only, deleted).
        # Retrying these burns the skip budget on the same track forever.
        self._dead_tracks: Set[str] = set()
        # Tracks already given their one fresh re-resolve after a 403/410 on a
        # signed URL. Without a bound, "refresh the stream" is an infinite loop.
        self._retried_tracks: Set[str] = set()
        # Next-track prefetch, keyed on video_id so a stale result is dropped.
        self._prefetched: Optional[tuple] = None
        # A setSource that never opens would otherwise leave _switching True and
        # the UI spinning with no timeout and no user-visible way out.
        self._switch_watchdog: Optional[QTimer] = None

        self.player.positionChanged.connect(self._relay_progress)
        self.player.durationChanged.connect(self._relay_length)
        self.player.playbackStateChanged.connect(self._relay_state)
        self.player.mediaStatusChanged.connect(self._relay_media_status)
        self.player.errorOccurred.connect(self._relay_error)

    # --------------------------------------------------------------- lifecycle
    def _lifecycle(self, event: str, track_id: Optional[str] = None, **extra: Any) -> None:
        """One line per lifecycle event, always tagged with the generation.

        These used to be bare log calls at four levels under four loggers, which
        is why the original "tracks change on their own" report took an hour of
        log archaeology to diagnose.
        """
        parts = [f"gen={self._generation}", f"event={event}"]
        if track_id:
            parts.append(f"track={track_id}")
        parts.append(f"wanted={self._wanted}")
        parts.append(f"loaded={self._loaded_id}")
        parts.append(f"switching={self._switching}")
        for key, value in extra.items():
            parts.append(f"{key}={value}")
        playback_log.info(" ".join(parts))

    def _reset_source_state(self) -> None:
        """The one place the source-identity fields are cleared.

        play(), _on_stream_failed() and _relay_error() each used to hand-clear
        overlapping subsets of these, which is exactly how they drift apart and
        produce the next bug of this class.

        _prefetched is deliberately NOT touched here: it describes a *future*
        track, and clearing it would throw away the resolution that makes the
        next transition instant — the one case prefetching exists for.
        """
        self._loaded_id = None
        self._ended_id = None
        self._failed_id = None
        self._switching = False

    def _arm_switch_watchdog(self) -> None:
        """Fail a setSource that never opens, instead of spinning forever."""
        if self._switch_watchdog is not None:
            self._switch_watchdog.stop()
        timer = QTimer(self)
        timer.setSingleShot(True)
        timer.setInterval(SWITCH_TIMEOUT_MS)
        timer.timeout.connect(self._on_switch_timeout)
        self._switch_watchdog = timer
        timer.start()

    def _disarm_switch_watchdog(self) -> None:
        if self._switch_watchdog is not None:
            self._switch_watchdog.stop()
            self._switch_watchdog.deleteLater()
            self._switch_watchdog = None

    def _settle_switch(self) -> None:
        """The new source is live: stop distrusting status, disarm the watchdog."""
        self._switching = False
        self._disarm_switch_watchdog()

    def _on_switch_timeout(self) -> None:
        """The backend never opened the source we handed it. Move on."""
        self._switch_watchdog = None
        if not self._switching:
            return
        self._lifecycle("switch_timeout")
        self._switching = False
        self._loaded_id = None
        self.loading_changed.emit(False)
        self.notice.emit("that track wouldn't open")
        self._error_streak += 1
        if self._error_streak <= MAX_AUTO_SKIP and self.cursor + 1 < len(self.queue):
            self.forward(force=True)
        else:
            self._error_streak = 0

    # ---------------------------------------------------------------- prefetch
    def _prefetch_next(self) -> None:
        """Resolve the following track while this one plays.

        Resolution latency is why track transitions feel broken; every streaming
        player hides it behind the currently-playing track.
        """
        if not self.auto_queue:
            return
        if self.cursor + 1 >= len(self.queue):
            return
        nxt = self.queue[self.cursor + 1]
        if nxt.video_id in self._dead_tracks:
            return
        if self._prefetched is not None:
            if self._prefetched[0] == nxt.video_id:
                return  # already resolved, or already in flight
            # A result for a track we have since skipped past would otherwise
            # occupy the slot forever and starve every later prefetch.
            self._prefetched = None
        self._prefetched = (nxt.video_id, None)
        job = LoadJob(nxt, self.resolver)
        job.signals.ready.connect(self._on_prefetch_ready)
        job.signals.failed.connect(self._on_prefetch_failed)
        self.playback_pool.start(job)

    def _on_prefetch_ready(self, song: Song, url: str) -> None:
        if self._prefetched is None or self._prefetched[0] != song.video_id:
            return
        self._prefetched = (song.video_id, url)
        self._lifecycle("prefetch_ready", song.video_id)

    def _on_prefetch_failed(self, song: Song, message: str, permanent: bool) -> None:
        if self._prefetched is not None and self._prefetched[0] == song.video_id:
            self._prefetched = None
        if permanent:
            self._dead_tracks.add(song.video_id)
        log.debug("prefetch failed for %s: %s", song.video_id, _redact(message))

    def _take_prefetch(self, song: Song) -> Optional[str]:
        """Consume the prefetched URL for this track, if one is ready."""
        if self._prefetched is None or self._prefetched[0] != song.video_id:
            return None
        url = self._prefetched[1]
        if url is None:
            return None  # still resolving; it lands via _on_prefetch_ready
        self._prefetched = None
        return url

    # ------------------------------------------------------------------ state
    @property
    def current(self) -> Optional[Song]:
        """Currently selected Song in the queue, if valid."""
        if 0 <= self.cursor < len(self.queue):
            return self.queue[self.cursor]
        return None

    def index_of(self, video_id: str) -> int:
        """Find the queue index of a video_id, or -1 if not present."""
        for index, song in enumerate(self.queue):
            if song.video_id == video_id:
                return index
        return -1

    # ------------------------------------------------------------------- queue
    def enqueue(self, song: Optional[Song]) -> None:
        """Append a single song to the upcoming queue."""
        if not song:
            return
        self.queue.append(song)
        self.queue_changed.emit(self.queue)

    def enqueue_many(self, songs: List[Song]) -> None:
        """Append multiple songs to the upcoming queue."""
        if not songs:
            return
        self.queue.extend(songs)
        self.queue_changed.emit(self.queue)

    def adopt(self, songs: List[Song], start: int = 0) -> None:
        """Replace the queue wholesale (used for search results) and start playing."""
        if not songs:
            return
        start = max(0, min(start, len(songs) - 1))
        self.queue = list(songs)
        self.cursor = start
        self.queue_changed.emit(self.queue)
        self.cursor_changed.emit(start)
        self.play(self.queue[start], expand=True)

    def play(self, song: Optional[Song], expand: Optional[bool] = None) -> None:
        """Queue and begin stream resolution for a given song."""
        if song is None:
            return
        if expand is None:
            expand = self.auto_queue

        slot = self.index_of(song.video_id)
        if slot < 0:
            self.queue = [song]
            self.cursor = 0
            self.queue_changed.emit(self.queue)
            self.cursor_changed.emit(0)
        elif slot != self.cursor:
            self.cursor = slot
            self.cursor_changed.emit(slot)

        self._generation += 1
        self._wanted = song.video_id
        # An explicit play is the user asking to try this track again, so the
        # remembered failure and the one-shot retry both reset here.
        self._dead_tracks.discard(song.video_id)
        self._retried_tracks.discard(song.video_id)
        # Whatever the player still holds belongs to the previous track. Drop it
        # through the one shared reset, then re-arm the swap guard — this used to
        # leave _loaded_id pointing at the old track and _switching wedged True.
        self._reset_source_state()
        self._saved_position_ms = 0
        self._switching = True
        self._lifecycle("play", song.video_id, index=self.cursor)
        self.loading_changed.emit(True)
        self.song_changed.emit(song)

        # Immediate off-thread stream resolution on isolated pool. Stale jobs are
        # dropped by the _wanted check in the slots — never clear() the pool here:
        # it deletes the in-flight job's signal carrier mid-emit, which wedges
        # _switching True and freezes the player for good.
        self._arm_switch_watchdog()
        self._start_load(song)
        if expand:
            # Parallel background recommendation fetch
            self._start_radio(song.video_id)

    def play_at(self, index: int) -> None:
        """Jump to and play the track at specified queue index."""
        if not 0 <= index < len(self.queue):
            return
        self.cursor = index
        self.cursor_changed.emit(index)
        self.play(self.queue[index], expand=False)

    # ----------------------------------------------------------- audio devices
    def available_audio_devices(self) -> List[str]:
        """List descriptions of available physical audio output devices."""
        try:
            from PyQt6.QtMultimedia import QMediaDevices
            return [dev.description() for dev in QMediaDevices.audioOutputs()]
        except Exception:
            return []

    def current_audio_device_name(self) -> str:
        """Name of active audio output device."""
        try:
            dev = self.output.device()
            return dev.description() if dev else "Default"
        except Exception:
            return "Default"

    def set_audio_device(self, device_name: str) -> bool:
        """Hot-swap the active audio output device on the fly without stopping playback."""
        try:
            from PyQt6.QtMultimedia import QMediaDevices
            for dev in QMediaDevices.audioOutputs():
                if dev.description() == device_name:
                    self.output.setDevice(dev)
                    log.info("Switched audio output device to %r", device_name)
                    return True
        except Exception as exc:
            log.warning("Failed to switch audio output device %r: %s", device_name, exc)
        return False

    def play_local_file(self, file_path: str) -> None:
        """Play a local audio file directly with bit-perfect lossless fidelity."""
        from pathlib import Path
        p = Path(file_path)
        if not p.is_file():
            return
        video_id = f"local_{p.stem}"
        song = Song(
            video_id=video_id,
            title=p.stem,
            artist="Local Lossless Audio",
            duration="",
            artwork_url="",
        )
        self.queue = [song]
        self.cursor = 0
        self.queue_changed.emit(self.queue)
        self.cursor_changed.emit(0)

        self._loaded_id = song.video_id
        self._wanted = song.video_id
        self._switching = False
        self.song_changed.emit(song)
        self.player.setSource(QUrl.fromLocalFile(str(p.resolve())))
        self.player.play()
        self.playing_changed.emit(True)
        log.info("Playing local audio file: %s", p)

    # --------------------------------------------------------------- transport
    @property
    def is_playing(self) -> bool:
        """True if the media player is currently playing."""
        return self.player.playbackState() == QMediaPlayer.PlaybackState.PlayingState

    def pause(self) -> None:
        """Pause audio playback."""
        self.player.pause()

    def resume(self) -> None:
        """Resume playback if paused, or start if stopped with current track."""
        state = self.player.playbackState()
        if state == QMediaPlayer.PlaybackState.PausedState:
            self.player.play()
        elif state == QMediaPlayer.PlaybackState.StoppedState:
            if self.current is not None:
                self.play(self.current, expand=False)
            elif self.queue:
                self.play_at(0)

    def toggle(self) -> None:
        """Toggle play/pause state."""
        state = self.player.playbackState()
        if state == QMediaPlayer.PlaybackState.PlayingState:
            self.player.pause()
        elif state == QMediaPlayer.PlaybackState.PausedState:
            self.player.play()
        else:
            current = self.current
            if current is not None:
                self.play(current, expand=False)
            elif self.queue:
                self.play_at(0)

    def _first_playable(self, indices: Iterable[int]) -> Optional[int]:
        """First index in `indices` whose track is not a known-dead one.

        Without this, auto-advance steps straight onto a track that already
        failed permanently and burns the whole skip budget re-resolving it —
        the loop that made one age-gated video look like a runaway player.
        """
        for index in indices:
            if 0 <= index < len(self.queue):
                if self.queue[index].video_id not in self._dead_tracks:
                    return index
        return None

    def forward(self, force: bool = False) -> None:
        """Skip to next track or fetch more from recommendation graph if at tail."""
        if not force and self.repeat_mode == "one" and self.current is not None:
            self.player.setPosition(0)
            self.player.play()
            return
        ahead = self._first_playable(range(self.cursor + 1, len(self.queue)))
        if ahead is not None:
            self.play_at(ahead)
            return
        if self.repeat_mode == "all" and self.queue:
            wrap = self._first_playable(range(len(self.queue)))
            if wrap is not None:
                self.play_at(wrap)
                return
        if not self.queue or self._extending:
            return

        # Tail of the queue: ask the recommendation graph for more, then advance.
        self._extending = True
        self._advance_after_extend = True
        self.notice.emit("finding more like this")
        self._start_radio(self.queue[-1].video_id, force=True)

    def back(self) -> None:
        """Go back to previous track or restart current track if > backstep threshold."""
        if self.player.position() > SEEK_MS_BACKSTEP:
            self.player.setPosition(0)
            return
        if self.cursor > 0:
            self.play_at(self.cursor - 1)
        elif self.repeat_mode == "all" and self.queue:
            self.play_at(len(self.queue) - 1)
        else:
            self.player.setPosition(0)

    # ------------------------------------------------------------- modes & tuning
    def set_repeat_mode(self, mode: str) -> None:
        """Set repeat mode ('off', 'all', 'one')."""
        if mode not in ("off", "all", "one"):
            mode = "off"
        self.repeat_mode = mode
        self.repeat_mode_changed.emit(mode)
        if mode == "one":
            self.notice.emit("repeat one on")
        elif mode == "all":
            self.notice.emit("repeat all on")
        else:
            self.notice.emit("repeat off")

    def cycle_repeat_mode(self) -> str:
        """Cycle repeat mode: off -> all -> one -> off."""
        order = ["off", "all", "one"]
        next_idx = (order.index(self.repeat_mode) + 1) % len(order)
        self.set_repeat_mode(order[next_idx])
        return self.repeat_mode

    def shuffle_upcoming(self) -> None:
        """Shuffle remaining unplayed tracks in place without losing history."""
        if self.cursor + 2 >= len(self.queue):
            self.notice.emit("no upcoming tracks to shuffle")
            return
        import random
        upcoming = self.queue[self.cursor + 1 :]
        random.shuffle(upcoming)
        self.queue = self.queue[: self.cursor + 1] + upcoming
        self.queue_changed.emit(self.queue)
        self.notice.emit("upcoming queue shuffled")

    def set_playback_rate(self, rate: float) -> None:
        """Set playback rate factor (0.5x - 2.5x)."""
        rate = max(0.5, min(2.5, float(rate)))
        self.playback_rate = rate
        self.player.setPlaybackRate(rate)
        self.rate_changed.emit(rate)
        self.notice.emit(f"speed {rate:g}x")

    def fade_out_and_pause(
        self,
        duration_ms: int = 60000,
        on_done: Optional[Callable[[], None]] = None,
    ) -> None:
        """Smoothly attenuate volume to zero over duration_ms using cosine easing, then pause."""
        if self._fade_timer is not None:
            self._fade_timer.stop()
            self._fade_timer.deleteLater()
            self._fade_timer = None

        if not self.is_playing:
            if on_done:
                on_done()
            return

        self._pre_fade_volume = self._raw_volume
        initial_vol = float(self._raw_volume)
        interval_ms = 50
        total_steps = max(10, duration_ms // interval_ms)
        elapsed_steps = 0

        timer = QTimer(self)
        self._fade_timer = timer

        def _step_fade() -> None:
            nonlocal elapsed_steps
            elapsed_steps += 1
            t = min(1.0, elapsed_steps / total_steps)
            # Smooth cosine easing curve: factor moves gently from 1.0 down to 0.0
            factor = 0.5 * (1.0 + math.cos(math.pi * t))
            new_vol = initial_vol * factor

            if t >= 1.0 or new_vol <= 0.5:
                timer.stop()
                timer.deleteLater()
                self._fade_timer = None
                self.pause()
                # Restore original volume setpoint for next session
                if self._pre_fade_volume is not None:
                    self.set_volume(self._pre_fade_volume)
                    self._pre_fade_volume = None
                if on_done:
                    on_done()
            else:
                self.set_volume(int(round(new_vol)))

        timer.timeout.connect(_step_fade)
        timer.start(interval_ms)

    def cancel_fade(self) -> None:
        """Cancel an ongoing sleep fade-out and restore original volume."""
        if self._fade_timer is not None:
            self._fade_timer.stop()
            self._fade_timer.deleteLater()
            self._fade_timer = None
            if self._pre_fade_volume is not None:
                self.set_volume(self._pre_fade_volume)
                self._pre_fade_volume = None

    def seek(self, position_ms: int) -> None:
        """Seek to position in milliseconds."""
        self.player.setPosition(max(0, int(position_ms)))

    def _apply_volume(self) -> None:
        """Compute final output volume factoring in volume normalization."""
        factor = 0.88 if self._normalize_volume else 1.0
        effective = (self._raw_volume / 100.0) * factor
        self.output.setVolume(max(0.0, min(1.0, effective)))

    def set_volume(self, percent: int) -> None:
        """Set volume percentage (0-100)."""
        self._raw_volume = max(0, min(100, int(percent)))
        self._apply_volume()

    def volume(self) -> int:
        """Get current volume percentage."""
        return self._raw_volume

    def set_normalize_volume(self, enabled: bool) -> None:
        """Toggle volume normalization to prevent loud track spikes."""
        self._normalize_volume = bool(enabled)
        self._apply_volume()

    @property
    def normalize_volume(self) -> bool:
        return self._normalize_volume

    def set_auto_queue(self, enabled: bool) -> None:
        """Toggle endless queue auto-expansion."""
        self.auto_queue = bool(enabled)

    # ------------------------------------------------------------- entry points
    def open_link(self, url: str) -> None:
        """Resolve a pasted URL into a Song, then play it like anything else."""
        self.notice.emit("reading that link")
        job = LinkJob(self.resolver, url)
        job.signals.ready.connect(self._on_link_song)
        job.signals.failed.connect(self._on_link_failed)
        self.pool.start(job)  # general pool, NOT playback_pool — don't block audio

    # ------------------------------------------------------------------ loading
    def _start_load(self, song: Song) -> None:
        if self._active_load_job is not None:
            self._active_load_job.cancel()
            self._active_load_job = None
        prefetched = self._take_prefetch(song)
        if prefetched:
            # Already resolved while the previous track played — skip the job.
            self._lifecycle("prefetch_hit", song.video_id)
            self._on_stream_ready(song, prefetched)
            return
        job = LoadJob(song, self.resolver)
        self._active_load_job = job
        job.signals.ready.connect(self._on_stream_ready)
        job.signals.failed.connect(self._on_stream_failed)
        self.playback_pool.start(job)

    def _start_radio(self, seed_id: str, force: bool = False) -> None:
        if not force and self._radio_seed == seed_id:
            return
        if self._active_radio_job is not None:
            self._active_radio_job.cancel()
            self._active_radio_job = None
        self._radio_seed = seed_id
        job = RadioJob(self.catalog, seed_id, RADIO_DEPTH)
        self._active_radio_job = job
        job.signals.ready.connect(self._on_radio_ready)
        job.signals.failed.connect(self._on_radio_failed)
        self.pool.start(job)

    # ------------------------------------------------------------------- slots
    def _on_stream_ready(self, song: Song, url: str) -> None:
        if self._active_load_job is not None and getattr(self._active_load_job, "song", None) == song:
            self._active_load_job = None
        if song.video_id != self._wanted:
            return  # user already moved on
        song.stream_url = url
        self._failed_id = None
        self._loaded_id = song.video_id
        self._ended_id = None
        self._lifecycle("stream_ready", song.video_id)

        # Stop before swapping sources. Setting a source while the previous one
        # is still playing lets the backend emit EndOfMedia for the outgoing
        # track, and the status relay reads that as "the new track finished" —
        # which skipped tracks and restarted others at 0:00.
        self.player.stop()
        self.player.setSource(QUrl(url))
        self.player.play()
        if self._saved_position_ms > 3000:
            restore_pos = self._saved_position_ms
            self._saved_position_ms = 0
            self.player.setPosition(restore_pos)
            log.info("resumed playback at preserved position %d ms", restore_pos)

        # _switching deliberately stays True: setSource is asynchronous, so the
        # backend's own LoadedMedia / BufferedMedia burst arrives after this
        # returns. _relay_media_status clears the flag once the new source is
        # genuinely live, which is the first point stale status cannot arrive.
        self.loading_changed.emit(False)

        # Background persistent audio caching
        if self.disk_cache and (url.startswith("http://") or url.startswith("https://")):
            cache_job = CacheTrackJob(self.disk_cache, song.video_id, url)
            self.pool.start(cache_job)

    def _on_stream_failed(self, song: Song, message: str, permanent: bool = False) -> None:
        if self._active_load_job is not None and getattr(self._active_load_job, "song", None) == song:
            self._active_load_job = None
        if song.video_id != self._wanted:
            return
        # Nothing of ours is on the player any more. One shared reset instead of
        # clearing the same fields by hand in three different places.
        self._reset_source_state()
        self._disarm_switch_watchdog()
        self.loading_changed.emit(False)
        self.notice.emit("skipping unavailable track")
        self._lifecycle("resolve_failed", song.video_id, permanent=permanent)
        log.warning("playback aborted for %s: %s", song.video_id, _redact(message))

        # An age gate or a deleted video will fail identically forever. Remember
        # it so auto-advance steps over the track instead of re-resolving it.
        if permanent:
            self._dead_tracks.add(song.video_id)

        # Same skip budget as a backend failure: a run of unresolvable tracks
        # must not walk the entire queue. force=True so repeat-one cannot pin us
        # to the track that just failed to resolve.
        self._error_streak += 1
        if self._error_streak <= MAX_AUTO_SKIP and self.cursor + 1 < len(self.queue):
            self.forward(force=True)
            return
        self._error_streak = 0

    def _on_radio_ready(self, seed_id: str, songs: list) -> None:
        self._active_radio_job = None
        self._extending = False
        # Ignore results from outdated radio jobs
        if seed_id != self._radio_seed:
            self._advance_after_extend = False
            return
        current = self.current
        if current is None or current.video_id != seed_id or not songs:
            self._advance_after_extend = False
            return

        known = {song.video_id for song in self.queue}
        fresh = [song for song in songs if song.video_id not in known]
        if fresh:
            self.queue.extend(fresh)

            # Prune already-played tracks when queue exceeds cap
            if len(self.queue) > MAX_QUEUE_SIZE and self.cursor > 10:
                trim = self.cursor - 5
                self.queue = self.queue[trim:]
                self.cursor -= trim
                self.cursor_changed.emit(self.cursor)

            self.queue_changed.emit(self.queue)

        if self._advance_after_extend:
            self._advance_after_extend = False
            if self.cursor + 1 < len(self.queue):
                self.play_at(self.cursor + 1)
            elif self.queue and self.auto_queue:
                self.play_at(0)

    def _on_radio_failed(self, seed_id: str, message: str) -> None:
        self._active_radio_job = None
        self._extending = False
        log.debug("radio unavailable for %s: %s", seed_id, message)
        if self._advance_after_extend:
            self._advance_after_extend = False
            if self.cursor + 1 < len(self.queue):
                self.play_at(self.cursor + 1)
            elif self.queue and self.auto_queue:
                log.info("radio failed; looping queue to keep music playing")
                self.play_at(0)

    def _on_link_song(self, song: Song) -> None:
        self.adopt([song], 0)

    def _on_link_failed(self, message: str) -> None:
        self.notice.emit("that link didn't work")
        log.warning("link playback failed: %s", message)

    # ------------------------------------------------------------ media relays
    def _relay_progress(self, position_ms: int) -> None:
        if self._switching and position_ms > 0 and self._loaded_id == self._wanted:
            self._settle_switch()
        self.progress_changed.emit(int(position_ms))

    def _relay_length(self, duration_ms: int) -> None:
        self.length_changed.emit(int(duration_ms))

    def _relay_state(self, state: QMediaPlayer.PlaybackState) -> None:
        # A track that actually reaches PlayingState clears the skip budget.
        # Resetting it on stream-ready instead would defeat MAX_AUTO_SKIP
        # entirely — every resolved URL looked like a fresh start.
        if state == QMediaPlayer.PlaybackState.PlayingState:
            self._error_streak = 0
            # Reaching PlayingState proves the new source is live even if the
            # backend skipped its LoadedMedia announcement, so the switch flag
            # can never wedge True and swallow a legitimate end-of-track.
            if self._loaded_id is not None and self._loaded_id == self._wanted:
                self._settle_switch()
        elif self._switching and state == QMediaPlayer.PlaybackState.StoppedState:
            # The stop() we issued ourselves before setSource. Relaying it as
            # "paused" flickers the disc and the play icon mid-swap, so the UI
            # keeps showing the state the user asked for until the new source
            # is live.
            return
        self.playing_changed.emit(state == QMediaPlayer.PlaybackState.PlayingState)

    def _resume_from_stall(self) -> None:
        """Attempt auto-recovery if playback stalled on network buffer underrun."""
        if (
            self._wanted is not None
            and self.is_playing
            and self.player.mediaStatus() == QMediaPlayer.MediaStatus.StalledMedia
        ):
            log.info("auto-recovering stalled audio stream")
            self.player.play()

    def _relay_media_status(self, status: QMediaPlayer.MediaStatus) -> None:
        if status in (
            QMediaPlayer.MediaStatus.LoadedMedia,
            QMediaPlayer.MediaStatus.BufferedMedia,
            QMediaPlayer.MediaStatus.BufferingMedia,
        ):
            # The source swap is done and the backend's status stream has caught
            # up with it. Only from here on is an EndOfMedia trustworthy.
            if self._loaded_id is not None and self._loaded_id == self._wanted:
                self._settle_switch()
                # This track is live, so there is time to resolve the next one
                # behind it. This is the only place prefetch is kicked off: a
                # resolve for a track that never started playing is wasted work.
                if status in (
                    QMediaPlayer.MediaStatus.LoadedMedia,
                    QMediaPlayer.MediaStatus.BufferedMedia,
                ):
                    self._prefetch_next()
            return

        if status == QMediaPlayer.MediaStatus.StalledMedia:
            log.warning("playback stalled due to buffer underrun — scheduling auto-recovery")
            self.notice.emit("buffering...")
            QTimer.singleShot(1500, self._resume_from_stall)
            return

        if status != QMediaPlayer.MediaStatus.EndOfMedia:
            return

        # EndOfMedia is not by itself a reliable "the track ended" signal: Qt
        # also emits it for the outgoing media mid-swap and for sources that
        # never loaded at all. Acting on those is what made tracks jump on
        # their own and restart at 0:00 unprompted.
        if self._switching:
            return
        if self._loaded_id is None or self._loaded_id != self._wanted:
            return  # stale status for a source we have already replaced
        if self._ended_id == self._loaded_id:
            return  # already acted on this track — a duplicate must not skip two

        self._ended_id = self._loaded_id
        self._lifecycle("end_of_media", self._ended_id)
        if self.repeat_mode == "one" and self.current is not None:
            self.player.setPosition(0)
            self.player.play()
            self._ended_id = None  # same source again — let it end a second time
            return
        if self.repeat_mode == "all" and self.cursor + 1 >= len(self.queue) and self.queue:
            self.play_at(0)
            return
        self.forward(force=True)

    def _relay_error(self, error: QMediaPlayer.Error, message: str) -> None:
        # Guard on track identity, not the source URL. Every resolve mints a new
        # signed URL, so comparing strings never matched, the guard failed open,
        # and the backend walked the queue retrying the same dead track — that is
        # what produced the 1607-error burst in the log.
        # An error reported for a source we already swapped out is noise from
        # the outgoing track. Tearing down playback for those stopped music that
        # was playing perfectly well.
        if self._loaded_id is not None and self._loaded_id != self._wanted:
            return
        if self._wanted is not None and self._failed_id == self._wanted:
            return  # already handled this track's failure
        self._failed_id = self._wanted
        self._lifecycle(
            "error",
            self._wanted,
            error=str(error).rsplit(".", 1)[-1],
            detail=_redact(message),
        )
        log.warning("media player error (%s): %s", error, _redact(message))

        # Preserve playback position before stopping so stream refresh doesn't restart from 0:00
        cur_pos = self.player.position()
        if cur_pos > 3000:
            self._saved_position_ms = cur_pos

        self.player.stop()
        # Nothing of ours is loaded now, so the EndOfMedia that stop() provokes
        # for the torn-down source is ignored rather than advancing a second time.
        self._reset_source_state()
        self.loading_changed.emit(False)
        self._disarm_switch_watchdog()

        # A 403/410 means the signed URL expired; the track is fine. Invalidate
        # the cached URL and re-resolve exactly once. Without the one-shot guard
        # the backend re-reports the same error on every retry and the skip
        # budget walks the queue — which is what made one expired URL look like a
        # runaway loop.
        wanted = self._wanted
        if wanted and wanted not in self._retried_tracks:
            self._retried_tracks.add(wanted)
            self.resolver.cache.invalidate(wanted)
            song = self.current
            if song is not None and song.video_id == wanted:
                self._switching = True
                self._lifecycle("stream_refresh", wanted)
                self.notice.emit("refreshing that stream")
                self.loading_changed.emit(True)
                self._arm_switch_watchdog()
                self._start_load(song)
                return

        self._error_streak += 1
        if self._error_streak <= MAX_AUTO_SKIP and self.cursor + 1 < len(self.queue):
            self.notice.emit("skipping a dead track")
            self.forward(force=True)
            return

        self._error_streak = 0
        if self.queue:
            self.notice.emit("playback hiccup")
        # Re-mark the failure: _reset_source_state() cleared it above, and if the
        # backend reports this same dead source again we must not re-run this
        # handler and reset the skip budget with it.
        self._failed_id = wanted