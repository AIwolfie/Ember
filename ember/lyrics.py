"""
lyrics.py
Real-time synchronized LRC lyrics client for Ember.
Fetches millisecond-accurate lyrics from LRCLIB and parses timecodes
for live karaoke-style scrolling.
"""

from __future__ import annotations

import logging
import re
from typing import List, Optional, Tuple

import requests

log = logging.getLogger(__name__)

LRCLIB_API_URL = "https://lrclib.net/api/get"
USER_AGENT = "EmberMusicPlayer/1.0 (https://github.com/AIwolfie/Ember)"
_LRC_PATTERN = re.compile(r"\[(\d{1,2}):(\d{2}(?:\.\d{1,3})?)\](.*)")

# Remove noise from video titles before querying metadata
_CLEAN_TITLE_PATTERNS = [
    re.compile(r"\s*[\(\[](official\s*(music\s*)?video|audio|lyrics?|visualizer|hd|4k|remastered|extended)[\)\]]", re.IGNORECASE),
    re.compile(r"\s*[\(\[]?(?:feat\.|ft\.)\s+[^\(\[\-]+[\)\]]?", re.IGNORECASE),
]


def clean_title(title: str) -> str:
    """Strip common YouTube labels like '(Official Video)' to maximize search hits."""
    cleaned = title
    for pat in _CLEAN_TITLE_PATTERNS:
        cleaned = pat.sub("", cleaned)
    return cleaned.strip()


def parse_lrc(text: str) -> List[Tuple[int, str]]:
    """Parse standard LRC timecoded lyrics into [(timestamp_ms, text)]."""
    if not text or not isinstance(text, str):
        return []
    parsed: List[Tuple[int, str]] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        match = _LRC_PATTERN.match(line)
        if match:
            try:
                mins = int(match.group(1))
                secs = float(match.group(2))
                ms = int((mins * 60 + secs) * 1000)
                content = match.group(3).strip()
                parsed.append((ms, content))
            except (ValueError, TypeError):
                continue
    parsed.sort(key=lambda x: x[0])
    return parsed


def find_active_index(lines: List[Tuple[int, str]], current_ms: int) -> int:
    """Find the 0-based index of the active lyric line for current_ms."""
    if not lines:
        return -1
    if current_ms < lines[0][0]:
        return -1
    # Find the latest line with timestamp <= current_ms
    low, high = 0, len(lines) - 1
    result = 0
    while low <= high:
        mid = (low + high) // 2
        if lines[mid][0] <= current_ms:
            result = mid
            low = mid + 1
        else:
            high = mid - 1
    return result


def fetch_lrclib(
    title: str,
    artist: str,
    duration_sec: Optional[int] = None,
    timeout: float = 4.0,
) -> Tuple[Optional[str], Optional[str]]:
    """Fetch lyrics from LRCLIB.

    Returns:
        (synced_lyrics_lrc, plain_lyrics_text)
    """
    cleaned = clean_title(title)
    params: dict[str, Any] = {
        "track_name": cleaned,
        "artist_name": artist,
    }
    if duration_sec and duration_sec > 0:
        params["duration"] = int(duration_sec)

    try:
        resp = requests.get(
            LRCLIB_API_URL,
            params=params,
            headers={"User-Agent": USER_AGENT},
            timeout=timeout,
        )
        if resp.status_code == 200:
            data = resp.json()
            synced = data.get("syncedLyrics")
            plain = data.get("plainLyrics")
            return (
                str(synced).strip() if synced else None,
                str(plain).strip() if plain else None,
            )
        log.debug("LRCLIB returned HTTP %d for %r by %r", resp.status_code, cleaned, artist)
    except Exception as exc:
        log.debug("LRCLIB request failed: %s", exc)

    return None, None
