from __future__ import annotations

import html
import logging
import time
from typing import Any, Callable, Dict, List, Optional, TypeVar

from ytmusicapi import YTMusic

from .models import Song

log = logging.getLogger(__name__)

T = TypeVar("T")


def _with_retry(
    operation: Callable[..., T],
    *args: Any,
    max_attempts: int = 3,
    base_delay: float = 0.6,
    operation_name: str = "request",
    **kwargs: Any,
) -> T:
    """Execute a network-bound callable with exponential backoff."""
    last_exc: Optional[Exception] = None
    for attempt in range(1, max_attempts + 1):
        try:
            return operation(*args, **kwargs)
        except Exception as exc:
            last_exc = exc
            if attempt < max_attempts:
                sleep_time = base_delay * (2 ** (attempt - 1))
                log.warning(
                    "%s attempt %d/%d failed: %s. Retrying in %.1fs...",
                    operation_name,
                    attempt,
                    max_attempts,
                    exc,
                    sleep_time,
                )
                time.sleep(sleep_time)
            else:
                log.error("%s failed permanently after %d attempts: %s", operation_name, max_attempts, exc)
    if last_exc is not None:
        raise last_exc
    raise RuntimeError(f"{operation_name} failed without exception")


def _artist_line(item: Dict[str, Any]) -> str:
    """Extract and normalize artist name(s) from a search or watch item."""
    raw = item.get("artists") or item.get("author") or item.get("subtitle") or []
    if isinstance(raw, dict):
        raw = [raw]
    if isinstance(raw, list):
        names = []
        for entry in raw:
            if isinstance(entry, dict) and entry.get("name"):
                names.append(str(entry["name"]).strip())
            elif isinstance(entry, str) and entry.strip():
                names.append(entry.strip())
        if names:
            return html.unescape(", ".join(names))
    if isinstance(raw, str) and raw.strip():
        return html.unescape(raw.strip())
    return "unknown artist"


def _artwork_url(item: Dict[str, Any]) -> str:
    """Pick highest resolution thumbnail available."""
    raw = item.get("thumbnails") or item.get("thumbnail") or []
    if isinstance(raw, dict):
        raw = [raw]
    if isinstance(raw, list) and raw:
        # Choose highest width/height or last element
        valid = [entry for entry in raw if isinstance(entry, dict) and entry.get("url")]
        if valid:
            def _area(x: Dict[str, Any]) -> int:
                try:
                    return int(x.get("width") or 0) * int(x.get("height") or 0)
                except (ValueError, TypeError):
                    return 0
            valid.sort(key=_area)
            return valid[-1].get("url") or ""
    return ""


class CatalogSource:
    """Wraps the guest (no-login) YouTube Music client with resilient retries."""

    def __init__(self) -> None:
        self.api = YTMusic()
        log.info("catalogue client ready")

    # ------------------------------------------------------------------ reads
    def search(self, query: str, limit: int = 12) -> List[Song]:
        """Free-text song search with exponential backoff.

        Raises on persistent transport failure so the UI can notify the user.
        """
        query = (query or "").strip()
        if not query:
            return []

        def _do_search() -> List[Dict[str, Any]]:
            return self.api.search(query, filter="songs", limit=limit)

        raw_results = _with_retry(
            _do_search,
            max_attempts=3,
            base_delay=0.5,
            operation_name=f"search({query!r})",
        )

        found: List[Song] = []
        for item in raw_results:
            song = self._build(item, duration_key="duration")
            if song is not None:
                found.append(song)

        log.info("search %r -> %d track(s)", query, len(found))
        return found

    def similar(self, seed_id: str, limit: int = 26) -> List[Song]:
        """Tracks the recommendation graph puts next to `seed_id`. Best effort."""
        related: List[Song] = []
        seen = {seed_id}

        def _do_watch() -> Dict[str, Any]:
            return self.api.get_watch_playlist(videoId=seed_id, limit=limit)

        try:
            watch = _with_retry(
                _do_watch,
                max_attempts=2,
                base_delay=0.6,
                operation_name=f"radio({seed_id})",
            )
        except Exception as exc:  # noqa: BLE001 - network surface
            log.warning("radio lookup failed for %s after retries: %s", seed_id, exc)
            return related

        for item in watch.get("tracks") or []:
            song = self._build(item, duration_key="length")
            if song is None or song.video_id in seen:
                continue
            seen.add(song.video_id)
            related.append(song)

        log.debug("radio for %s -> %d track(s)", seed_id, len(related))
        return related

    def lyrics(self, video_id: str) -> Optional[str]:
        """Fetch lyrics text from YouTube Music for a given video_id."""
        video_id = (video_id or "").strip()
        if not video_id:
            return None

        def _do_lyrics() -> Optional[str]:
            watch = self.api.get_watch_playlist(videoId=video_id)
            lyrics_id = watch.get("lyrics")
            if not lyrics_id:
                return None
            data = self.api.get_lyrics(lyrics_id)
            if not data or not isinstance(data, dict):
                return None
            text = data.get("lyrics")
            return str(text).strip() if text else None

        try:
            return _with_retry(
                _do_lyrics,
                max_attempts=2,
                base_delay=0.5,
                operation_name=f"lyrics({video_id})",
            )
        except Exception as exc:  # noqa: BLE001
            log.warning("lyrics lookup failed for %s: %s", video_id, exc)
            return None

    # ----------------------------------------------------------------- parsing
    @staticmethod
    def _build(item: Dict[str, Any], duration_key: str = "duration") -> Optional[Song]:
        """Map raw dictionary to a validated Song dataclass."""
        if not isinstance(item, dict):
            return None
        video_id = item.get("videoId")
        if not video_id:
            return None
        raw_dur = item.get(duration_key)
        if raw_dur is None:
            raw_dur = item.get("duration") or item.get("length") or ""
        if isinstance(raw_dur, (int, float)):
            minutes = int(raw_dur) // 60
            seconds = int(raw_dur) % 60
            duration = f"{minutes}:{seconds:02d}"
        else:
            duration = str(raw_dur).strip()

        raw_title = str(item.get("title") or "untitled").strip()
        return Song(
            video_id=str(video_id).strip(),
            title=html.unescape(raw_title),
            artist=_artist_line(item),
            duration=duration,
            artwork_url=_artwork_url(item),
        )
