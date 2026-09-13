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
from typing import Any, Callable, List, Optional

from PyQt6.QtCore import QObject, QThreadPool, QTimer, QUrl, pyqtSignal
from PyQt6.QtMultimedia import QAudioOutput, QMediaPlayer

from .catalog import CatalogSource
from .config import DEFAULT_VOLUME, RADIO_DEPTH, SEEK_MS_BACKSTEP
from .jobs import LinkJob, LoadJob, RadioJob
from .models import Song
from .stream import StreamResolver

log = logging.getLogger(__name__)

MAX_AUTO_SKIP = 3  # consecutive dead tracks before we stop advancing
MAX_QUEUE_SIZE = 200  # prevent infinite queue growth from auto-radio


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
        parent: Optional[QObject] = None,
    ) -> None:
        super().__init__(parent)
        self.catalog = catalog
        self.resolver = resolver

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
        self._switching = False
        self._extending = False
        self._advance_after_extend = False
        self._radio_seed: Optional[str] = None
        self._failed_id: Optional[str] = None
        self._error_streak = 0

        self.player.positionChanged.connect(self._relay_progress)
        self.player.durationChanged.connect(self._relay_length)
        self.player.playbackStateChanged.connect(self._relay_state)
        self.player.mediaStatusChanged.connect(self._relay_media_status)
        self.player.errorOccurred.connect(self._relay_error)

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

        self._wanted = song.video_id
        self._failed_id = None  # allow manual retries of failed tracks
        self._switching = True
        self.loading_changed.emit(True)
        self.song_changed.emit(song)

        # Immediate off-thread stream resolution on isolated pool. Stale jobs are
        # dropped by the _wanted check in the slots — never clear() the pool here:
        # it deletes the in-flight job's signal carrier mid-emit, which wedges
        # _switching True and freezes the player for good.
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

    def forward(self, force: bool = False) -> None:
        """Skip to next track or fetch more from recommendation graph if at tail."""
        if not force and self.repeat_mode == "one" and self.current is not None:
            self.player.setPosition(0)
            self.player.play()
            return
        if self.cursor + 1 < len(self.queue):
            self.play_at(self.cursor + 1)
            return
        if self.repeat_mode == "all" and self.queue:
            self.play_at(0)
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
        duration_ms: int = 15000,
        on_done: Optional[Callable[[], None]] = None,
    ) -> None:
        """Smoothly attenuate volume to zero over duration_ms and pause playback."""
        if self._fade_timer is not None:
            self._fade_timer.stop()
            self._fade_timer.deleteLater()
            self._fade_timer = None

        if not self.is_playing:
            if on_done:
                on_done()
            return

        self._pre_fade_volume = self._raw_volume
        steps = max(10, duration_ms // 100)
        interval = max(20, duration_ms // steps)
        step_dec = self._raw_volume / steps
        current_vol = float(self._raw_volume)

        timer = QTimer(self)
        self._fade_timer = timer

        def _step_fade() -> None:
            nonlocal current_vol
            current_vol -= step_dec
            if current_vol <= 0.5:
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
                self.set_volume(int(current_vol))

        timer.timeout.connect(_step_fade)
        timer.start(interval)

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
        job = LoadJob(song, self.resolver)
        job.signals.ready.connect(self._on_stream_ready)
        job.signals.failed.connect(self._on_stream_failed)
        self.playback_pool.start(job)

    def _start_radio(self, seed_id: str, force: bool = False) -> None:
        if not force and self._radio_seed == seed_id:
            return
        self._radio_seed = seed_id
        job = RadioJob(self.catalog, seed_id, RADIO_DEPTH)
        job.signals.ready.connect(self._on_radio_ready)
        job.signals.failed.connect(self._on_radio_failed)
        self.pool.start(job)

    # ------------------------------------------------------------------- slots
    def _on_stream_ready(self, song: Song, url: str) -> None:
        if song.video_id != self._wanted:
            return  # user already moved on
        song.stream_url = url
        self._failed_id = None
        self.player.setSource(QUrl(url))
        self.player.play()
        self._switching = False
        self.loading_changed.emit(False)

    def _on_stream_failed(self, song: Song, message: str) -> None:
        if song.video_id != self._wanted:
            return
        self._switching = False
        self.loading_changed.emit(False)
        self.notice.emit("skipping unavailable track")
        log.warning("playback aborted for %s: %s", song.video_id, message)

        # Same skip budget as a backend failure: a run of unresolvable tracks
        # must not walk the entire queue. force=True so repeat-one cannot pin us
        # to the track that just failed to resolve.
        self._error_streak += 1
        if self._error_streak <= MAX_AUTO_SKIP and self.cursor + 1 < len(self.queue):
            self.forward(force=True)
            return
        self._error_streak = 0

    def _on_radio_ready(self, seed_id: str, songs: list) -> None:
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

    def _on_radio_failed(self, seed_id: str, message: str) -> None:
        self._extending = False
        self._advance_after_extend = False
        log.debug("radio unavailable for %s: %s", seed_id, message)

    def _on_link_song(self, song: Song) -> None:
        self.adopt([song], 0)

    def _on_link_failed(self, message: str) -> None:
        self.notice.emit("that link didn't work")
        log.warning("link playback failed: %s", message)

    # ------------------------------------------------------------ media relays
    def _relay_progress(self, position_ms: int) -> None:
        self.progress_changed.emit(int(position_ms))

    def _relay_length(self, duration_ms: int) -> None:
        self.length_changed.emit(int(duration_ms))

    def _relay_state(self, state: QMediaPlayer.PlaybackState) -> None:
        # A track that actually reaches PlayingState clears the skip budget.
        # Resetting it on stream-ready instead would defeat MAX_AUTO_SKIP
        # entirely — every resolved URL looked like a fresh start.
        if state == QMediaPlayer.PlaybackState.PlayingState:
            self._error_streak = 0
        self.playing_changed.emit(state == QMediaPlayer.PlaybackState.PlayingState)

    def _relay_media_status(self, status: QMediaPlayer.MediaStatus) -> None:
        if status == QMediaPlayer.MediaStatus.EndOfMedia and not self._switching:
            log.debug("track finished — rolling into the next one")
            if self.repeat_mode == "one" and self.current is not None:
                self.player.setPosition(0)
                self.player.play()
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
        if self._wanted is not None and self._failed_id == self._wanted:
            return  # already handled this track's failure
        self._failed_id = self._wanted
        log.warning("media player error (%s): %s", error, message)

        self.player.stop()
        self.loading_changed.emit(False)
        self._switching = False

        self._error_streak += 1
        if self._error_streak <= MAX_AUTO_SKIP and self.cursor + 1 < len(self.queue):
            self.notice.emit("skipping a dead track")
            self.forward(force=True)
            return

        self._error_streak = 0
        if self.queue:
            self.notice.emit("playback hiccup")