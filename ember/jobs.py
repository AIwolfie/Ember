"""
jobs.py
Every blocking operation Ember performs, wrapped as a QRunnable so it can run
on the thread pool. Each job owns a tiny QObject that carries its signals —
QRunnable itself cannot declare them.
"""

from __future__ import annotations

import logging
from typing import Any, List, Optional

import requests
from PyQt6.QtCore import QObject, QRunnable, pyqtSignal

from .catalog import CatalogSource
from .models import Song
from .stream import StreamResolver

log = logging.getLogger(__name__)


class _Signals(QObject):
    """Base carrier so each job subclass only declares what it needs."""


class CancellableJob(QRunnable):
    """Base QRunnable supporting cooperative thread cancellation."""

    def __init__(self) -> None:
        super().__init__()
        self._cancelled = False
        self.setAutoDelete(True)

    def cancel(self) -> None:
        """Signal the job to abort without emitting results."""
        self._cancelled = True

    @property
    def is_cancelled(self) -> bool:
        return self._cancelled


# --------------------------------------------------------------------- search
class SearchSignals(_Signals):
    done = pyqtSignal(str, list)
    failed = pyqtSignal(str, str)


class SearchJob(CancellableJob):
    """Off-thread catalogue search job."""

    def __init__(self, catalog: CatalogSource, query: str, limit: int = 12) -> None:
        super().__init__()
        self.catalog = catalog
        self.query = query
        self.limit = limit
        self.signals = SearchSignals()

    def run(self) -> None:
        if self.is_cancelled:
            return
        try:
            results = self.catalog.search(self.query, self.limit)
            if self.is_cancelled:
                return
            self.signals.done.emit(self.query, results)
        except Exception as exc:  # noqa: BLE001 - network surface
            if self.is_cancelled:
                return
            log.warning("search job failed for %r: %s", self.query, exc)
            self.signals.failed.emit(self.query, str(exc))


# ---------------------------------------------------------------------- radio
class RadioSignals(_Signals):
    ready = pyqtSignal(str, list)
    failed = pyqtSignal(str, str)


class RadioJob(CancellableJob):
    """Off-thread recommendation graph expansion job."""

    def __init__(self, catalog: CatalogSource, seed_id: str, limit: int = 26) -> None:
        super().__init__()
        self.catalog = catalog
        self.seed_id = seed_id
        self.limit = limit
        self.signals = RadioSignals()

    def run(self) -> None:
        if self.is_cancelled:
            return
        try:
            recommendations = self.catalog.similar(self.seed_id, self.limit)
            if self.is_cancelled:
                return
            self.signals.ready.emit(self.seed_id, recommendations)
        except Exception as exc:  # noqa: BLE001
            if self.is_cancelled:
                return
            log.debug("radio job failed for %s: %s", self.seed_id, exc)
            self.signals.failed.emit(self.seed_id, str(exc))


# ----------------------------------------------------------------------- load
class LoadSignals(_Signals):
    ready = pyqtSignal(object, str)
    # song, message, permanent — "permanent" is what lets the player skip an
    # age-gated track and remember it, instead of re-resolving it forever.
    failed = pyqtSignal(object, str, bool)


class LoadJob(CancellableJob):
    """Resolve the audio stream for one song. Emits the Song back with its URL."""

    def __init__(self, song: Song, resolver: StreamResolver) -> None:
        super().__init__()
        self.song = song
        self.resolver = resolver
        self.signals = LoadSignals()

    def run(self) -> None:
        if self.is_cancelled:
            return
        try:
            url, message, permanent = self.resolver.resolve(self.song.video_id)
        except Exception as exc:  # noqa: BLE001 - resolver contract breach
            if self.is_cancelled:
                return
            log.warning("stream resolve failed for %s: %s", self.song.video_id, exc)
            self.signals.failed.emit(self.song, str(exc), False)
            return
        if self.is_cancelled:
            return
        if url:
            self.signals.ready.emit(self.song, url)
            return
        log.warning("stream resolve failed for %s: %s", self.song.video_id, message)
        self.signals.failed.emit(self.song, message, permanent)


# ------------------------------------------------------------------ pasted url
class LinkSignals(_Signals):
    ready = pyqtSignal(object)
    failed = pyqtSignal(str)


class LinkJob(CancellableJob):
    """Turn an arbitrary video/song URL into a playable Song dataclass."""

    def __init__(self, resolver: StreamResolver, url: str) -> None:
        super().__init__()
        self.resolver = resolver
        self.url = url
        self.signals = LinkSignals()

    def run(self) -> None:
        if self.is_cancelled:
            return
        try:
            song = self.resolver.describe(self.url)
            if self.is_cancelled:
                return
            if song is None:
                raise RuntimeError("that link did not resolve to a track")
            self.signals.ready.emit(song)
        except Exception as exc:  # noqa: BLE001
            if self.is_cancelled:
                return
            log.warning("link resolve failed for %r: %s", self.url, exc)
            self.signals.failed.emit(str(exc))


# -------------------------------------------------------------------- artwork
class ArtSignals(_Signals):
    arrived = pyqtSignal(str, bytes)
    failed = pyqtSignal(str, str)


class ArtJob(CancellableJob):
    """Best-effort cover art download with timeout guards."""

    def __init__(self, song_id: str, url: str, timeout: float = 6.0) -> None:
        super().__init__()
        self.song_id = song_id
        self.url = url
        self.timeout = timeout
        self.signals = ArtSignals()

    def run(self) -> None:
        if self.is_cancelled:
            return
        try:
            with requests.get(self.url, timeout=self.timeout) as response:
                if self.is_cancelled:
                    return
                if response.status_code == 200 and response.content:
                    self.signals.arrived.emit(self.song_id, response.content)
                else:
                    self.signals.failed.emit(self.song_id, f"HTTP {response.status_code}")
        except Exception as exc:  # noqa: BLE001
            if self.is_cancelled:
                return
            log.debug("artwork fetch failed for %s: %s", self.song_id, exc)
            self.signals.failed.emit(self.song_id, str(exc))


# --------------------------------------------------------------------- lyrics
class LyricsSignals(_Signals):
    done = pyqtSignal(str, str)
    ready = pyqtSignal(str, str)
    lyrics_ready = pyqtSignal(str, str, str)
    failed = pyqtSignal(str, str)
    lyrics_failed = pyqtSignal(str, str)


class LyricsJob(CancellableJob):
    """Off-thread lyrics fetch job with LRCLIB synchronized lyrics priority."""

    def __init__(
        self,
        catalog: CatalogSource,
        video_id: str,
        title: str = "",
        artist: str = "",
        duration_sec: int = 0,
    ) -> None:
        super().__init__()
        self.catalog = catalog
        self.video_id = video_id
        self.title = title
        self.artist = artist
        self.duration_sec = duration_sec
        self.signals = LyricsSignals()

    def run(self) -> None:
        if self.is_cancelled:
            return

        # 1. Try LRCLIB for synchronized lyrics
        if self.title and self.artist:
            from .lyrics import fetch_lrclib
            try:
                synced, plain = fetch_lrclib(self.title, self.artist, self.duration_sec)
                if self.is_cancelled:
                    return
                if synced or plain:
                    display_text = synced or plain or ""
                    self.signals.done.emit(self.video_id, display_text)
                    self.signals.ready.emit(self.video_id, display_text)
                    self.signals.lyrics_ready.emit(self.video_id, display_text, "LRCLIB")
                    return
            except Exception as lrc_err:
                log.debug("LRCLIB lookup failed for %r: %s", self.title, lrc_err)

        # 2. Fall back to YouTube Music catalog lyrics
        try:
            text = self.catalog.lyrics(self.video_id)
            if self.is_cancelled:
                return
            if text:
                self.signals.done.emit(self.video_id, text)
                self.signals.ready.emit(self.video_id, text)
                self.signals.lyrics_ready.emit(self.video_id, text, "")
            else:
                self.signals.failed.emit(self.video_id, "No lyrics found for this track")
                self.signals.lyrics_failed.emit(self.video_id, "No lyrics found for this track")
        except Exception as exc:  # noqa: BLE001
            if self.is_cancelled:
                return
            log.warning("lyrics job failed for %s: %s", self.video_id, exc)
            self.signals.failed.emit(self.video_id, str(exc))
            self.signals.lyrics_failed.emit(self.video_id, str(exc))


# ----------------------------------------------------------- playlist importer
class PlaylistImportSignals(_Signals):
    ready = pyqtSignal(list, str)
    failed = pyqtSignal(str)


class PlaylistImportJob(CancellableJob):
    """Off-thread playlist importer for Spotify and YouTube links."""

    def __init__(self, url: str, catalog: CatalogSource) -> None:
        super().__init__()
        self.url = url
        self.catalog = catalog
        self.signals = PlaylistImportSignals()

    def run(self) -> None:
        if self.is_cancelled:
            return
        from .importer import SPOTIFY_URL_RE, YOUTUBE_PLAYLIST_RE, fetch_spotify_tracks, parse_youtube_playlist

        try:
            if YOUTUBE_PLAYLIST_RE.search(self.url):
                songs = parse_youtube_playlist(self.url)
                if self.is_cancelled:
                    return
                if not songs:
                    raise RuntimeError("No playable tracks found in YouTube playlist")
                self.signals.ready.emit(songs, "YouTube Playlist")
                return

            if SPOTIFY_URL_RE.search(self.url):
                raw_tracks = fetch_spotify_tracks(self.url)
                if self.is_cancelled:
                    return
                if not raw_tracks:
                    raise RuntimeError("Could not retrieve tracks from Spotify link")

                songs: list[Song] = []
                for item in raw_tracks[:60]:
                    if self.is_cancelled:
                        return
                    title = item.get("title", "")
                    artist = item.get("subtitle", "")
                    query = f"{title} {artist}".strip()
                    if not query:
                        continue
                    try:
                        matches = self.catalog.search(query, limit=1)
                        if matches:
                            songs.append(matches[0])
                    except Exception:
                        pass

                if self.is_cancelled:
                    return
                if not songs:
                    raise RuntimeError("Could not resolve tracks from Spotify link")
                self.signals.ready.emit(songs, "Spotify Playlist")
                return

            raise RuntimeError("Unsupported playlist URL format")
        except Exception as exc:
            if self.is_cancelled:
                return
            log.warning("playlist import failed for %r: %s", self.url, exc)
            self.signals.failed.emit(str(exc))


# ----------------------------------------------------------- disk audio cache
class CacheTrackJob(CancellableJob):
    """Downloads audio stream bytes to AudioDiskCache in the background."""

    def __init__(self, disk_cache: Any, video_id: str, stream_url: str) -> None:
        super().__init__()
        self.disk_cache = disk_cache
        self.video_id = video_id
        self.stream_url = stream_url

    def run(self) -> None:
        if self.is_cancelled or not self.disk_cache or not self.stream_url:
            return
        if self.stream_url.startswith("file:") or self.disk_cache.has(self.video_id):
            return
        try:
            with requests.get(self.stream_url, stream=True, timeout=30) as resp:
                if resp.status_code == 200:
                    chunks = bytearray()
                    for chunk in resp.iter_content(chunk_size=65536):
                        if self.is_cancelled:
                            return
                        chunks.extend(chunk)
                    if not self.is_cancelled and chunks:
                        ext = "opus" if "webm" in self.stream_url else "m4a"
                        self.disk_cache.store(self.video_id, bytes(chunks), ext=ext)
        except Exception as exc:  # noqa: BLE001
            log.debug("Background track caching failed for %s: %s", self.video_id, exc)