"""
storage.py
SQLite-backed persistent storage for local favorites and playback history.

Zero external dependencies (uses Python standard library sqlite3). Atomic,
concurrently safe for desktop reads/writes, and scales effortlessly.
"""

from __future__ import annotations

import logging
import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Generator, List, Optional

from .models import Song

log = logging.getLogger(__name__)

DB_FILENAME = "ember.db"


class EmberStorage:
    """Manages SQLite database for user favorites and playback history."""

    def __init__(self, db_path: Path | str) -> None:
        self.db_path = Path(db_path)
        self._ensure_tables()

    @contextmanager
    def _connection(self) -> Generator[sqlite3.Connection, None, None]:
        """Context manager guaranteeing connection closure, rollback, and proper locking."""
        conn = sqlite3.connect(str(self.db_path), timeout=10.0)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        except Exception:
            try:
                conn.rollback()
            except Exception:
                pass
            raise
        finally:
            conn.close()

    def close(self) -> None:
        """Explicit cleanup hook for application shutdown."""
        pass

    def _ensure_tables(self) -> None:
        """Initialize database tables and indexes."""
        try:
            self.db_path.parent.mkdir(parents=True, exist_ok=True)
            with self._connection() as conn:
                conn.execute("PRAGMA journal_mode=WAL;")
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS favorites (
                        video_id TEXT PRIMARY KEY,
                        title TEXT NOT NULL,
                        artist TEXT NOT NULL,
                        duration TEXT,
                        artwork_url TEXT,
                        added_at REAL NOT NULL
                    );
                    """
                )
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS history (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        video_id TEXT NOT NULL,
                        title TEXT NOT NULL,
                        artist TEXT NOT NULL,
                        duration TEXT,
                        artwork_url TEXT,
                        played_at REAL NOT NULL
                    );
                    """
                )
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_history_played ON history(played_at DESC);"
                )
                conn.commit()
            log.info("Ember storage initialized at %s", self.db_path)
        except Exception as exc:
            log.error("Failed to initialize Ember storage at %s: %s", self.db_path, exc)

    # ---------------------------------------------------------------- favorites
    def add_favorite(self, song: Song) -> None:
        """Add or update a track in the favorites collection."""
        if not song or not song.video_id:
            return
        try:
            with self._connection() as conn:
                conn.execute(
                    """
                    INSERT INTO favorites (video_id, title, artist, duration, artwork_url, added_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(video_id) DO UPDATE SET
                        title = excluded.title,
                        artist = excluded.artist,
                        duration = excluded.duration,
                        artwork_url = excluded.artwork_url,
                        added_at = excluded.added_at;
                    """,
                    (
                        song.video_id,
                        song.title,
                        song.artist,
                        song.duration,
                        song.artwork_url,
                        time.time(),
                    ),
                )
                conn.commit()
            log.info("Favorited: %s (%s)", song.title, song.video_id)
        except Exception as exc:
            log.error("Failed to add favorite %s: %s", song.video_id, exc)

    def remove_favorite(self, video_id: str) -> None:
        """Remove a track from favorites."""
        if not video_id:
            return
        try:
            with self._connection() as conn:
                conn.execute("DELETE FROM favorites WHERE video_id = ?;", (video_id,))
                conn.commit()
            log.info("Removed favorite: %s", video_id)
        except Exception as exc:
            log.error("Failed to remove favorite %s: %s", video_id, exc)

    def is_favorite(self, video_id: str) -> bool:
        """Check if a given video_id is favorited."""
        if not video_id:
            return False
        try:
            with self._connection() as conn:
                cursor = conn.execute(
                    "SELECT 1 FROM favorites WHERE video_id = ? LIMIT 1;", (video_id,)
                )
                return cursor.fetchone() is not None
        except Exception as exc:
            log.error("Failed to check favorite status for %s: %s", video_id, exc)
            return False

    def get_favorites(self) -> List[Song]:
        """Fetch all favorited songs ordered by addition time (newest first)."""
        songs: List[Song] = []
        try:
            with self._connection() as conn:
                cursor = conn.execute(
                    """
                    SELECT video_id, title, artist, duration, artwork_url
                    FROM favorites
                    ORDER BY added_at DESC;
                    """
                )
                for row in cursor.fetchall():
                    songs.append(
                        Song(
                            video_id=row["video_id"],
                            title=row["title"],
                            artist=row["artist"],
                            duration=row["duration"] or "",
                            artwork_url=row["artwork_url"] or "",
                        )
                    )
        except Exception as exc:
            log.error("Failed to load favorites: %s", exc)
        return songs

    # ------------------------------------------------------------------ history
    def record_history(self, song: Song) -> None:
        """Record a played track into history, pruning old entries past 300 items."""
        if not song or not song.video_id:
            return
        try:
            with self._connection() as conn:
                conn.execute(
                    """
                    INSERT INTO history (video_id, title, artist, duration, artwork_url, played_at)
                    VALUES (?, ?, ?, ?, ?, ?);
                    """,
                    (
                        song.video_id,
                        song.title,
                        song.artist,
                        song.duration,
                        song.artwork_url,
                        time.time(),
                    ),
                )
                # Keep max 300 history rows to keep database lean
                conn.execute(
                    """
                    DELETE FROM history WHERE id NOT IN (
                        SELECT id FROM history ORDER BY played_at DESC LIMIT 300
                    );
                    """
                )
                conn.commit()
            log.debug("Recorded playback history for %s", song.video_id)
        except Exception as exc:
            log.error("Failed to record history for %s: %s", song.video_id, exc)

    def get_history(self, limit: int = 50) -> List[Song]:
        """Fetch recently played tracks (newest first, unique tracks preserved)."""
        songs: List[Song] = []
        try:
            with self._connection() as conn:
                cursor = conn.execute(
                    """
                    SELECT video_id, title, artist, duration, artwork_url, MAX(played_at) AS last_played
                    FROM history
                    GROUP BY video_id
                    ORDER BY last_played DESC
                    LIMIT ?;
                    """,
                    (limit,),
                )
                for row in cursor.fetchall():
                    songs.append(
                        Song(
                            video_id=row["video_id"],
                            title=row["title"],
                            artist=row["artist"],
                            duration=row["duration"] or "",
                            artwork_url=row["artwork_url"] or "",
                        )
                    )
        except Exception as exc:
            log.error("Failed to fetch playback history: %s", exc)
        return songs

    def clear_history(self) -> None:
        """Clear all playback history."""
        try:
            with self._connection() as conn:
                conn.execute("DELETE FROM history;")
                conn.commit()
            log.info("Playback history cleared")
        except Exception as exc:
            log.error("Failed to clear history: %s", exc)
