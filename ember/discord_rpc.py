"""
discord_rpc.py
Discord Rich Presence (RPC) integration for Ember.
Broadcasts active track, artist, album art, and progress bar
to your Discord profile without blocking the UI thread.
"""

from __future__ import annotations

import logging
import threading
import time
from typing import Optional

from PyQt6.QtCore import QObject

log = logging.getLogger(__name__)

_PYPRESENCE_AVAILABLE = False
try:
    from pypresence import Presence

    _PYPRESENCE_AVAILABLE = True
except Exception as _err:
    log.debug("pypresence unavailable: %s", _err)

# Default public Ember Discord Application Client ID
DEFAULT_CLIENT_ID = "128456789012345678"
MIN_UPDATE_INTERVAL = 4.0  # seconds between RPC pushes (Discord allows ~1/15s, 4s safe max)


class DiscordPresence(QObject):
    """Manages asynchronous Discord Rich Presence connection and updates."""

    def __init__(
        self,
        client_id: str = DEFAULT_CLIENT_ID,
        parent: Optional[QObject] = None,
    ) -> None:
        super().__init__(parent)
        self.client_id = client_id
        self._rpc: Optional[Presence] = None
        self._connected = False
        self._lock = threading.Lock()
        self._last_update_ts = 0.0
        self._last_state_key = ""

    def connect_async(self) -> None:
        """Attempt to connect to the local Discord desktop client in the background."""
        if not _PYPRESENCE_AVAILABLE or self._connected:
            return
        threading.Thread(target=self._try_connect, daemon=True).start()

    def _try_connect(self) -> None:
        with self._lock:
            if self._connected:
                return
            try:
                self._rpc = Presence(self.client_id)
                self._rpc.connect()
                self._connected = True
                log.info("Connected to Discord Rich Presence")
            except Exception as exc:
                log.debug("Discord client not detected or RPC connection failed: %s", exc)
                self._connected = False
                self._rpc = None

    def update(
        self,
        title: str,
        artist: str,
        position_ms: int = 0,
        duration_ms: int = 0,
        is_playing: bool = True,
    ) -> None:
        """Push current playback state to Discord."""
        if not _PYPRESENCE_AVAILABLE:
            return

        now = time.time()
        state_key = f"{title}:{artist}:{is_playing}"
        # Throttle unless track or playback state changed
        if state_key == self._last_state_key and now - self._last_update_ts < MIN_UPDATE_INTERVAL:
            return

        if not self._connected:
            self.connect_async()
            return

        threading.Thread(
            target=self._do_update,
            args=(title, artist, position_ms, duration_ms, is_playing),
            daemon=True,
        ).start()

    def _do_update(
        self,
        title: str,
        artist: str,
        position_ms: int,
        duration_ms: int,
        is_playing: bool,
    ) -> None:
        with self._lock:
            if not self._connected or not self._rpc:
                return
            try:
                kwargs: dict[str, Any] = {
                    "details": str(title)[:128] if title else "Listening",
                    "state": f"by {artist}"[:128] if artist else "Ember",
                    "large_image": "ember_logo",
                    "large_text": "Ember — Floating Music Companion",
                }

                if is_playing:
                    now = time.time()
                    elapsed_sec = max(0, position_ms // 1000)
                    kwargs["start"] = int(now - elapsed_sec)
                    if duration_ms > 0:
                        remaining_sec = max(0, (duration_ms - position_ms) // 1000)
                        kwargs["end"] = int(now + remaining_sec)
                    kwargs["small_image"] = "play"
                    kwargs["small_text"] = "Playing"
                else:
                    kwargs["small_image"] = "pause"
                    kwargs["small_text"] = "Paused"

                self._rpc.update(**kwargs)
                self._last_update_ts = time.time()
                self._last_state_key = f"{title}:{artist}:{is_playing}"
            except Exception as exc:
                log.debug("Failed to push Discord presence update: %s", exc)
                self._connected = False
                self._rpc = None

    def clear(self) -> None:
        """Clear the Discord presence card."""
        with self._lock:
            if self._connected and self._rpc:
                try:
                    self._rpc.clear()
                except Exception:
                    pass

    def close(self) -> None:
        """Close presence connection cleanly."""
        with self._lock:
            if self._rpc:
                try:
                    self._rpc.close()
                except Exception:
                    pass
                self._rpc = None
                self._connected = False
