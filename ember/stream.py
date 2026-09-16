"""
stream.py
Resolves a track id (or a pasted link) into a direct HTTPS audio stream with
yt-dlp. Nothing is ever written to disk — we only read the resolved URL.
"""

from __future__ import annotations

import datetime
import logging
import threading
import time
from typing import Any, Dict, List, Optional, Tuple

import yt_dlp

from .config import STREAM_CACHE_TTL_S, YTDLP_MAX_AGE_DAYS
from .models import Song

log = logging.getLogger(__name__)

WATCH_URL = "https://www.youtube.com/watch?v={0}"

# Conditions yt-dlp cannot recover from by trying again: the extractor needs an
# authenticated session, so a retry returns the same refusal seconds later.
PERMANENT_FAILURE_MARKERS = (
    "sign in to confirm your age",
    "sign in to confirm you're not a bot",
    "sign in to confirm you’re not a bot",
    "this video is age-restricted",
    "video unavailable",
    "private video",
    "members-only",
)


def _is_permanent_failure(exc: BaseException) -> bool:
    """True when the extractor error will not resolve on a retry."""
    text = str(exc).lower()
    return any(marker in text for marker in PERMANENT_FAILURE_MARKERS)


# --------------------------------------------------------------- yt-dlp guard
_YTDLP_FRESHNESS_CHECKED = False


def ytdlp_version() -> str:
    """Version string reported by the installed yt-dlp build."""
    try:
        from yt_dlp.version import __version__ as version
    except Exception:  # noqa: BLE001 - the version module has moved between releases
        return str(getattr(yt_dlp, "__version__", "unknown"))
    return str(version)


def ytdlp_age_days(version: Optional[str] = None) -> Optional[int]:
    """Days since the installed yt-dlp release, or None when it is not dated.

    yt-dlp versions are calendar releases (2026.9.15), which is the only reason
    an "is this build stale" check is possible at all.
    """
    raw = version or ytdlp_version()
    parts = raw.split(".")
    if len(parts) < 3:
        return None
    try:
        released = datetime.date(int(parts[0]), int(parts[1]), int(parts[2]))
    except (TypeError, ValueError):
        return None
    return (datetime.date.today() - released).days


def check_ytdlp_freshness(max_age_days: int = YTDLP_MAX_AGE_DAYS) -> Optional[int]:
    """Log once when the installed yt-dlp is old enough to be the bug report.

    An extractor that lags YouTube by a month is the single most likely cause of
    "it stopped working", so this is worth saying out loud in the log.
    """
    global _YTDLP_FRESHNESS_CHECKED
    if _YTDLP_FRESHNESS_CHECKED:
        return None
    _YTDLP_FRESHNESS_CHECKED = True

    age = ytdlp_age_days()
    if age is None:
        log.debug("yt-dlp %s is not date-versioned — skipping freshness check", ytdlp_version())
        return None
    if age > max_age_days:
        log.warning(
            "yt-dlp %s is %d days old (budget %d). Extractor changes land "
            "continuously; run: python -m pip install -U yt-dlp",
            ytdlp_version(),
            age,
            max_age_days,
        )
    else:
        log.info("yt-dlp %s is %d days old", ytdlp_version(), age)
    return age


# ------------------------------------------------------------- resolved streams
class StreamCache:
    """Short-TTL map of video_id -> direct audio URL.

    Replaying a track used to re-run yt-dlp with three attempts and exponential
    backoff — seconds of dead air for a track the user already heard. Signed
    URLs expire, so entries live for STREAM_CACHE_TTL_S and are dropped early
    when the backend rejects one.
    """

    def __init__(self, ttl_seconds: int = STREAM_CACHE_TTL_S) -> None:
        self.ttl = int(ttl_seconds)
        self._entries: Dict[str, tuple] = {}
        self._lock = threading.Lock()

    def get(self, video_id: str) -> Optional[str]:
        """Cached URL for a track, or None when missing or expired."""
        if not video_id:
            return None
        now = time.monotonic()
        with self._lock:
            entry = self._entries.get(video_id)
            if entry is None:
                return None
            stamped, url = entry
            if now - stamped > self.ttl:
                del self._entries[video_id]
                return None
            return url

    def put(self, video_id: str, url: str) -> None:
        """Remember a freshly resolved URL. Never logged — it is signed."""
        if not video_id or not url:
            return
        with self._lock:
            self._entries[video_id] = (time.monotonic(), url)

    def invalidate(self, video_id: str) -> None:
        """Drop one entry — used when the backend rejects an expired signature."""
        with self._lock:
            self._entries.pop(video_id, None)

    def clear(self) -> None:
        with self._lock:
            self._entries.clear()

    def __len__(self) -> int:
        with self._lock:
            return len(self._entries)


BASE_OPTIONS: Dict[str, Any] = {
    # M4A first. Windows Media Foundation — the backend QMediaPlayer uses on
    # Windows — cannot demux WebM/Opus past the opening cluster, which is what
    # cuts playback off around the two-minute mark. AAC in an MP4 container it
    # handles cleanly.
    "format": "bestaudio[ext=m4a]/bestaudio[acodec^=mp4a]/bestaudio/best",
    "quiet": True,
    "no_warnings": True,
    "noplaylist": True,
    "skip_download": True,
    # NOTE: internal retries removed — our _probe() already does 3-attempt
    # exponential backoff; keeping both multiplies total attempts (4×3 = 12).
    "retries": 0,
    "socket_timeout": 15,
    "extractor_retries": 0,
}


class StreamResolver:
    """Thin yt-dlp wrapper with retry backoff. Every call is synchronous — jobs run it off-thread."""

    def __init__(
        self,
        overrides: Optional[Dict[str, Any]] = None,
        cache: Optional[StreamCache] = None,
    ) -> None:
        self.options = dict(BASE_OPTIONS)
        if overrides:
            self.options.update(overrides)
        self.cache = cache if cache is not None else StreamCache()
        check_ytdlp_freshness()

    def _probe(self, target: str, max_attempts: int = 3) -> Dict[str, Any]:
        """Extract info from yt-dlp with retries and exponential backoff."""
        last_exc: Optional[Exception] = None
        for attempt in range(1, max_attempts + 1):
            try:
                with yt_dlp.YoutubeDL(self.options) as ydl:
                    data = ydl.extract_info(target, download=False)
                    if isinstance(data, dict):
                        return data
                    raise RuntimeError("unexpected response structure from extractor")
            except Exception as exc:
                last_exc = exc
                # Age gate and bot check are not transient — retrying just burns
                # ~10s of dead air before failing anyway. Bail on the first hit.
                if _is_permanent_failure(exc):
                    log.warning("stream probe %r blocked permanently: %s", target, exc)
                    raise
                if attempt < max_attempts:
                    sleep_sec = 0.5 * (2 ** (attempt - 1))
                    log.warning(
                        "stream probe %r attempt %d/%d failed: %s. Retrying in %.1fs...",
                        target,
                        attempt,
                        max_attempts,
                        exc,
                        sleep_sec,
                    )
                    time.sleep(sleep_sec)
                else:
                    log.error("stream probe %r failed after %d attempts: %s", target, max_attempts, exc)
        if last_exc is not None:
            raise last_exc
        return {}

    def resolve(self, video_id: str) -> Tuple[Optional[str], str, bool]:
        """Resolve a track, reporting why it failed and whether a retry can help.

        stream_url() collapses every failure into None, which is why the player
        could not tell an age-gated track (never retry, skip and remember) from
        a 403 on an expired signed URL (re-resolve, it will work). Returns
        (url, message, permanent).
        """
        if not video_id:
            return None, "no track id", True

        cached = self.cache.get(video_id)
        if cached is not None:
            log.debug("stream cache hit for %s", video_id)
            return cached, "", False

        target = WATCH_URL.format(video_id)
        try:
            info = self._probe(target)
        except Exception as exc:
            log.error("stream resolve failed for %s: %s", video_id, exc)
            return None, str(exc), _is_permanent_failure(exc)

        url = self._pick_url(info)
        if not url:
            return None, "no playable audio stream was returned", False
        self.cache.put(video_id, url)
        return url, "", False

    def stream_url(self, video_id: str) -> Optional[str]:
        """Direct audio URL for a track id, or None when nothing playable exists."""
        return self.resolve(video_id)[0]

    @staticmethod
    def _pick_url(info: Dict[str, Any]) -> Optional[str]:
        """Best playable audio URL from an extractor response, M4A first.

        Collect every usable audio format and pick from the list. The old code
        returned info["url"] straight away, which made the M4A preference below
        dead code: yt-dlp had already chosen bestaudio for us, and that choice
        is often WebM/Opus, which Windows Media Foundation cannot demux past the
        opening cluster.
        """
        raw_formats: List[Dict[str, Any]] = info.get("formats") or []
        formats = [
            fmt
            for fmt in raw_formats
            if fmt.get("acodec") not in (None, "none") and fmt.get("url")
        ]

        # Fall back to the top-level entry only when the format list is empty.
        direct = info.get("url")
        if not formats:
            return direct if isinstance(direct, str) and direct else None

        def _rank(fmt: Dict[str, Any]) -> tuple:
            ext = str(fmt.get("ext") or "").lower()
            acodec = str(fmt.get("acodec") or "").lower()
            is_mp4 = ext == "m4a" or acodec.startswith("mp4a")
            # WebM/Opus last resort only — WMF cuts playback on those.
            is_webm = ext == "webm" or acodec.startswith("opus")
            return (
                0 if is_mp4 else (2 if is_webm else 1),
                -(fmt.get("abr") or 0),
                -(fmt.get("filesize") or 0),
            )

        formats.sort(key=_rank)
        return formats[0]["url"]

    def describe(self, url: str) -> Optional[Song]:
        """Turn a pasted link into a Song so it can enter the normal queue."""
        if not url or not url.strip():
            return None
        try:
            info = self._probe(url.strip())
        except Exception as exc:
            log.error("describe failed for %r: %s", url, exc)
            return None
        video_id = info.get("id")
        if not video_id:
            return None
        return Song(
            video_id=str(video_id),
            title=str(info.get("title") or "untitled"),
            artist=str(info.get("uploader") or info.get("channel") or "youtube"),
            duration=str(info.get("duration_string") or ""),
            artwork_url=str(info.get("thumbnail") or ""),
        )