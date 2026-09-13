"""
utils.py
Small helpers with no dependencies on the rest of the package.
"""

from __future__ import annotations

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QFontMetrics
from PyQt6.QtWidgets import QLabel


def clock(ms: int) -> str:
    """Milliseconds to a human clock string. Drops the hour field when unused."""
    total = max(0, int(ms or 0)) // 1000
    hours, rest = divmod(total, 3600)
    minutes, seconds = divmod(rest, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{seconds:02d}"
    return f"{minutes}:{seconds:02d}"


def elide_into(label: QLabel, text: str, width: int) -> None:
    """Write text into a fixed-width label, ellipsised to fit, tooltip full value."""
    label.ensurePolished()
    metrics = QFontMetrics(label.font())
    label.setText(metrics.elidedText(text or "", Qt.TextElideMode.ElideRight, max(24, width)))
    label.setToolTip(text or "")


def looks_like_link(text: str) -> bool:
    """True when the field holds something we should hand straight to the resolver."""
    probe = (text or "").strip().lower()
    return (
        probe.startswith("http://")
        or probe.startswith("https://")
        or "youtu.be/" in probe
        or "youtube.com/watch" in probe
    )


def pretty_count(value: int, singular: str, plural: str = "") -> str:
    """'1 track' / '12 tracks' without the caller doing the branch."""
    word = singular if value == 1 else (plural or singular + "s")
    return f"{value} {word}"