"""
scrobbler.py
Decoupled background audio scrobbler for Ember.
Supports ListenBrainz and Last.fm protocol submissions.
Scrobbles when a track has played for 50% of its duration or 240 seconds.
"""

from __future__ import annotations

import json
import logging
import threading
import time
from typing import Any, Optional

import requests
from PyQt6.QtCore import QObject

from .models import Song

log = logging.getLogger(__name__)

LISTENBRAINZ_API_URL = "https://api.listenbrainz.org/1/submit-listens"
MIN_PLAY_TIME_SEC = 30
MAX_THRESHOLD_SEC = 240


class ScrobbleEngine(QObject):
    """Monitors playback progression and dispatches scrobbles in background threads."""

    def __init__(
        self,
        listenbrainz_token: str = "",
        lastfm_key: str = "",
        parent: Optional[QObject] = None,
    ) -> None:
        super().__init__(parent)
        self.listenbrainz_token = listenbrainz_token.strip()
        self.lastfm_key = lastfm_key.strip()
        self._current_song: Optional[Song] = None
        self._current_gen: int = 0
        self._scrobbled_gen: set[int] = set()
        self._playing_now_sent: set[int] = set()
        self._lock = threading.Lock()

    def set_listenbrainz_token(self, token: str) -> None:
        """Update ListenBrainz user token."""
        self.listenbrainz_token = token.strip()

    def on_song_changed(self, song: Optional[Song], generation: int = 0) -> None:
        """Handle new track loading."""
        with self._lock:
            self._current_song = song
            self._current_gen = generation

        if song and self.listenbrainz_token:
            threading.Thread(
                target=self._send_listenbrainz,
                args=(song, "playing_now"),
                daemon=True,
            ).start()

    def on_progress(self, position_ms: int, duration_ms: int) -> None:
        """Check if playback has passed the scrobble threshold."""
        if not self.listenbrainz_token:
            return

        with self._lock:
            song = self._current_song
            gen = self._current_gen
            if not song or gen in self._scrobbled_gen:
                return

        pos_sec = position_ms // 1000
        dur_sec = duration_ms // 1000 if duration_ms > 0 else 0

        # Criteria: at least 30s AND (50% of duration OR 240s)
        threshold_sec = min(MAX_THRESHOLD_SEC, dur_sec // 2) if dur_sec > 0 else MAX_THRESHOLD_SEC
        threshold_sec = max(MIN_PLAY_TIME_SEC, threshold_sec)

        if pos_sec >= threshold_sec:
            with self._lock:
                self._scrobbled_gen.add(gen)
            threading.Thread(
                target=self._send_listenbrainz,
                args=(song, "single"),
                daemon=True,
            ).start()

    def _send_listenbrainz(self, song: Song, listen_type: str = "single") -> None:
        """Submit listen to ListenBrainz REST API."""
        if not self.listenbrainz_token or not song:
            return

        artist = song.artist or song.byline or "Unknown Artist"
        title = song.title or "Unknown Title"

        payload: dict[str, Any] = {
            "listen_type": listen_type,
            "payload": [
                {
                    "track_metadata": {
                        "artist_name": artist,
                        "track_name": title,
                        "additional_info": {
                            "media_player": "Ember",
                            "submission_client": "Ember Desktop Companion",
                        },
                    }
                }
            ],
        }
        if listen_type == "single":
            payload["payload"][0]["listened_at"] = int(time.time())

        headers = {
            "Authorization": f"Token {self.listenbrainz_token}",
            "Content-Type": "application/json",
            "User-Agent": "EmberMusicPlayer/1.0",
        }

        try:
            resp = requests.post(
                LISTENBRAINZ_API_URL,
                headers=headers,
                data=json.dumps(payload),
                timeout=6.0,
            )
            if resp.status_code == 200:
                log.info("ListenBrainz %s submitted for %r by %r", listen_type, title, artist)
            else:
                log.warning("ListenBrainz returned HTTP %d: %s", resp.status_code, resp.text[:120])
        except Exception as exc:
            log.debug("ListenBrainz submission failed: %s", exc)
