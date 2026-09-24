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
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS playlists (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name TEXT NOT NULL,
                        source_type TEXT DEFAULT 'custom',
                        source_url TEXT DEFAULT '',
                        created_at REAL NOT NULL
                    );
                    """
                )
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS playlist_tracks (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        playlist_id INTEGER NOT NULL,
                        video_id TEXT NOT NULL,
                        title TEXT NOT NULL,
                        artist TEXT NOT NULL,
                        duration TEXT,
                        artwork_url TEXT,
                        position INTEGER NOT NULL,
                        FOREIGN KEY(playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
                    );
                    """
                )
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_playlist_tracks ON playlist_tracks(playlist_id, position);"
                )

                # Schema migrations for existing databases
                pl_cols = {
                    row["name"]
                    for row in conn.execute("PRAGMA table_info(playlists);").fetchall()
                }
                if "source_type" not in pl_cols:
                    conn.execute("ALTER TABLE playlists ADD COLUMN source_type TEXT DEFAULT 'custom';")
                if "source_url" not in pl_cols:
                    conn.execute("ALTER TABLE playlists ADD COLUMN source_url TEXT DEFAULT '';")

                track_cols = {
                    row["name"]
                    for row in conn.execute("PRAGMA table_info(playlist_tracks);").fetchall()
                }
                if "position" not in track_cols and track_cols:
                    conn.execute("ALTER TABLE playlist_tracks ADD COLUMN position INTEGER DEFAULT 0;")

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

    # ---------------------------------------------------------------- playlists
    def create_playlist(self, name: str, source_type: str = "custom", source_url: str = "") -> int:
        """Create a new playlist and return its ID."""
        clean_name = (name or "").strip() or "Untitled Playlist"
        with self._connection() as conn:
            cursor = conn.execute(
                """
                INSERT INTO playlists (name, source_type, source_url, created_at)
                VALUES (?, ?, ?, ?);
                """,
                (clean_name, source_type, source_url, time.time()),
            )
            conn.commit()
            return int(cursor.lastrowid)

    def delete_playlist(self, playlist_id: int) -> bool:
        """Delete a playlist and all its contained tracks."""
        with self._connection() as conn:
            conn.execute("DELETE FROM playlist_tracks WHERE playlist_id = ?;", (playlist_id,))
            cursor = conn.execute("DELETE FROM playlists WHERE id = ?;", (playlist_id,))
            conn.commit()
            return cursor.rowcount > 0

    def rename_playlist(self, playlist_id: int, new_name: str) -> bool:
        """Rename an existing playlist."""
        clean_name = (new_name or "").strip() or "Untitled Playlist"
        with self._connection() as conn:
            cursor = conn.execute(
                "UPDATE playlists SET name = ? WHERE id = ?;",
                (clean_name, playlist_id),
            )
            conn.commit()
            return cursor.rowcount > 0

    def get_playlists(self) -> List[Dict[str, Any]]:
        """Return all playlists with track counts and metadata ordered by most recent."""
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT p.id, p.name, p.source_type, p.source_url, p.created_at,
                       COUNT(t.rowid) as track_count
                FROM playlists p
                LEFT JOIN playlist_tracks t ON p.id = t.playlist_id
                GROUP BY p.id
                ORDER BY p.created_at DESC;
                """
            ).fetchall()
            return [dict(r) for r in rows]

    def get_playlist(self, playlist_id: int) -> Optional[Dict[str, Any]]:
        """Return a single playlist with metadata and track count, or None if not found."""
        with self._connection() as conn:
            row = conn.execute(
                """
                SELECT p.id, p.name, p.source_type, p.source_url, p.created_at,
                       COUNT(t.rowid) as track_count
                FROM playlists p
                LEFT JOIN playlist_tracks t ON p.id = t.playlist_id
                WHERE p.id = ?
                GROUP BY p.id;
                """,
                (playlist_id,),
            ).fetchone()
            return dict(row) if row else None

    def get_playlist_tracks(self, playlist_id: int) -> List[Song]:
        """Return all songs in a playlist ordered by their playlist position."""
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT video_id, title, artist, duration, artwork_url
                FROM playlist_tracks
                WHERE playlist_id = ?
                ORDER BY position ASC;
                """,
                (playlist_id,),
            ).fetchall()
            return [
                Song(
                    video_id=r["video_id"],
                    title=r["title"],
                    artist=r["artist"],
                    duration=r["duration"] or "",
                    artwork_url=r["artwork_url"] or "",
                )
                for r in rows
            ]

    def add_tracks_to_playlist(self, playlist_id: int, songs: List[Song]) -> None:
        """Append songs to a playlist preserving order and skipping duplicates."""
        if not songs:
            return
        with self._connection() as conn:
            max_pos_row = conn.execute(
                "SELECT COALESCE(MAX(position), -1) as max_pos FROM playlist_tracks WHERE playlist_id = ?;",
                (playlist_id,),
            ).fetchone()
            current_pos = max_pos_row["max_pos"] + 1

            existing_vids = {
                r["video_id"]
                for r in conn.execute(
                    "SELECT video_id FROM playlist_tracks WHERE playlist_id = ?;",
                    (playlist_id,),
                ).fetchall()
            }

            records = []
            for s in songs:
                if not s or not s.video_id or s.video_id in existing_vids:
                    continue
                existing_vids.add(s.video_id)
                records.append(
                    (
                        playlist_id,
                        s.video_id,
                        s.title,
                        s.artist,
                        s.duration or "",
                        s.artwork_url or "",
                        current_pos,
                    )
                )
                current_pos += 1

            if records:
                conn.executemany(
                    """
                    INSERT INTO playlist_tracks
                    (playlist_id, video_id, title, artist, duration, artwork_url, position)
                    VALUES (?, ?, ?, ?, ?, ?, ?);
                    """,
                    records,
                )
                conn.commit()

    def remove_track_from_playlist(self, playlist_id: int, video_id: str) -> None:
        """Remove a track from a playlist and re-compact track positions."""
        with self._connection() as conn:
            conn.execute(
                "DELETE FROM playlist_tracks WHERE playlist_id = ? AND video_id = ?;",
                (playlist_id, video_id),
            )
            rows = conn.execute(
                "SELECT rowid FROM playlist_tracks WHERE playlist_id = ? ORDER BY position ASC;",
                (playlist_id,),
            ).fetchall()
            for idx, r in enumerate(rows):
                conn.execute(
                    "UPDATE playlist_tracks SET position = ? WHERE rowid = ?;",
                    (idx, r[0]),
                )
            conn.commit()

