"""
cache.py
Persistent LRU audio disk cache for Ember.
Stores downloaded audio streams locally to eliminate redundant network hits,
speed up track loading to 0ms, and enable offline playback.
"""

from __future__ import annotations

import logging
import os
import shutil
import threading
from pathlib import Path
from typing import Optional

from PyQt6.QtCore import QStandardPaths

log = logging.getLogger(__name__)

DEFAULT_MAX_BYTES = 500 * 1024 * 1024  # 500 MB default LRU cache cap


class AudioDiskCache:
    """Thread-safe persistent LRU disk cache for audio tracks."""

    def __init__(
        self,
        cache_dir: Optional[Path] = None,
        max_bytes: int = DEFAULT_MAX_BYTES,
        enabled: bool = True,
    ) -> None:
        if cache_dir is None:
            base = QStandardPaths.writableLocation(
                QStandardPaths.StandardLocation.CacheLocation
            ) or str(Path.home() / ".cache")
            cache_dir = Path(base) / "ember" / "tracks"

        self.cache_dir = Path(cache_dir)
        self.max_bytes = max_bytes
        self.enabled = enabled
        self._lock = threading.Lock()

        if self.enabled:
            self._ensure_dir()

    def _ensure_dir(self) -> None:
        try:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            log.warning("Failed to create audio cache directory %s: %s", self.cache_dir, exc)

    def _track_path(self, video_id: str, ext: str = "m4a") -> Path:
        clean_id = "".join(c for c in video_id if c.isalnum() or c in "-_.")
        return self.cache_dir / f"{clean_id}.{ext}"

    def has(self, video_id: str) -> bool:
        """True if video_id exists on disk and has non-zero size."""
        if not self.enabled or not video_id:
            return False
        with self._lock:
            for ext in ("m4a", "opus", "webm", "mp3", "flac"):
                p = self._track_path(video_id, ext)
                if p.is_file() and p.stat().st_size > 0:
                    return True
            return False

    def get_path(self, video_id: str) -> Optional[Path]:
        """Return local Path if cached, updating its access time for LRU tracking."""
        if not self.enabled or not video_id:
            return None
        with self._lock:
            for ext in ("m4a", "opus", "webm", "mp3", "flac"):
                p = self._track_path(video_id, ext)
                if p.is_file() and p.stat().st_size > 0:
                    try:
                        p.touch(exist_ok=True)
                    except OSError:
                        pass
                    return p
            return None

    def store(self, video_id: str, data: bytes, ext: str = "m4a") -> Optional[Path]:
        """Write track bytes to disk and trigger LRU eviction if size exceeded."""
        if not self.enabled or not video_id or not data:
            return None
        with self._lock:
            self._ensure_dir()
            target = self._track_path(video_id, ext)
            temp_path = target.with_suffix(".tmp")
            try:
                with open(temp_path, "wb") as f:
                    f.write(data)
                temp_path.replace(target)
                log.info("Cached track %s to disk (%d bytes)", video_id, len(data))
                self._prune_under_lock()
                return target
            except OSError as exc:
                log.warning("Failed to write track %s to disk cache: %s", video_id, exc)
                if temp_path.exists():
                    try:
                        temp_path.unlink()
                    except OSError:
                        pass
                return None

    def store_file(self, video_id: str, src_path: Path, ext: str = "m4a") -> Optional[Path]:
        """Copy an already downloaded file into the cache."""
        if not self.enabled or not video_id or not src_path.is_file():
            return None
        with self._lock:
            self._ensure_dir()
            target = self._track_path(video_id, ext)
            try:
                shutil.copy2(src_path, target)
                self._prune_under_lock()
                return target
            except OSError as exc:
                log.warning("Failed to copy %s to cache: %s", src_path, exc)
                return None

    def total_size_bytes(self) -> int:
        """Calculate total bytes currently used by cached tracks."""
        if not self.cache_dir.is_dir():
            return 0
        total = 0
        try:
            for entry in os.scandir(self.cache_dir):
                if entry.is_file() and not entry.name.endswith(".tmp"):
                    total += entry.stat().st_size
        except OSError:
            pass
        return total

    def _prune_under_lock(self) -> None:
        """Evict least recently accessed files when total size exceeds max_bytes."""
        if not self.cache_dir.is_dir() or self.max_bytes <= 0:
            return
        files = []
        total = 0
        try:
            for entry in os.scandir(self.cache_dir):
                if entry.is_file() and not entry.name.endswith(".tmp"):
                    stat = entry.stat()
                    files.append((stat.st_mtime, stat.st_size, Path(entry.path)))
                    total += stat.st_size
        except OSError:
            return

        if total <= self.max_bytes:
            return

        # Sort oldest first (LRU)
        files.sort(key=lambda x: x[0])
        for _mtime, size, path in files:
            try:
                path.unlink(missing_ok=True)
                total -= size
                log.debug("LRU evicted cached track: %s", path.name)
            except OSError:
                pass
            if total <= self.max_bytes:
                break

    def clear(self) -> None:
        """Purge all cached audio tracks."""
        with self._lock:
            if not self.cache_dir.is_dir():
                return
            for entry in os.scandir(self.cache_dir):
                try:
                    if entry.is_file():
                        os.unlink(entry.path)
                except OSError:
                    pass
            log.info("Audio disk cache cleared")
