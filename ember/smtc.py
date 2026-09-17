"""
smtc.py
Native Windows System Media Transport Controls (SMTC) integration.
Binds Ember to the Windows 10/11 volume overlay, lock screen controls,
and hardware media keys.
"""

from __future__ import annotations

import logging
from typing import Any, Optional

from PyQt6.QtCore import QObject, pyqtSignal

log = logging.getLogger(__name__)

# Lazy flag for WinRT availability
_WINRT_AVAILABLE = False
try:
    import winrt.windows.foundation as wf
    import winrt.windows.media as wm
    import winrt.windows.media.playback as wmp
    import winrt.windows.storage.streams as wss

    _WINRT_AVAILABLE = True
except Exception as _import_err:
    log.debug("WinRT SMTC modules unavailable: %s", _import_err)


class WindowsMediaControls(QObject):
    """Integrates Ember with Windows 10/11 native SMTC media overlay."""

    play_requested = pyqtSignal()
    pause_requested = pyqtSignal()
    toggle_requested = pyqtSignal()
    next_requested = pyqtSignal()
    previous_requested = pyqtSignal()
    stop_requested = pyqtSignal()

    def __init__(self, parent: Optional[QObject] = None) -> None:
        super().__init__(parent)
        self._enabled = False
        self._player: Any = None
        self._smtc: Any = None
        self._token: Any = None

        if not _WINRT_AVAILABLE:
            return

        try:
            self._player = wmp.MediaPlayer()
            # CommandManager can conflict with manual SMTC control; disable it
            try:
                self._player.command_manager.is_enabled = False
            except Exception:
                pass

            self._smtc = self._player.system_media_transport_controls
            self._smtc.is_enabled = True
            self._smtc.is_play_enabled = True
            self._smtc.is_pause_enabled = True
            self._smtc.is_next_enabled = True
            self._smtc.is_previous_enabled = True
            self._smtc.is_stop_enabled = True

            self._token = self._smtc.add_button_pressed(self._on_button_pressed)
            self._enabled = True
            log.info("Windows System Media Transport Controls initialized successfully")
        except Exception as exc:
            log.debug("Failed to initialize Windows SMTC: %s", exc)
            self._enabled = False

    @property
    def is_available(self) -> bool:
        """True if Windows SMTC is active."""
        return self._enabled

    def update_metadata(self, title: str, artist: str, artwork_url: str = "") -> None:
        """Update the floating Windows media overlay with current track details."""
        if not self._enabled or not self._smtc:
            return
        try:
            updater = self._smtc.display_updater
            updater.type = wm.MediaPlaybackType.MUSIC
            music = updater.music_properties
            music.title = str(title or "Untitled")
            music.artist = str(artist or "Ember")

            if artwork_url and (artwork_url.startswith("http://") or artwork_url.startswith("https://")):
                try:
                    uri = wf.Uri(artwork_url)
                    updater.thumbnail = wss.RandomAccessStreamReference.create_from_uri(uri)
                except Exception as thumb_err:
                    log.debug("SMTC thumbnail URI parse failed: %s", thumb_err)

            updater.update()
        except Exception as exc:
            log.debug("Failed to update SMTC display metadata: %s", exc)

    def set_playback_status(self, is_playing: bool) -> None:
        """Inform Windows whether audio is playing or paused."""
        if not self._enabled or not self._smtc:
            return
        try:
            status = (
                wm.MediaPlaybackStatus.PLAYING
                if is_playing
                else wm.MediaPlaybackStatus.PAUSED
            )
            self._smtc.playback_status = status
        except Exception as exc:
            log.debug("Failed to update SMTC playback status: %s", exc)

    def _on_button_pressed(self, sender: Any, args: Any) -> None:
        """Handle button clicks from Windows overlay or keyboard media chords."""
        try:
            btn = args.button
            if btn == wm.SystemMediaTransportControlsButton.PLAY:
                self.play_requested.emit()
            elif btn == wm.SystemMediaTransportControlsButton.PAUSE:
                self.pause_requested.emit()
            elif btn == wm.SystemMediaTransportControlsButton.NEXT:
                self.next_requested.emit()
            elif btn == wm.SystemMediaTransportControlsButton.PREVIOUS:
                self.previous_requested.emit()
            elif btn == wm.SystemMediaTransportControlsButton.STOP:
                self.stop_requested.emit()
        except Exception as exc:
            log.debug("Error processing SMTC button event: %s", exc)

    def close(self) -> None:
        """Cleanly detach button listener and clear SMTC display."""
        if not self._enabled or not self._smtc:
            return
        try:
            if self._token is not None:
                self._smtc.remove_button_pressed(self._token)
                self._token = None
            self._smtc.playback_status = wm.MediaPlaybackStatus.CLOSED
            self._smtc.display_updater.clear_all()
        except Exception as exc:
            log.debug("Error releasing SMTC resources: %s", exc)
        self._enabled = False
