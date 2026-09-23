"""
exporter.py
1-Click Offline Music Exporter for Ember.

Takes cached or streamed tracks, embeds high-resolution album artwork,
injects standardized ID3 / MP4 / Vorbis metadata tags via mutagen, and
deposits organized audio files into ~/Music/Ember/<Artist>/<Title>.<ext>.
"""

from __future__ import annotations

import logging
import os
import re
import shutil
from pathlib import Path
from typing import Optional

import requests

from .cache import AudioDiskCache
from .models import Song
from .stream import StreamResolver

log = logging.getLogger(__name__)

# Characters invalid on Windows, macOS, or Linux filesystems
INVALID_FS_CHARS = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def sanitize_filename(name: str, max_length: int = 120) -> str:
    """Sanitize track or artist names for safe multiplatform filesystem paths."""
    cleaned = INVALID_FS_CHARS.sub("", name).strip()
    # Strip trailing periods/spaces which Windows dislikes
    cleaned = cleaned.rstrip(". ")
    if not cleaned:
        cleaned = "untitled"
    return cleaned[:max_length]


class AudioExporter:
    """Exports audio tracks to local library directory with embedded metadata tags."""

    def __init__(
        self,
        cache: Optional[AudioDiskCache] = None,
        resolver: Optional[StreamResolver] = None,
        base_dir: Optional[Path] = None,
    ) -> None:
        self.cache = cache
        self.resolver = resolver or StreamResolver()
        self.base_dir = base_dir or (Path.home() / "Music" / "Ember")

    def export_song(self, song: Song, custom_dest: Optional[Path] = None) -> Path:
        """
        Export a Song to the destination library path with embedded artwork and tags.
        Returns the absolute Path of the exported file.
        """
        artist_dir = sanitize_filename(song.artist or "Unknown Artist")
        title_name = sanitize_filename(song.title or "Untitled")

        # Find existing source audio file (from cache or local file)
        src_path: Optional[Path] = None
        ext = "m4a"

        if song.video_id.startswith("local_"):
            local_candidate = Path(song.video_id.replace("local_", "", 1))
            if local_candidate.exists():
                src_path = local_candidate
                ext = local_candidate.suffix.lstrip(".").lower() or "m4a"

        if src_path is None and self.cache is not None:
            cached = self.cache.get_path(song.video_id)
            if cached is not None and cached.exists():
                src_path = cached
                ext = cached.suffix.lstrip(".").lower() or "m4a"

        target_dir = custom_dest.parent if custom_dest else (self.base_dir / artist_dir)
        target_dir.mkdir(parents=True, exist_ok=True)
        final_dest = custom_dest or (target_dir / f"{title_name}.{ext}")

        # If we have a local source file, copy it directly
        if src_path is not None and src_path.exists():
            shutil.copyfile(src_path, final_dest)
        else:
            # Download audio stream directly
            stream_url = song.stream_url
            if not stream_url:
                stream_url = self.resolver.resolve(song.video_id)
            if not stream_url:
                raise RuntimeError(f"Could not resolve audio stream for track: {song.title}")

            resp = requests.get(
                stream_url,
                stream=True,
                timeout=20,
                headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"},
            )
            resp.raise_for_status()

            temp_dest = final_dest.with_suffix(f".tmp_{os.getpid()}")
            with open(temp_dest, "wb") as fh:
                for chunk in resp.iter_content(chunk_size=65536):
                    if chunk:
                        fh.write(chunk)
            temp_dest.replace(final_dest)

        # Embed metadata & artwork
        self._tag_audio_file(final_dest, song)
        log.info("Successfully exported track to %s", final_dest)
        return final_dest

    def _fetch_artwork(self, url: str) -> Optional[bytes]:
        """Fetch raw image bytes for embedding in audio metadata."""
        if not url:
            return None
        try:
            resp = requests.get(url, timeout=10)
            if resp.status_code == 200 and resp.content:
                return resp.content
        except Exception as exc:
            log.debug("Failed fetching cover art from %s: %s", url, exc)
        return None

    def _tag_audio_file(self, file_path: Path, song: Song) -> None:
        """Inject artist, title, album and cover art using mutagen."""
        try:
            import mutagen
            from mutagen.mp4 import MP4, MP4Cover
            from mutagen.flac import FLAC, Picture
            from mutagen.oggopus import OggOpus
            from mutagen.oggvorbis import OggVorbis
            from mutagen.id3 import ID3, TIT2, TPE1, TALB, APIC, ID3NoHeaderError
        except ImportError:
            log.warning("mutagen not installed; audio exported without embedded tags.")
            return

        art_bytes = self._fetch_artwork(song.artwork_url)
        ext = file_path.suffix.lower()

        try:
            if ext in (".m4a", ".mp4"):
                mp4 = MP4(file_path)
                mp4["\xa9nam"] = [song.title]
                mp4["\xa9ART"] = [song.artist or "Unknown Artist"]
                mp4["\xa9alb"] = ["Ember Music Library"]
                if art_bytes:
                    fmt = MP4Cover.FORMAT_PNG if art_bytes.startswith(b"\x89PNG") else MP4Cover.FORMAT_JPEG
                    mp4["covr"] = [MP4Cover(art_bytes, imageformat=fmt)]
                mp4.save()

            elif ext == ".flac":
                audio = FLAC(file_path)
                audio["title"] = song.title
                audio["artist"] = song.artist or "Unknown Artist"
                audio["album"] = "Ember Music Library"
                if art_bytes:
                    pic = Picture()
                    pic.data = art_bytes
                    pic.type = 3  # front cover
                    pic.mime = "image/png" if art_bytes.startswith(b"\x89PNG") else "image/jpeg"
                    audio.add_picture(pic)
                audio.save()

            elif ext in (".opus", ".ogg"):
                try:
                    audio = OggOpus(file_path)
                except Exception:
                    audio = OggVorbis(file_path)
                audio["title"] = [song.title]
                audio["artist"] = [song.artist or "Unknown Artist"]
                audio["album"] = ["Ember Music Library"]
                audio.save()

            elif ext == ".mp3":
                try:
                    tags = ID3(file_path)
                except ID3NoHeaderError:
                    tags = ID3()
                tags.add(TIT2(encoding=3, text=song.title))
                tags.add(TPE1(encoding=3, text=song.artist or "Unknown Artist"))
                tags.add(TALB(encoding=3, text="Ember Music Library"))
                if art_bytes:
                    mime = "image/png" if art_bytes.startswith(b"\x89PNG") else "image/jpeg"
                    tags.add(APIC(encoding=3, mime=mime, type=3, desc="Cover", data=art_bytes))
                tags.save(file_path)

        except Exception as exc:
            log.warning("Could not write audio tags for %s: %s", file_path, exc)
