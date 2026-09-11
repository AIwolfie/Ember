"""
Helpers for stable Qt audio-output device selection.
"""

from __future__ import annotations

import base64
from typing import Optional

from PyQt6.QtMultimedia import QAudioDevice, QMediaDevices

DEFAULT_AUDIO_DEVICE_ID = "default"


def device_key(device: QAudioDevice) -> str:
    """Return a QSettings-safe key for a Qt audio device."""
    raw = device.id()
    try:
        payload = bytes(raw)
    except TypeError:
        payload = str(raw).encode("utf-8", errors="surrogatepass")
    return base64.urlsafe_b64encode(payload).decode("ascii")


def audio_outputs() -> list[QAudioDevice]:
    """Current output devices reported by Qt."""
    return list(QMediaDevices.audioOutputs())


def find_audio_output(device_id: str) -> Optional[QAudioDevice]:
    """Find output device by persisted key, or None when default/unavailable."""
    if not device_id or device_id == DEFAULT_AUDIO_DEVICE_ID:
        return None
    for device in audio_outputs():
        if device_key(device) == device_id:
            return device
    return None
