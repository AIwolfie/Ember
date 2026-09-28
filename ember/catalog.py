from __future__ import annotations

import html
import logging
import time
from typing import Any, Callable, Dict, List, Optional, TypeVar

from ytmusicapi import YTMusic

try:
    from .models import Song
except ImportError:
    from models import Song

log = logging.getLogger(__name__)

T = TypeVar("T")

_VALID_FILTERS = {
    "albums", "artists", "playlists", "community_playlists",
    "featured_playlists", "songs", "videos", "profiles",
    "podcasts", "episodes",
}
_FILTER_ALIASES = {
    "song": "songs", "track": "songs", "tracks": "songs",
    "video": "videos", "album": "albums", "artist": "artists",
    "playlist": "playlists",
}


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
    if isinstance(item.get("artist"), str) and item["artist"].strip():
        return html.unescape(item["artist"].strip())
    raw = item.get("artists") or item.get("author") or item.get("subtitle") or item.get("artist") or []
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
                    if not isinstance(x, dict): return 0
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
    def search(self, query: str, filter_type: Optional[str] = None, limit: int = 20) -> List[Song]:
        """Free-text song search with exponential backoff.

        Raises on persistent transport failure so the UI can notify the user.
        """
        query = (query or "").strip()
        if not query:
            return []

        f = filter_type.strip().lower() if isinstance(filter_type, str) else ""
        f = _FILTER_ALIASES.get(f, f)
        filter_type = f if f in _VALID_FILTERS else None

        def _do_search() -> List[Dict[str, Any]]:
            return self.api.search(query, filter=filter_type, limit=limit)

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

    def lyrics(self, video_id: str, title: str = "", artist: str = "") -> Optional[str]:
        """Fetch lyrics text, preferring LRCLIB timed .lrc, fallback to YouTube Music for plain text."""
        video_id = (video_id or "").strip()
        title = (title or "").strip()
        artist = (artist or "").strip()
        
        # 1. Try LRCLIB for pristine timestamped lyrics
        if title and artist:
            try:
                import urllib.request, urllib.parse, json
                url = f"https://lrclib.net/api/search?track_name={urllib.parse.quote(title)}&artist_name={urllib.parse.quote(artist)}"
                req = urllib.request.Request(url, headers={'User-Agent': 'EmberMusic/1.0'})
                with urllib.request.urlopen(req, timeout=5) as response:
                    data = json.loads(response.read().decode())
                    if isinstance(data, list) and len(data) > 0:
                        for entry in data:
                            if entry.get("syncedLyrics"):
                                return str(entry["syncedLyrics"])
                        # If no synced LRC exists, keep fallback
                        for entry in data:
                            if entry.get("plainLyrics"):
                                return str(entry["plainLyrics"])
            except Exception as exc:
                log.warning("lrclib fetch failed for %s - %s: %s", title, artist, exc)
                
        # 2. Fallback to YouTube Music
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
            return str(data.get("lyrics", "")).strip() or None

        try:
            return _with_retry(
                _do_lyrics,
                max_attempts=2,
                base_delay=0.5,
                operation_name=f"lyrics({video_id})",
            )
        except Exception as exc: 
            log.warning("lyrics lookup failed for %s: %s", video_id, exc)
            return None

    def home(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Fetch the dynamic YTMusic home feed and filter for playable tracks."""
        def _do_home() -> List[Dict[str, Any]]:
            return self.api.get_home(limit=limit)

        try:
            raw = _with_retry(
                _do_home,
                max_attempts=2,
                base_delay=0.6,
                operation_name="get_home",
            )
        except Exception as exc:
            log.warning("home fetch failed: %s", exc)
            return []
            
        sections = []
        for shelf in raw:
            if not isinstance(shelf, dict): 
                continue
            title = shelf.get("title") or "Recommended for you"
            contents = shelf.get("contents") or []
            valid_tracks = []
            for item in contents:
                vid = item.get("videoId") or item.get("browseId") or item.get("playlistId")
                if vid:
                    song = self._build(item)
                    if song:
                        valid_tracks.append(song)
            if valid_tracks:
                sections.append({
                    "title": html.unescape(title) if isinstance(title, str) else str(title),
                    "tracks": valid_tracks
                })
        return sections

    def top_artists(self, country: str = "IN") -> List[Song]:
        try:
            charts = _with_retry(lambda: self.api.get_charts(country=country), max_attempts=2, base_delay=0.5, operation_name="charts")
            artists_data = charts.get("artists") or []
            raw_artists = artists_data.get("items", []) if isinstance(artists_data, dict) else artists_data
            found = []
            for item in raw_artists:
                item["resultType"] = "artist"
                song = self._build(item)
                if song:
                    found.append(song)
            return found
        except Exception as exc:
            log.warning("top_artists failed: %s", exc)
            return []

    def artist_details(self, browse_id: str) -> Dict[str, Any]:
        try:
            data = _with_retry(lambda: self.api.get_artist(browse_id), max_attempts=2, base_delay=0.5, operation_name=f"artist({browse_id})")
            
            songs = []
            if "songs" in data and "results" in data["songs"]:
                for r in data["songs"]["results"]:
                    r["resultType"] = "song"
                    song = self._build(r)
                    if song: songs.append(song)
            
            albums = []
            if "albums" in data and "results" in data["albums"]:
                for r in data["albums"]["results"]:
                    r["resultType"] = "album"
                    pl = self._build(r)
                    if pl: albums.append(pl)
                    
            singles = []
            if "singles" in data and "results" in data["singles"]:
                for r in data["singles"]["results"]:
                    r["resultType"] = "album"
                    pl = self._build(r)
                    if pl: singles.append(pl)
            
            image_url = ""
            thumbnails = data.get("thumbnails", [])
            if thumbnails:
                image_url = sorted(thumbnails, key=lambda x: x.get("width", 0))[-1]["url"]

            return {
                "name": data.get("name", "Unknown Artist"),
                "description": data.get("description", ""),
                "image": image_url,
                "songs": songs,
                "albums": albums,
                "singles": singles
            }
        except Exception as exc:
            log.warning("artist_details failed: %s", exc)
            return {}

    def import_playlist(self, identifier: str) -> Dict[str, Any]:
        """Fetch playlist tracks by URL or ID."""
        identifier = identifier.strip()
        if not identifier:
            return {"title": "Unknown", "tracks": []}
            
        import urllib.parse
        if "spotify.com" in identifier:
            return self._import_spotify_playlist(identifier)
            
        if "list=" in identifier:
            try:
                parsed = urllib.parse.urlparse(identifier)
                qs = urllib.parse.parse_qs(parsed.query)
                identifier = qs.get("list", [identifier])[0]
            except Exception:
                pass
                
        def _do_get() -> Dict[str, Any]:
            return self.api.get_playlist(playlistId=identifier, limit=300)
            
        try:
            data = _with_retry(_do_get, max_attempts=2, base_delay=0.6, operation_name=f"playlist({identifier})")
        except Exception as exc:
            log.warning("playlist import failed: %s", exc)
            return {"title": "Failed to Import", "tracks": []}
            
        title = data.get("title", "Imported Playlist")
        tracks = []
        for item in data.get("tracks", []):
            song = self._build(item)
            if song:
                tracks.append(song)
                
        return {"title": title, "tracks": tracks}

    def _import_spotify_playlist(self, url: str) -> Dict[str, Any]:
        """Scrape Spotify embed API for playlist tracks and match them to YT."""
        import requests, re, json
        import concurrent.futures
        
        try:
            # Transform normal url to embed url
            if "/playlist/" in url and "/embed/" not in url:
                url = url.replace("/playlist/", "/embed/playlist/")
            elif "/album/" in url and "/embed/" not in url:
                url = url.replace("/album/", "/embed/album/")
            
            headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
            r = requests.get(url, headers=headers, timeout=10)
            
            match = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', r.text)
            if not match:
                log.warning("Could not find NEXT_DATA in Spotify embed")
                return {"title": "Failed to Parse Spotify", "tracks": []}
                
            data = json.loads(match.group(1))
            entity = data.get("props", {}).get("pageProps", {}).get("state", {}).get("data", {}).get("entity", {})
            title = entity.get("name", "Spotify Import")
            track_list = entity.get("trackList", [])
            
            if not track_list:
                return {"title": title, "tracks": []}
                
            # Limit to 100 tracks to avoid crazy ytmusic rate limiting / waiting forever
            track_list = track_list[:100]
            
            def _resolve_track(trk):
                t_name = trk.get("title", "")
                t_artist = trk.get("subtitle", "")
                if not t_name: return None
                query = f"{t_name} {t_artist}".strip()
                # Search ytmusic
                try:
                    res = self.api.search(query, filter="songs", limit=1)
                    if res:
                        return self._build(res[0])
                except Exception:
                    pass
                return None
                
            tracks = []
            with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                for yt_song in executor.map(_resolve_track, track_list):
                    if yt_song:
                        tracks.append(yt_song)
                        
            return {"title": title, "tracks": tracks}
        except Exception as exc:
            log.warning("Spotify playlist import failed: %s", exc)
            return {"title": "Spotify Import Failed", "tracks": []}

    # ----------------------------------------------------------------- parsing
    @staticmethod
    def _build(item: Dict[str, Any], duration_key: str = "duration") -> Optional[Song]:
        """Map raw dictionary to a validated Song dataclass."""
        if not isinstance(item, dict):
            return None
            
        result_type = item.get("resultType") or "song"
        category = str(item.get("category", "")).lower()
        if "artist" in category or "profiles" in category:
            result_type = "artist"
        elif "playlist" in category or "albums" in category:
            result_type = "playlist"
            
        video_id = item.get("videoId")
        browse_id = item.get("browseId")
        
        if not browse_id and result_type == "artist":
            artists = item.get("artists")
            if isinstance(artists, list) and len(artists) > 0 and isinstance(artists[0], dict):
                browse_id = artists[0].get("id")

        if not video_id:
            if browse_id:
                video_id = browse_id
                if not item.get("resultType"):
                    if "artist" in category or "profiles" in category: result_type = "artist"
                    elif "playlist" in category or "albums" in category: result_type = "playlist"
            else:
                return None
                
        raw_dur = item.get(duration_key)
        if raw_dur is None:
            raw_dur = item.get("duration") or item.get("length") or ""
            
        try:
            if isinstance(raw_dur, (int, float)) or (isinstance(raw_dur, str) and raw_dur.isdigit()):
                numeric_dur = int(raw_dur)
                minutes = numeric_dur // 60
                seconds = numeric_dur % 60
                duration = f"{minutes}:{seconds:02d}"
            else:
                duration = str(raw_dur).strip()
        except (ValueError, TypeError):
            duration = str(raw_dur).strip()

        if result_type == "artist":
            raw_title = _artist_line(item)
            if not raw_title or raw_title == "unknown artist":
                raw_title = str(item.get("artist") or item.get("title") or item.get("author") or "unknown artist")
        else:
            raw_title = str(item.get("title") or "untitled").strip()
            
        return Song(
            video_id=str(video_id).strip(),
            title=html.unescape(raw_title),
            artist=_artist_line(item),
            duration=duration,
            artwork_url=_artwork_url(item),
            type=result_type,
        )
