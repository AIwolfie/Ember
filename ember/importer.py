"""
importer.py
Universal playlist importer for Ember.
Scrapes and parses public Spotify and YouTube playlists into
Ember Song queues without requiring API keys or user logins.
"""

from __future__ import annotations

import html
import json
import logging
import re
from typing import Any, Dict, List, Optional

import requests

from .models import Song
from .utils import clock

log = logging.getLogger(__name__)

SPOTIFY_URL_RE = re.compile(r"https?://open\.spotify\.com/(?:intl-[a-z]+/)?(playlist|album|track)/([a-zA-Z0-9]+)")
YOUTUBE_PLAYLIST_RE = re.compile(r"https?://(?:www\.|music\.)?youtube\.com/playlist\?list=([a-zA-Z0-9_-]+)")
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"


def is_playlist_url(text: str) -> bool:
    """True if text looks like a supported Spotify or YouTube playlist/album link."""
    if not text or not isinstance(text, str):
        return False
    s = text.strip()
    return bool(SPOTIFY_URL_RE.search(s) or YOUTUBE_PLAYLIST_RE.search(s))


def extract_spotify_id(url: str) -> tuple[str, str]:
    """Extract (entity_type, id) from a Spotify link."""
    match = SPOTIFY_URL_RE.search(url.strip())
    if match:
        return match.group(1), match.group(2)
    return "", ""


def fetch_spotify_tracks(url: str, timeout: float = 8.0) -> List[Dict[str, Any]]:
    """Scrape public Spotify embed metadata for tracks in a playlist or album."""
    match = SPOTIFY_URL_RE.search(url.strip())
    if not match:
        return []
    entity_type, entity_id = match.group(1), match.group(2)
    embed_url = f"https://open.spotify.com/embed/{entity_type}/{entity_id}"

    try:
        resp = requests.get(embed_url, headers={"User-Agent": USER_AGENT}, timeout=timeout)
        if resp.status_code != 200:
            log.warning("Spotify embed returned HTTP %d", resp.status_code)
            return []

        # Find __NEXT_DATA__ JSON payload in embed HTML
        script_match = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', resp.text, re.DOTALL)
        if not script_match:
            log.warning("Could not find __NEXT_DATA__ in Spotify embed page")
            return []

        data = json.loads(script_match.group(1))
        entity = data.get("props", {}).get("pageProps", {}).get("state", {}).get("data", {}).get("entity", {})

        track_list: List[Dict[str, Any]] = entity.get("trackList", [])
        if not track_list and entity_type == "track":
            # Single track fallback
            name = entity.get("name") or entity.get("title")
            artist = entity.get("subtitle") or entity.get("artists", "")
            duration = entity.get("duration", 0)
            if name:
                track_list = [{"title": name, "subtitle": artist, "duration": duration}]

        log.info("Scraped %d Spotify tracks from %s", len(track_list), entity_type)
        return track_list
    except Exception as exc:
        log.error("Failed to scrape Spotify playlist %r: %s", url, exc)
        return []


def parse_youtube_playlist(url: str, timeout_sec: int = 15) -> List[Song]:
    """Extract songs from a YouTube playlist via yt-dlp flat extraction."""
    import yt_dlp

    ydl_opts: Dict[str, Any] = {
        "extract_flat": "in_playlist",
        "skip_download": True,
        "quiet": True,
        "no_warnings": True,
        "socket_timeout": timeout_sec,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            data = ydl.extract_info(url.strip(), download=False)
            if not data:
                return []
            entries = data.get("entries") or []
            songs: List[Song] = []
            for item in entries:
                if not isinstance(item, dict):
                    continue
                vid = item.get("id")
                if not vid:
                    continue
                title = str(item.get("title") or "untitled")
                artist = str(item.get("uploader") or item.get("channel") or "youtube")
                dur_sec = item.get("duration")
                dur_str = clock(int(dur_sec * 1000)) if isinstance(dur_sec, (int, float)) else ""
                thumbs = item.get("thumbnails") or []
                art_url = thumbs[-1].get("url", "") if thumbs and isinstance(thumbs[-1], dict) else ""

                songs.append(
                    Song(
                        video_id=str(vid).strip(),
                        title=html.unescape(title),
                        artist=html.unescape(artist),
                        duration=dur_str,
                        artwork_url=art_url,
                    )
                )
            log.info("Extracted %d tracks from YouTube playlist", len(songs))
            return songs
    except Exception as exc:
        log.warning("YouTube playlist extraction failed: %s", exc)
        return []
