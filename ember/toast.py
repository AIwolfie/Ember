"""
toast.py
Subtle, non-intrusive "Now Playing" desktop toast notification.

Matches Ember's palette, renders album art and track info, stays on top,
and never steals keyboard or window focus.
"""

from __future__ import annotations

import logging
from typing import Optional

from PyQt6.QtCore import (
    QEasingCurve,
    QPoint,
    QPropertyAnimation,
    QRectF,
    QSize,
    Qt,
    QTimer,
)
from PyQt6.QtGui import QColor, QPainter, QPainterPath, QPixmap
from PyQt6.QtWidgets import (
    QApplication,
    QFrame,
    QGraphicsDropShadowEffect,
    QGraphicsOpacityEffect,
    QHBoxLayout,
    QLabel,
    QVBoxLayout,
    QWidget,
)

from .config import Palette
from .icons import download_icon, music_icon
from .models import Song
from .theme import toast_stylesheet
from .utils import elide_into

log = logging.getLogger(__name__)

TOAST_WIDTH = 290
TOAST_HEIGHT = 68
TOAST_DISPLAY_MS = 3200
MARGIN = 8


def _rounded_thumb(source: QPixmap, side: int = 44) -> QPixmap:
    """Create a high-quality rounded square thumbnail."""
    if source.isNull():
        canvas = QPixmap(side, side)
        canvas.fill(Qt.GlobalColor.transparent)
        return canvas
    scaled = source.scaled(
        QSize(side, side),
        Qt.AspectRatioMode.KeepAspectRatioByExpanding,
        Qt.TransformationMode.SmoothTransformation,
    )
    cropped = scaled.copy(
        (scaled.width() - side) // 2, (scaled.height() - side) // 2, side, side
    )
    canvas = QPixmap(side, side)
    canvas.fill(Qt.GlobalColor.transparent)
    painter = QPainter(canvas)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    path = QPainterPath()
    path.addRoundedRect(QRectF(0, 0, side, side), 8, 8)
    painter.setClipPath(path)
    painter.drawPixmap(0, 0, cropped)
    painter.end()
    return canvas


class NowPlayingToast(QWidget):
    """Floating desktop toast that slides/fades in when a track changes."""

    def __init__(self, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self.setWindowFlags(
            Qt.WindowType.ToolTip
            | Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.WindowDoesNotAcceptFocus
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setFixedSize(TOAST_WIDTH + MARGIN * 2, TOAST_HEIGHT + MARGIN * 2)

        self._build()
        self.setStyleSheet(toast_stylesheet())

        self._opacity = QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self._opacity)

        self._anim = QPropertyAnimation(self._opacity, b"opacity")
        self._anim.setDuration(280)
        self._anim.setEasingCurve(QEasingCurve.Type.InOutQuad)
        self._anim.finished.connect(self._on_fade_finished)

        self._hide_timer = QTimer(self)
        self._hide_timer.setSingleShot(True)
        self._hide_timer.timeout.connect(self._fade_out)

    def _build(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(MARGIN, MARGIN, MARGIN, MARGIN)

        self.shell = QFrame(self)
        self.shell.setObjectName("ToastShell")
        outer.addWidget(self.shell)

        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(22)
        shadow.setOffset(0, 6)
        shadow.setColor(QColor(0, 0, 0, 140))
        self.shell.setGraphicsEffect(shadow)

        layout = QHBoxLayout(self.shell)
        layout.setContentsMargins(10, 8, 12, 8)
        layout.setSpacing(10)

        self.art_label = QLabel(self.shell)
        self.art_label.setFixedSize(44, 44)
        self.art_label.setStyleSheet(
            f"background: rgba(244, 233, 221, 0.06); border: 1px solid {Palette.line}; border-radius: 8px;"
        )
        self.art_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.art_label)

        words = QVBoxLayout()
        words.setContentsMargins(0, 0, 0, 0)
        words.setSpacing(1)

        self.badge = QLabel("NOW PLAYING", self.shell)
        self.badge.setObjectName("ToastBadge")
        self.title = QLabel("Track Title", self.shell)
        self.title.setObjectName("ToastTitle")
        self.artist = QLabel("Artist", self.shell)
        self.artist.setObjectName("ToastArtist")

        words.addWidget(self.badge)
        words.addWidget(self.title)
        words.addWidget(self.artist)
        words.addStretch(1)
        layout.addLayout(words, 1)

    def show_song(self, song: Song, pixmap: Optional[QPixmap] = None) -> None:
        """Display toast with song info without stealing focus."""
        if not song:
            return

        self.badge.setText("NOW PLAYING")
        elide_into(self.title, song.title, 195)
        elide_into(self.artist, song.byline, 195)

        if pixmap and not pixmap.isNull():
            self.art_label.setPixmap(_rounded_thumb(pixmap, 44))
        else:
            self.art_label.clear()
            self.art_label.setPixmap(music_icon(Palette.amber_hi).pixmap(22, 22))
            self.art_label.setStyleSheet(
                f"background: {Palette.raised}; border: 1px solid {Palette.line}; border-radius: 8px;"
            )

        self._position_toast()
        self.show()

        self._anim.stop()
        self._anim.setStartValue(self._opacity.opacity())
        self._anim.setEndValue(1.0)
        self._anim.start()

        self._hide_timer.start(TOAST_DISPLAY_MS)

    def show_message(
        self,
        badge: str,
        title: str,
        subtitle: str,
        pixmap: Optional[QPixmap] = None,
    ) -> None:
        """Display toast with custom badge and message."""
        self.badge.setText(badge.upper())
        elide_into(self.title, title, 195)
        elide_into(self.artist, subtitle, 195)

        if pixmap and not pixmap.isNull():
            self.art_label.setPixmap(_rounded_thumb(pixmap, 44))
        else:
            self.art_label.clear()
            self.art_label.setPixmap(download_icon(Palette.amber_hi).pixmap(22, 22))
            self.art_label.setStyleSheet(
                f"background: {Palette.raised}; border: 1px solid {Palette.line}; border-radius: 8px;"
            )

        self._position_toast()
        self.show()

        self._anim.stop()
        self._anim.setStartValue(self._opacity.opacity())
        self._anim.setEndValue(1.0)
        self._anim.start()

        self._hide_timer.start(TOAST_DISPLAY_MS)

    def update_art(self, pixmap: QPixmap) -> None:
        """Update art if arrived while toast is visible."""
        if self.isVisible() and pixmap and not pixmap.isNull():
            self.art_label.setPixmap(_rounded_thumb(pixmap, 44))

    def _fade_out(self) -> None:
        self._anim.stop()
        self._anim.setStartValue(self._opacity.opacity())
        self._anim.setEndValue(0.0)
        self._anim.start()

    def _on_fade_finished(self) -> None:
        if self._opacity.opacity() <= 0.05:
            self.hide()

    def _position_toast(self) -> None:
        screen = QApplication.primaryScreen()
        if screen is not None:
            geom = screen.availableGeometry()
            x = geom.right() - self.width() - 20
            y = geom.bottom() - self.height() - 20
            self.move(x, y)

    def reload_theme(self) -> None:
        """Reload stylesheet when theme changes."""
        self.setStyleSheet(toast_stylesheet())
