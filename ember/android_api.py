# -*- coding: utf-8 -*-
"""
android_api.py
Bridge module for Ember Flutter Android via Chaquopy.
Exposes catalog search, home feed, radio/similar, lyrics, and stream resolution.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Dict, List, Optional

try:
    from .catalog import CatalogSource
    from .models import Song
    from .stream import StreamResolver
except ImportError:
    from catalog import CatalogSource
    from models import Song
    from stream import StreamResolver

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("android_api")

_catalog: Optional[CatalogSource] = None
_stream_resolver: Optional[StreamResolver] = None


def _get_catalog() -> CatalogSource:
    global _catalog
    if _catalog is None:
        _catalog = CatalogSource()
    return _catalog


def _get_stream_resolver() -> StreamResolver:
    global _stream_resolver
    if _stream_resolver is None:
        _stream_resolver = StreamResolver()
    return _stream_resolver


def _song_to_dict(song: Song) -> Dict[str, str]:
    return {
        "videoId": str(getattr(song, "video_id", "") or ""),
        "title": str(getattr(song, "title", "") or ""),
        "artist": str(getattr(song, "artist", "") or ""),
        "duration": str(getattr(song, "duration", "") or ""),
        "artworkUrl": str(getattr(song, "artwork_url", "") or ""),
        "type": str(getattr(song, "type", "song") or "song"),
    }


def search(query: str, filter_type: Optional[str] = None) -> List[Dict[str, str]]:
    """Search catalog and return list of song dicts."""
    if not query or not query.strip():
        return []
    try:
        cat = _get_catalog()
        f = filter_type.strip().lower() if filter_type and filter_type.strip() else None
        if f == "all":
            f = None
        results = cat.search(query.strip(), filter_type=f)
        return [_song_to_dict(s) for s in results if s and s.video_id]
    except Exception as exc:
        log.error("search failed for %r: %s", query, exc)
        return []


def similar(seed_id: str) -> List[Dict[str, str]]:
    """Get radio / similar tracks for a seed videoId."""
    if not seed_id or not seed_id.strip():
        return []
    try:
        cat = _get_catalog()
        results = cat.similar(seed_id.strip())
        return [_song_to_dict(s) for s in results if s and s.video_id]
    except Exception as exc:
        log.error("similar failed for %r: %s", seed_id, exc)
        return []


def get_stream_url(video_id: str) -> Dict[str, str]:
    """Resolve direct audio streaming URL using yt-dlp."""
    if not video_id or not video_id.strip():
        return {"url": "", "format": "", "error": "Empty videoId"}
    try:
        resolver = _get_stream_resolver()
        url, err, _ = resolver.resolve(video_id.strip())
        if url:
            return {"url": url, "format": "audio/mp4", "error": ""}
        return {"url": "", "format": "", "error": err or "Failed to resolve stream"}
    except Exception as exc:
        log.error("get_stream_url failed for %r: %s", video_id, exc)
        return {"url": "", "format": "", "error": str(exc)}


def get_home(*args: Any, **kwargs: Any) -> str:
    """Fetch YTMusic home feed sections and return serialized JSON."""
    try:
        cat = _get_catalog()
        sections_raw = cat.home(limit=10)
        out_sections = []
        for sec in sections_raw:
            if not isinstance(sec, dict):
                continue
            title = str(sec.get("title") or "Recommended")
            raw_tracks = sec.get("tracks") or []
            tracks = []
            for t in raw_tracks:
                if isinstance(t, Song):
                    tracks.append(_song_to_dict(t))
                elif isinstance(t, dict):
                    tracks.append({
                        "videoId": str(t.get("videoId") or t.get("video_id") or ""),
                        "title": str(t.get("title") or ""),
                        "artist": str(t.get("artist") or ""),
                        "duration": str(t.get("duration") or ""),
                        "artworkUrl": str(t.get("artworkUrl") or t.get("artwork_url") or ""),
                        "type": str(t.get("type") or "song"),
                    })
            if tracks:
                out_sections.append({"title": title, "tracks": tracks})

        # Fallback if home feed returns empty sections
        if not out_sections:
            trending = cat.search("trending music", filter_type="songs")
            if trending:
                out_sections.append({
                    "title": "Quick Picks",
                    "tracks": [_song_to_dict(s) for s in trending if s and s.video_id]
                })

        return json.dumps(out_sections)
    except Exception as exc:
        log.error("get_home failed: %s", exc)
        # Attempt fallback to simple search
        try:
            cat = _get_catalog()
            trending = cat.search("popular songs", filter_type="songs")
            if trending:
                return json.dumps([{
                    "title": "Quick Picks",
                    "tracks": [_song_to_dict(s) for s in trending if s and s.video_id]
                }])
        except Exception:
            pass
        return "[]"


def lyrics(video_id: str, title: str = "", artist: str = "") -> str:
    """Fetch track lyrics."""
    if not video_id:
        return ""
    try:
        cat = _get_catalog()
        res = cat.lyrics(video_id.strip())
        return str(res or "")
    except Exception as exc:
        log.error("lyrics failed for %r: %s", video_id, exc)
        return ""


def get_artist_details(browse_id: str) -> str:
    """Fetch artist details JSON."""
    if not browse_id:
        return "{}"
    try:
        cat = _get_catalog()
        data = cat.artist_details(browse_id.strip())
        # Convert song dataclasses to dicts
        for key in ("songs", "albums", "singles"):
            if key in data and isinstance(data[key], list):
                data[key] = [
                    _song_to_dict(x) if isinstance(x, Song) else x
                    for x in data[key]
                ]
        return json.dumps(data)
    except Exception as exc:
        log.error("get_artist_details failed for %r: %s", browse_id, exc)
        return "{}"


def import_playlist(identifier: str) -> str:
    """Import playlist from YouTube or Spotify link / ID and return JSON."""
    if not identifier:
        return json.dumps({"title": "Empty URL", "tracks": []})
    try:
        cat = _get_catalog()
        data = cat.import_playlist(identifier.strip())
        if "tracks" in data and isinstance(data["tracks"], list):
            data["tracks"] = [
                _song_to_dict(x) if isinstance(x, Song) else x
                for x in data["tracks"]
            ]
        return json.dumps(data)
    except Exception as exc:
        log.error("import_playlist failed for %r: %s", identifier, exc)
        return json.dumps({"title": "Failed to import", "tracks": []})
