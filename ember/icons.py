"""
icons.py
FontAwesome 6 vector icon provider for Ember with dynamic Palette tinting.

Provides crisp, high-DPI vector icons for playback transport, library, search,
and window controls instead of fragile unicode glyphs.
"""

from __future__ import annotations

import logging
from typing import Optional

from PyQt6.QtGui import QIcon

from .config import Palette

log = logging.getLogger(__name__)

try:
    import qtawesome as qta
    HAS_QTAWESOME = True
except ImportError:
    HAS_QTAWESOME = False
    log.warning("qtawesome not found — vector icons will use fallback rendering")


def get_icon(name: str, color: Optional[str] = None, color_active: Optional[str] = None, scale_factor: float = 1.0) -> QIcon:
    """Load a FontAwesome vector icon tinted to specified or palette colors."""
    if not HAS_QTAWESOME:
        return QIcon()
    try:
        kwargs = {"scale_factor": scale_factor}
        if color:
            kwargs["color"] = color
        if color_active:
            kwargs["color_active"] = color_active
        return qta.icon(name, **kwargs)
    except Exception as exc:
        log.debug("Icon %r load error: %s", name, exc)
        return QIcon()


# ------------------------------------------------------------- transport
def play_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.play", color=color or Palette.ink, scale_factor=0.85)


def pause_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.pause", color=color or Palette.ink, scale_factor=0.85)


def forward_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.forward-step", color=color or Palette.muted, color_active=Palette.text, scale_factor=0.85)


def backward_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.backward-step", color=color or Palette.muted, color_active=Palette.text, scale_factor=0.85)


# ------------------------------------------------------------- window & nav
def expand_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.chevron-up", color=color or Palette.muted, color_active=Palette.text, scale_factor=0.85)


def collapse_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.chevron-down", color=color or Palette.muted, color_active=Palette.text, scale_factor=0.85)


def close_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.xmark", color=color or Palette.muted, color_active="#FFE8DF", scale_factor=0.9)


def settings_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.gear", color=color or Palette.muted, color_active=Palette.amber_hi, scale_factor=0.85)


# ------------------------------------------------------------- features
def heart_icon(active: bool = False) -> QIcon:
    if active:
        return get_icon("fa6s.heart", color=Palette.clay, scale_factor=0.9)
    return get_icon("fa6.heart", color=Palette.muted, color_active=Palette.clay, scale_factor=0.9)


def search_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.magnifying-glass", color=color or Palette.ink, scale_factor=0.85)


def queue_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.list-ul", color=color or Palette.muted, scale_factor=0.8)


def history_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.clock-rotate-left", color=color or Palette.muted, scale_factor=0.8)


def infinity_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.infinity", color=color or Palette.muted, scale_factor=0.85)


def fire_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.fire", color=color or Palette.amber, scale_factor=0.9)


def music_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.music", color=color or Palette.amber_hi, scale_factor=0.85)


def sliders_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.sliders", color=color or Palette.amber, scale_factor=0.85)


def palette_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.palette", color=color or Palette.amber, scale_factor=0.85)


def keyboard_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.keyboard", color=color or Palette.amber, scale_factor=0.85)


def shuffle_icon(active: bool = False) -> QIcon:
    return get_icon(
        "fa6s.shuffle",
        color=Palette.amber_hi if active else Palette.muted,
        color_active=Palette.amber_hi,
        scale_factor=0.85,
    )


def repeat_icon(mode: str = "off") -> QIcon:
    """Repeat mode icon: 'off', 'all', or 'one'."""
    is_active = mode in ("all", "one")
    return get_icon(
        "fa6s.repeat",
        color=Palette.amber_hi if is_active else Palette.muted,
        color_active=Palette.amber_hi,
        scale_factor=0.85,
    )


def lyrics_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.quote-right", color=color or Palette.muted, scale_factor=0.8)


def moon_icon(active: bool = False) -> QIcon:
    return get_icon(
        "fa6s.moon",
        color=Palette.amber_hi if active else Palette.muted,
        color_active=Palette.amber_hi,
        scale_factor=0.85,
    )


def gauge_icon(color: Optional[str] = None) -> QIcon:
    return get_icon("fa6s.gauge-high", color=color or Palette.muted, scale_factor=0.85)
