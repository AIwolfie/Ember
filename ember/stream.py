"""
stream.py
Resolves a track id (or a pasted link) into a direct HTTPS audio stream with
yt-dlp. Nothing is ever written to disk — we only read the resolved URL.
"""

from __future__ import annotations

import logging
import time
from typing import Any, Dict, List, Optional

import yt_dlp

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

    def __init__(self, overrides: Optional[Dict[str, Any]] = None) -> None:
        self.options = dict(BASE_OPTIONS)
        if overrides:
            self.options.update(overrides)

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

    def stream_url(self, video_id: str) -> Optional[str]:
        """Direct audio URL for a track id, or None when nothing playable exists."""
        if not video_id:
            return None
        target = WATCH_URL.format(video_id)
        try:
            info = self._probe(target)
        except Exception as exc:
            log.error("stream_url failed for %s: %s", video_id, exc)
            return None
        # Collect every usable audio format first and pick from the list. The old
        # code returned info["url"] straight away, which made the M4A preference
        # below dead code: yt-dlp had already chosen bestaudio for us, and that
        # choice is often WebM/Opus, which Windows Media Foundation cannot demux
        # past the opening cluster.
        raw_formats: List[Dict[str, Any]] = info.get("formats") or []
        formats = [
            fmt
            for fmt in raw_formats
            if fmt.get("acodec") not in (None, "none") and fmt.get("url")
        ]

        # Fall back to the top-level entry only when the format list is empty.
        direct = info.get("url")
        if not formats:
            if direct and isinstance(direct, str):
                return direct
            return None

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