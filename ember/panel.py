"""
panel.py
The floating Ember surface: a compact ribbon that expands into a full panel.

Layout is hand-built with high-DPI FontAwesome 6 vector icons, dynamic palette
tinting, responsive search debouncing, and persistent favorites/history tabs.

# Extended/upgraded by Taezeem (@taezeem14) — fork of Ember
"""

from __future__ import annotations

import logging
import sys
from typing import Callable, Dict, List, Optional, Tuple

from PyQt6.QtCore import QPoint, QRectF, QSettings, QSize, Qt, QTimer, pyqtSignal
from PyQt6.QtGui import (
    QColor,
    QLinearGradient,
    QPainter,
    QPainterPath,
    QPen,
    QPixmap,
)
from PyQt6.QtWidgets import (
    QFrame,
    QGraphicsDropShadowEffect,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMenu,
    QPushButton,
    QScrollArea,
    QVBoxLayout,
    QWidget,
)

from .config import (
    ANIM_MS,
    APP_CREDIT,
    APP_NAME,
    APP_TAGLINE,
    ART_COMPACT,
    ART_HERO,
    ARTWORK_CACHE_LIMIT,
    COMPACT_HEIGHT,
    DEFAULT_OPACITY,
    EXPANDED_HEIGHT,
    PANEL_WIDTH,
    Palette,
    QUEUE_VIEW_HEIGHT,
    SEARCH_DEBOUNCE_MS,
    SETTINGS_AUTO_QUEUE,
    SETTINGS_HOTKEYS,
    SETTINGS_NORMALIZE_VOLUME,
    SETTINGS_OPACITY,
    SETTINGS_THEME,
    SETTINGS_TOAST_ENABLED,
    SHELL_MARGIN,
    VINYL_DEGREES,
    VINYL_TICK_MS,
)
from .icons import (
    backward_icon,
    close_icon,
    collapse_icon,
    expand_icon,
    fire_icon,
    forward_icon,
    heart_icon,
    history_icon,
    infinity_icon,
    lyrics_icon,
    moon_icon,
    music_icon,
    pause_icon,
    play_icon,
    queue_icon,
    repeat_icon,
    search_icon,
    settings_icon,
    shuffle_icon,
)
from .jobs import ArtJob, LyricsJob, SearchJob
from .models import Song
from .player import PlaybackCore
from .settings_dialog import DEFAULT_HOTKEYS, SettingsDialog
from .storage import EmberStorage
from .theme import panel_stylesheet
from .toast import NowPlayingToast
from .utils import clock, elide_into, looks_like_link, pretty_count

log = logging.getLogger(__name__)

HWND_TOPMOST = -1
SWP_NOSIZE = 0x0001
SWP_NOMOVE = 0x0002
SWP_NOACTIVATE = 0x0010


# ---------------------------------------------------------------- paint helpers
def rounded_pixmap(source: QPixmap, radius: int) -> QPixmap:
    """Clip a pixmap to a rounded square with smooth anti-aliased corners."""
    scaled = source.scaled(
        QSize(radius * 2, radius * 2).expandedTo(source.size()),
        Qt.AspectRatioMode.KeepAspectRatioByExpanding,
        Qt.TransformationMode.SmoothTransformation,
    )
    side = min(scaled.width(), scaled.height())
    cropped = scaled.copy(
        (scaled.width() - side) // 2, (scaled.height() - side) // 2, side, side
    )
    canvas = QPixmap(side, side)
    canvas.fill(Qt.GlobalColor.transparent)

    painter = QPainter(canvas)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    path = QPainterPath()
    path.addRoundedRect(QRectF(0, 0, side, side), side * 0.24, side * 0.24)
    painter.setClipPath(path)
    painter.drawPixmap(0, 0, cropped)
    painter.end()
    return canvas


# ------------------------------------------------------------------ primitives
class Hairline(QFrame):
    """One-pixel separator that dynamically adapts to the current palette line colour."""

    def __init__(self, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self.setFixedHeight(1)
        self.reload_theme()

    def reload_theme(self) -> None:
        self.setStyleSheet(f"background: {Palette.line}; border: none;")


class SeekBar(QWidget):
    """Horizontal progress bar that supports smooth scrubbing and direct jumping."""

    scrubbed = pyqtSignal(int)
    released = pyqtSignal(int)

    def __init__(self, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self.setObjectName("Seek")
        self.setFixedHeight(18)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self._minimum = 0
        self._maximum = 0
        self._value = 0
        self._scrubbing = False

    def setRange(self, minimum: int, maximum: int) -> None:  # noqa: N802
        self._minimum = max(0, int(minimum))
        self._maximum = max(self._minimum, int(maximum))
        self._value = max(self._minimum, min(self._value, self._maximum))
        self.update()

    def setValue(self, value: int) -> None:  # noqa: N802
        clamped = max(self._minimum, min(int(value), self._maximum))
        if clamped != self._value:
            self._value = clamped
            self.update()

    def value(self) -> int:
        return self._value

    def _value_at(self, x: int) -> int:
        span = max(1, self.width())
        ratio = min(1.0, max(0.0, x / span))
        return int(self._minimum + ratio * (self._maximum - self._minimum))

    def mousePressEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton:
            self._scrubbing = True
            val = self._value_at(int(event.position().x()))
            self.setValue(val)
            self.scrubbed.emit(val)

    def mouseMoveEvent(self, event) -> None:  # noqa: N802
        if self._scrubbing:
            val = self._value_at(int(event.position().x()))
            self.setValue(val)
            self.scrubbed.emit(val)

    def mouseReleaseEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton and self._scrubbing:
            self._scrubbing = False
            self.released.emit(self.value())

    def paintEvent(self, event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)

        y = (self.height() - 5) / 2.0
        w = float(self.width())
        track_rect = QRectF(0, y, w, 5.0)

        # Background track
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(Palette.raised))
        painter.drawRoundedRect(track_rect, 2.5, 2.5)

        # Active progress fill
        span = self._maximum - self._minimum
        ratio = (self._value - self._minimum) / span if span > 0 else 0.0
        fill_w = max(0.0, w * ratio)
        if fill_w > 0:
            fill_rect = QRectF(0, y, fill_w, 5.0)
            grad = QLinearGradient(0, 0, w, 0)
            grad.setColorAt(0.0, QColor(Palette.amber_lo))
            grad.setColorAt(1.0, QColor(Palette.amber_hi))
            painter.setBrush(grad)
            painter.drawRoundedRect(fill_rect, 2.5, 2.5)

        # Handle knob
        handle_x = min(w - 10, max(0.0, fill_w - 5.0))
        handle_rect = QRectF(handle_x, y - 2.5, 10.0, 10.0)
        painter.setBrush(QColor(Palette.text))
        painter.setPen(QPen(QColor(Palette.amber), 2.0))
        painter.drawEllipse(handle_rect)
        painter.end()


class VinylDisc(QWidget):
    """Painted record that spins while audio is playing."""

    def __init__(self, diameter: int, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self.setFixedSize(diameter, diameter)
        self._angle = 0.0
        self._spinning = False
        self._timer = QTimer(self)
        self._timer.setInterval(VINYL_TICK_MS)
        self._timer.timeout.connect(self._tick)

    def set_spinning(self, spinning: bool) -> None:
        self._spinning = bool(spinning)
        if self._spinning and not self._timer.isActive():
            self._timer.start()
        elif not self._spinning:
            self._timer.stop()

    def _tick(self) -> None:
        self._angle = (self._angle + VINYL_DEGREES) % 360.0
        self.update()

    def paintEvent(self, event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        side = min(self.width(), self.height())
        painter.translate(self.width() / 2.0, self.height() / 2.0)
        painter.rotate(self._angle)

        disc = QRectF(-side / 2.0, -side / 2.0, side, side)
        gradient = QLinearGradient(disc.topLeft(), disc.bottomRight())
        gradient.setColorAt(0.0, QColor(Palette.raised))
        gradient.setColorAt(1.0, QColor(Palette.void))

        painter.setPen(QPen(QColor(Palette.line), 1.0))
        painter.setBrush(gradient)
        painter.drawEllipse(disc.adjusted(1, 1, -1, -1))

        groove = QPen(QColor(255, 255, 255, 14), 1.0)
        painter.setPen(groove)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        for step in range(3, int(side / 2), 4):
            painter.drawEllipse(QRectF(-step, -step, step * 2, step * 2))

        label_side = side * 0.34
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(Palette.amber))
        painter.drawEllipse(QRectF(-label_side / 2, -label_side / 2, label_side, label_side))

        painter.setBrush(QColor(Palette.void))
        painter.drawEllipse(QRectF(-side * 0.035, -side * 0.035, side * 0.07, side * 0.07))
        painter.end()


class SpringPhysics:
    """Calculates spring-damper dynamics for fluid audio visualizer bars."""

    @staticmethod
    def step(
        pos: list[float],
        vel: list[float],
        step_idx: int,
        stiffness: float = 0.28,
        damping: float = 0.65,
    ) -> tuple[list[float], list[float]]:
        import math
        new_pos = list(pos)
        new_vel = list(vel)
        for i in range(len(pos)):
            phase = step_idx * 0.22 + i * 1.35
            amp = 3.8 + (i % 2) * 2.2
            base = 7.0
            target = max(3.0, min(13.0, base + math.sin(phase) * amp + math.cos(phase * 0.5) * 1.5))
            force = (target - new_pos[i]) * stiffness
            new_vel[i] = (new_vel[i] + force) * damping
            new_pos[i] = max(2.5, min(13.5, new_pos[i] + new_vel[i]))
        return new_pos, new_vel


class EqualiserBars(QWidget):
    """Four bars that animate with fluid spring-damper physics while playing."""

    def __init__(self, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self.setFixedSize(18, 14)
        self._on = False
        self._pos = [3.5, 3.5, 3.5, 3.5]
        self._vel = [0.0, 0.0, 0.0, 0.0]
        self._step = 0
        self._timer = QTimer(self)
        self._timer.setInterval(40)
        self._timer.timeout.connect(self._tick)

    def set_on(self, on: bool) -> None:
        self._on = bool(on)
        if self._on and not self._timer.isActive():
            self._timer.start()
        elif not self._on:
            self._timer.stop()
            self._pos = [3.5, 3.5, 3.5, 3.5]
            self._vel = [0.0, 0.0, 0.0, 0.0]
        self.update()

    def _tick(self) -> None:
        if not self._on:
            return
        self._step += 1
        self._pos, self._vel = SpringPhysics.step(self._pos, self._vel, self._step)
        self.update()

    def paintEvent(self, event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setPen(Qt.PenStyle.NoPen)

        if not self._on:
            painter.setBrush(QColor(Palette.faint))
            for col in range(4):
                painter.drawRoundedRect(QRectF(col * 4.4, 9.5, 2.8, 4.0), 1.4, 1.4)
            painter.end()
            return

        gradient = QLinearGradient(0, 14, 0, 0)
        gradient.setColorAt(0.0, QColor(Palette.amber))
        gradient.setColorAt(1.0, QColor(Palette.amber_hi))
        painter.setBrush(gradient)

        for col in range(4):
            h = self._pos[col]
            painter.drawRoundedRect(QRectF(col * 4.4, 14.0 - h, 2.8, h), 1.4, 1.4)
        painter.end()


class VolumeDial(QWidget):
    """Vertical-drag dial. Cozy alternative to a flat volume slider."""

    changed = pyqtSignal(int)

    def __init__(self, value: int, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self.setFixedSize(30, 30)
        self.setCursor(Qt.CursorShape.SizeVerCursor)
        self._value = max(0, min(100, int(value)))
        self._drag_origin: Optional[QPoint] = None
        self._drag_value = self._value
        self.setToolTip(f"volume {self._value}%")

    def value(self) -> int:
        return self._value

    def set_value(self, value: int) -> None:
        clamped = max(0, min(100, int(value)))
        if clamped != self._value:
            self._value = clamped
            self.setToolTip(f"volume {clamped}%")
            self.update()

    def mousePressEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton:
            self._drag_origin = event.globalPosition().toPoint()
            self._drag_value = self._value

    def mouseMoveEvent(self, event) -> None:  # noqa: N802
        if self._drag_origin is None:
            return
        delta = self._drag_origin.y() - event.globalPosition().toPoint().y()
        target = max(0, min(100, self._drag_value + int(delta / 1.2)))
        if target != self._value:
            self._value = target
            self.setToolTip(f"volume {target}%")
            self.changed.emit(target)
            self.update()

    def mouseReleaseEvent(self, event) -> None:  # noqa: N802
        self._drag_origin = None

    def wheelEvent(self, event) -> None:  # noqa: N802
        delta = event.angleDelta().y()
        if delta == 0:
            return
        step = 4 if delta > 0 else -4
        target = max(0, min(100, self._value + step))
        if target != self._value:
            self._value = target
            self.setToolTip(f"volume {target}%")
            self.changed.emit(target)
            self.update()

    def paintEvent(self, event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)

        ring = QRectF(3.0, 3.0, 24.0, 24.0)
        painter.setPen(QPen(QColor(Palette.line), 2.5))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawArc(ring, 0, 360 * 16)

        span = int(-self._value / 100.0 * 360 * 16)
        painter.setPen(QPen(QColor(Palette.amber), 2.5))
        painter.drawArc(ring, 90 * 16, span)

        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(Palette.text))
        painter.drawEllipse(QRectF(12.0, 12.0, 6.0, 6.0))
        painter.end()


class QueueRow(QFrame):
    """One line in the queue / library list. Clicking it plays that item."""

    picked = pyqtSignal(int)
    fav_toggled = pyqtSignal(int)

    def __init__(
        self,
        index: int,
        song: Song,
        is_fav: bool = False,
        parent: Optional[QWidget] = None,
    ) -> None:
        super().__init__(parent)
        self.index = index
        self.song = song
        self.is_fav = is_fav
        self.setFixedHeight(36)
        self.setCursor(Qt.CursorShape.PointingHandCursor)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(10, 0, 10, 0)
        layout.setSpacing(8)

        self.meter = EqualiserBars(self)
        layout.addWidget(self.meter)

        self.title = QLabel(self)
        self.title.setObjectName("RibbonTitle")
        layout.addWidget(self.title, 1)

        self.stamp = QLabel(self)
        self.stamp.setObjectName("Clock")
        layout.addWidget(self.stamp, 0, Qt.AlignmentFlag.AlignRight)

        self.fav_btn = QPushButton(self)
        self.fav_btn.setObjectName("HeartButton")
        self.fav_btn.setFixedSize(22, 22)
        self.fav_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.fav_btn.setIcon(heart_icon(is_fav))
        self.fav_btn.setIconSize(QSize(13, 13))
        self.fav_btn.clicked.connect(lambda: self.fav_toggled.emit(self.index))
        layout.addWidget(self.fav_btn)

        self._active = False
        self._hover = False
        elide_into(self.title, song.title, 200)
        self.stamp.setText(song.duration or "")

    def set_favorite(self, is_fav: bool) -> None:
        self.is_fav = is_fav
        self.fav_btn.setIcon(heart_icon(is_fav))

    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        elide_into(self.title, self.song.title, max(80, self.title.width() - 6))

    def set_active(self, active: bool) -> None:
        if active == self._active:
            return
        self._active = active
        self.meter.set_on(active)
        self.title.setStyleSheet(
            f"color: {Palette.amber_hi}; font-weight: 700;" if active else f"color: {Palette.text}; font-weight: 500;"
        )
        self.update()

    def enterEvent(self, event) -> None:  # noqa: N802
        self._hover = True
        self.update()

    def leaveEvent(self, event) -> None:  # noqa: N802
        self._hover = False
        self.update()

    def mouseReleaseEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton and self.rect().contains(
            event.position().toPoint()
        ):
            self.picked.emit(self.index)

    def paintEvent(self, event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)

        if self._active:
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(QColor(Palette.amber_lo))
            painter.setOpacity(0.18)
            painter.drawRoundedRect(QRectF(0, 1, self.width(), self.height() - 2), 10, 10)
            painter.setOpacity(1.0)
            painter.setBrush(QColor(Palette.amber))
            painter.drawRoundedRect(QRectF(3, 9, 2.5, self.height() - 18), 1.25, 1.25)
        elif self._hover:
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(QColor(244, 233, 221, 14))
            painter.drawRoundedRect(QRectF(0, 1, self.width(), self.height() - 2), 10, 10)
        painter.end()


# ----------------------------------------------------------------- main surface
class FloatingPanel(QWidget):
    """Compact ribbon that expands into the full Ember panel with FontAwesome 6 vector icons."""

    closed = pyqtSignal()
    endless_toggled = pyqtSignal(bool)
    theme_reloaded = pyqtSignal(str)
    hotkeys_updated = pyqtSignal()

    def __init__(
        self,
        core: PlaybackCore,
        storage: Optional[EmberStorage] = None,
        settings: Optional[QSettings] = None,
        parent: Optional[QWidget] = None,
    ) -> None:
        super().__init__(parent)
        self.core = core
        self.storage = storage
        self.settings = settings or QSettings()
        self.expanded = False

        self._drag_offset: Optional[QPoint] = None
        self._anchor: Optional[Tuple[str, int, str, int]] = None
        self._scrubbing = False
        self._art_cache: Dict[str, QPixmap] = {}
        self._art_pending: set = set()
        self._active_tab = "queue"
        self._view_songs: List[Song] = []

        self.toast = NowPlayingToast()

        self._current_lyrics_vid: Optional[str] = None
        self._lyrics_loaded_for: Optional[str] = None
        self._sleep_seconds_remaining: int = 0
        self._sleep_fading: bool = False
        self._sleep_timer = QTimer(self)
        self._sleep_timer.setInterval(1000)
        self._sleep_timer.timeout.connect(self._on_sleep_tick)

        self.setWindowTitle(APP_NAME)
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setStyleSheet(panel_stylesheet())

        try:
            saved_opacity = int(self.settings.value(SETTINGS_OPACITY, DEFAULT_OPACITY))
        except (ValueError, TypeError):
            saved_opacity = DEFAULT_OPACITY
        self.set_window_opacity_percent(saved_opacity)

        self._build()
        self._wire()
        self._apply_size()
        self._update_all_icons()

    # ------------------------------------------------------------------ build
    def _build(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(SHELL_MARGIN, SHELL_MARGIN, SHELL_MARGIN, SHELL_MARGIN)
        outer.setSpacing(0)

        self.shell = QFrame(self)
        self.shell.setObjectName("Shell")
        outer.addWidget(self.shell)

        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(36)
        shadow.setOffset(0, 10)
        shadow.setColor(QColor(0, 0, 0, 180))
        self.shell.setGraphicsEffect(shadow)

        stage = QVBoxLayout(self.shell)
        stage.setContentsMargins(0, 0, 0, 0)
        stage.setSpacing(0)

        self.ribbon = self._build_ribbon()
        self.panel = self._build_panel()
        stage.addWidget(self.ribbon)
        stage.addWidget(self.panel)

    # ---------------------------------------------------------------- compact
    def _build_ribbon(self) -> QWidget:
        holder = QWidget(self)
        holder.setObjectName("Ribbon")
        holder.setFixedHeight(COMPACT_HEIGHT - 2)

        row = QHBoxLayout(holder)
        row.setContentsMargins(10, 0, 10, 0)
        row.setSpacing(8)

        self.ribbon_art = self._art_label(ART_COMPACT, 10)
        row.addWidget(self.ribbon_art)

        words = QVBoxLayout()
        words.setContentsMargins(0, 0, 0, 0)
        words.setSpacing(1)
        self.ribbon_title = QLabel("nothing playing", holder)
        self.ribbon_title.setObjectName("RibbonTitle")
        self.ribbon_artist = QLabel(APP_TAGLINE, holder)
        self.ribbon_artist.setObjectName("RibbonArtist")
        words.addWidget(self.ribbon_title)
        words.addWidget(self.ribbon_artist)
        row.addLayout(words, 1)

        self.ribbon_fav = QPushButton(self)
        self.ribbon_fav.setObjectName("HeartButton")
        self.ribbon_fav.setFixedSize(28, 28)
        self.ribbon_fav.setCursor(Qt.CursorShape.PointingHandCursor)
        self.ribbon_fav.setToolTip("pin to favorites")
        self.ribbon_fav.clicked.connect(self._toggle_favorite)
        row.addWidget(self.ribbon_fav)

        self.ribbon_prev = self._ghost_btn(28)
        self.ribbon_prev.setToolTip("previous track")
        self.ribbon_play = QPushButton(self)
        self.ribbon_play.setObjectName("RoundPlay")
        self.ribbon_play.setFixedSize(38, 38)
        self.ribbon_play.setCursor(Qt.CursorShape.PointingHandCursor)
        self.ribbon_play.setToolTip("play / pause")

        self.ribbon_next = self._ghost_btn(28)
        self.ribbon_next.setToolTip("next track")

        row.addWidget(self.ribbon_prev)
        row.addWidget(self.ribbon_play)
        row.addWidget(self.ribbon_next)

        self.ribbon_open = self._pill_btn(28)
        self.ribbon_open.setToolTip("expand player")
        row.addWidget(self.ribbon_open)

        return holder

    # --------------------------------------------------------------- expanded
    def _build_panel(self) -> QWidget:
        holder = QWidget(self)
        holder.setObjectName("Panel")
        holder.setVisible(False)

        column = QVBoxLayout(holder)
        column.setContentsMargins(14, 12, 14, 12)
        column.setSpacing(10)

        column.addLayout(self._build_header())
        column.addWidget(self._build_now_card())
        column.addLayout(self._build_search())
        column.addLayout(self._build_tabs_row())
        column.addWidget(self._build_queue())
        self.panel_hairline = Hairline(holder)
        column.addWidget(self.panel_hairline)
        column.addLayout(self._build_footer())

        return holder

    def _build_header(self) -> QVBoxLayout:
        block = QVBoxLayout()
        block.setContentsMargins(2, 0, 0, 0)
        block.setSpacing(1)

        row = QHBoxLayout()
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(8)

        brand_row = QHBoxLayout()
        brand_row.setSpacing(6)
        self.fire_label = QLabel(self)
        self.fire_label.setPixmap(fire_icon().pixmap(16, 16))
        mark = QLabel(APP_NAME.upper(), self)
        mark.setObjectName("Display")
        brand_row.addWidget(self.fire_label)
        brand_row.addWidget(mark)

        words = QVBoxLayout()
        words.setContentsMargins(0, 0, 0, 0)
        words.setSpacing(0)
        words.addLayout(brand_row)
        tail = QLabel(APP_TAGLINE.upper(), self)
        tail.setObjectName("Tagline")
        words.addWidget(tail)
        row.addLayout(words, 1)

        self.status = QLabel("ready", self)
        self.status.setObjectName("StatusChip")
        row.addWidget(self.status, 0, Qt.AlignmentFlag.AlignVCenter)

        self.collapse_pill = self._pill_btn(28)
        self.collapse_pill.setToolTip("collapse player")
        row.addWidget(self.collapse_pill, 0, Qt.AlignmentFlag.AlignVCenter)

        block.addLayout(row)

        # Full-width line — the credit never shares the row with the tagline.
        # At 392px the tagline + credit together need ~397px and only ~190px exists
        # beside the status chip and collapse pill, so the credit would clip.
        credit_row = QHBoxLayout()
        credit_row.setContentsMargins(22, 0, 0, 0)
        credit = QLabel(APP_CREDIT, self)
        credit.setObjectName("Credit")
        credit.setToolTip("developed by Mayank Malaviya aka AIwolfie")
        credit_row.addWidget(credit)
        credit_row.addStretch(1)
        block.addLayout(credit_row)

        return block

    def _build_now_card(self) -> QWidget:
        card = QFrame(self)
        card.setObjectName("NowCard")

        column = QVBoxLayout(card)
        column.setContentsMargins(12, 12, 12, 10)
        column.setSpacing(9)

        top = QHBoxLayout()
        top.setContentsMargins(0, 0, 0, 0)
        top.setSpacing(11)

        self.hero_art = self._art_label(ART_HERO, 14)
        top.addWidget(self.hero_art, 0, Qt.AlignmentFlag.AlignTop)

        self.disc = VinylDisc(ART_HERO - 22, card)
        top.addWidget(self.disc, 0, Qt.AlignmentFlag.AlignTop)

        words = QVBoxLayout()
        words.setContentsMargins(0, 4, 0, 0)
        words.setSpacing(3)
        self.hero_title = QLabel("pick something to play", card)
        self.hero_title.setObjectName("HeroTitle")
        self.hero_artist = QLabel("—", card)
        self.hero_artist.setObjectName("HeroArtist")
        words.addWidget(self.hero_title)
        words.addWidget(self.hero_artist)
        words.addStretch(1)
        top.addLayout(words, 1)

        self.hero_fav = QPushButton(card)
        self.hero_fav.setObjectName("HeartButton")
        self.hero_fav.setFixedSize(28, 28)
        self.hero_fav.setCursor(Qt.CursorShape.PointingHandCursor)
        self.hero_fav.setToolTip("pin to favorites")
        self.hero_fav.clicked.connect(self._toggle_favorite)
        top.addWidget(self.hero_fav, 0, Qt.AlignmentFlag.AlignTop)

        column.addLayout(top)

        seek_row = QHBoxLayout()
        seek_row.setContentsMargins(0, 0, 0, 0)
        seek_row.setSpacing(8)

        self.elapsed = QLabel("0:00", card)
        self.elapsed.setObjectName("Clock")
        self.elapsed.setFixedWidth(38)
        seek_row.addWidget(self.elapsed)

        self.seek = SeekBar(card)
        seek_row.addWidget(self.seek, 1)

        self.total = QLabel("0:00", card)
        self.total.setObjectName("Clock")
        self.total.setFixedWidth(38)
        self.total.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        seek_row.addWidget(self.total)

        column.addLayout(seek_row)

        # Transport controls inside NowCard
        transport = QHBoxLayout()
        transport.setContentsMargins(0, 2, 0, 0)
        transport.setSpacing(10)

        self.panel_shuffle = QPushButton(card)
        self.panel_shuffle.setObjectName("ModeToggle")
        self.panel_shuffle.setFixedSize(28, 28)
        self.panel_shuffle.setCursor(Qt.CursorShape.PointingHandCursor)
        self.panel_shuffle.setToolTip("Shuffle upcoming queue")
        self.panel_shuffle.setIcon(shuffle_icon(False))
        self.panel_shuffle.setIconSize(QSize(14, 14))
        self.panel_shuffle.clicked.connect(self.core.shuffle_upcoming)
        transport.addWidget(self.panel_shuffle)

        transport.addStretch(1)

        self.panel_prev = self._ghost_btn(28)
        self.panel_prev.setToolTip("previous track")
        self.panel_prev.setIcon(backward_icon())
        self.panel_prev.setIconSize(QSize(14, 14))
        self.panel_prev.clicked.connect(self.core.back)
        transport.addWidget(self.panel_prev)

        self.panel_play = QPushButton(card)
        self.panel_play.setObjectName("RoundPlay")
        self.panel_play.setFixedSize(36, 36)
        self.panel_play.setCursor(Qt.CursorShape.PointingHandCursor)
        self.panel_play.setToolTip("play / pause")
        self.panel_play.setIcon(play_icon())
        self.panel_play.setIconSize(QSize(16, 16))
        self.panel_play.clicked.connect(self.core.toggle)
        transport.addWidget(self.panel_play)

        self.panel_next = self._ghost_btn(28)
        self.panel_next.setToolTip("next track")
        self.panel_next.setIcon(forward_icon())
        self.panel_next.setIconSize(QSize(14, 14))
        self.panel_next.clicked.connect(lambda: self.core.forward(force=True))
        transport.addWidget(self.panel_next)

        transport.addStretch(1)

        self.panel_repeat = QPushButton(card)
        self.panel_repeat.setObjectName("ModeToggle")
        self.panel_repeat.setFixedSize(28, 28)
        self.panel_repeat.setCheckable(True)
        self.panel_repeat.setCursor(Qt.CursorShape.PointingHandCursor)
        self.panel_repeat.setToolTip("Repeat: Off")
        self.panel_repeat.setIcon(repeat_icon("off"))
        self.panel_repeat.setIconSize(QSize(14, 14))
        self.panel_repeat.clicked.connect(self.core.cycle_repeat_mode)
        transport.addWidget(self.panel_repeat)

        column.addLayout(transport)
        return card

    def _build_search(self) -> QHBoxLayout:
        row = QHBoxLayout()
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(8)

        self.field = QLineEdit(self)
        self.field.setObjectName("SearchField")
        self.field.setPlaceholderText("Search tracks, artists, or drop YouTube link...")
        self.field.setFixedHeight(36)
        self.field.setClearButtonEnabled(True)
        row.addWidget(self.field, 1)

        self.find = QPushButton(self)
        self.find.setObjectName("AmberButton")
        self.find.setFixedHeight(36)
        self.find.setFixedWidth(44)
        self.find.setCursor(Qt.CursorShape.PointingHandCursor)
        self.find.setToolTip("search catalogue")
        row.addWidget(self.find)

        return row

    def _build_tabs_row(self) -> QHBoxLayout:
        row = QHBoxLayout()
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(5)

        self.tab_queue = QPushButton(" Up Next", self)
        self.tab_queue.setObjectName("TabButton")
        self.tab_queue.setCheckable(True)
        self.tab_queue.setChecked(True)
        self.tab_queue.setIcon(queue_icon())
        self.tab_queue.setIconSize(QSize(12, 12))

        self.tab_favs = QPushButton(" Favorites", self)
        self.tab_favs.setObjectName("TabButton")
        self.tab_favs.setCheckable(True)
        self.tab_favs.setIcon(heart_icon(True))
        self.tab_favs.setIconSize(QSize(12, 12))

        self.tab_history = QPushButton(" History", self)
        self.tab_history.setObjectName("TabButton")
        self.tab_history.setCheckable(True)
        self.tab_history.setIcon(history_icon())
        self.tab_history.setIconSize(QSize(12, 12))

        self.tab_lyrics = QPushButton(" Lyrics", self)
        self.tab_lyrics.setObjectName("TabButton")
        self.tab_lyrics.setCheckable(True)
        self.tab_lyrics.setIcon(lyrics_icon())
        self.tab_lyrics.setIconSize(QSize(12, 12))
        self.tab_lyrics.setToolTip("live song lyrics")

        row.addWidget(self.tab_queue)
        row.addWidget(self.tab_favs)
        row.addWidget(self.tab_history)
        row.addWidget(self.tab_lyrics)
        row.addStretch(1)

        self.tab_queue.clicked.connect(lambda: self._switch_tab("queue"))
        self.tab_favs.clicked.connect(lambda: self._switch_tab("favorites"))
        self.tab_history.clicked.connect(lambda: self._switch_tab("history"))
        self.tab_lyrics.clicked.connect(lambda: self._switch_tab("lyrics"))

        return row

    def _build_queue(self) -> QWidget:
        container = QWidget(self)
        layout = QVBoxLayout(container)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        self.queue_scroll = QScrollArea(container)
        self.queue_scroll.setObjectName("QueueScroll")
        self.queue_scroll.setWidgetResizable(True)
        self.queue_scroll.setFixedHeight(QUEUE_VIEW_HEIGHT)
        self.queue_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.queue_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        self.queue_host = QWidget()
        self.queue_list = QVBoxLayout(self.queue_host)
        self.queue_list.setContentsMargins(0, 0, 4, 0)
        self.queue_list.setSpacing(3)
        self.queue_list.addStretch(1)
        self.queue_scroll.setWidget(self.queue_host)

        self._empty = QLabel("search for something warm", self.queue_host)
        self._empty.setObjectName("Hint")
        self._empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.queue_list.insertWidget(0, self._empty)
        layout.addWidget(self.queue_scroll)

        # Lyrics view
        self.lyrics_scroll = QScrollArea(container)
        self.lyrics_scroll.setObjectName("LyricsScroll")
        self.lyrics_scroll.setWidgetResizable(True)
        self.lyrics_scroll.setFixedHeight(QUEUE_VIEW_HEIGHT)
        self.lyrics_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.lyrics_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.lyrics_scroll.setVisible(False)

        lyrics_host = QWidget()
        lyrics_layout = QVBoxLayout(lyrics_host)
        lyrics_layout.setContentsMargins(14, 12, 14, 12)
        lyrics_layout.setSpacing(8)

        self.lyrics_text = QLabel("No lyrics available", lyrics_host)
        self.lyrics_text.setObjectName("LyricsText")
        self.lyrics_text.setWordWrap(True)
        self.lyrics_text.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lyrics_text.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        lyrics_layout.addWidget(self.lyrics_text)
        lyrics_layout.addStretch(1)
        self.lyrics_scroll.setWidget(lyrics_host)
        layout.addWidget(self.lyrics_scroll)

        return container

    def _build_footer(self) -> QHBoxLayout:
        row = QHBoxLayout()
        row.setContentsMargins(2, 0, 0, 0)
        row.setSpacing(6)

        self.endless = QPushButton(" Endless", self)
        self.endless.setObjectName("Chip")
        self.endless.setCheckable(True)
        self.endless.setChecked(True)
        self.endless.setIcon(infinity_icon())
        self.endless.setIconSize(QSize(13, 13))
        self.endless.setToolTip("keep adding look-alike tracks when queue runs dry")
        row.addWidget(self.endless)

        self.speed_btn = QPushButton("1.0x", self)
        self.speed_btn.setObjectName("SpeedPill")
        self.speed_btn.setToolTip("Playback speed (click to cycle)")
        self.speed_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.speed_btn.clicked.connect(self._cycle_speed)
        row.addWidget(self.speed_btn)

        self.sleep_btn = QPushButton(" Sleep", self)
        self.sleep_btn.setObjectName("SleepPill")
        self.sleep_btn.setCheckable(True)
        self.sleep_btn.setIcon(moon_icon(False))
        self.sleep_btn.setIconSize(QSize(12, 12))
        self.sleep_btn.setToolTip("Sleep timer (click to set)")
        self.sleep_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.sleep_btn.clicked.connect(self._open_sleep_menu)
        row.addWidget(self.sleep_btn)

        self.count = QLabel("0 tracks", self)
        self.count.setObjectName("Hint")
        row.addWidget(self.count)

        row.addStretch(1)

        self.volume = VolumeDial(self.core.volume(), self)
        row.addWidget(self.volume, 0, Qt.AlignmentFlag.AlignVCenter)

        self.settings_btn = self._pill_btn(28)
        self.settings_btn.setToolTip("preferences & tunables")
        self.settings_btn.clicked.connect(self._open_settings)
        row.addWidget(self.settings_btn)

        self.quit = QPushButton(self)
        self.quit.setObjectName("PillClose")
        self.quit.setFixedSize(28, 28)
        self.quit.setCursor(Qt.CursorShape.PointingHandCursor)
        self.quit.setToolTip("close Ember")
        row.addWidget(self.quit)

        return row

    # ------------------------------------------------------------- small parts
    def _art_label(self, side: int, radius: int) -> QLabel:
        label = QLabel(self)
        label.setFixedSize(side, side)
        label.setStyleSheet(
            f"background: rgba(244, 233, 221, 0.05);"
            f"border: 1px solid {Palette.line};"
            f"border-radius: {radius}px;"
        )
        label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        return label

    def _ghost_btn(self, side: int) -> QPushButton:
        btn = QPushButton(self)
        btn.setObjectName("Ghost")
        btn.setFixedSize(side, side)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        return btn

    def _pill_btn(self, side: int) -> QPushButton:
        btn = QPushButton(self)
        btn.setObjectName("Pill")
        btn.setFixedSize(side, side)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        return btn

    def _update_all_icons(self) -> None:
        """Refresh all vector FontAwesome icons tinted to the active palette."""
        is_playing = self.core.player.playbackState() == self.core.player.PlaybackState.PlayingState
        self.ribbon_play.setIcon(pause_icon() if is_playing else play_icon())
        self.ribbon_play.setIconSize(QSize(16, 16))

        self.panel_play.setIcon(pause_icon() if is_playing else play_icon())
        self.panel_play.setIconSize(QSize(16, 16))

        self.ribbon_prev.setIcon(backward_icon())
        self.ribbon_prev.setIconSize(QSize(14, 14))

        self.panel_prev.setIcon(backward_icon())
        self.panel_prev.setIconSize(QSize(14, 14))

        self.ribbon_next.setIcon(forward_icon())
        self.ribbon_next.setIconSize(QSize(14, 14))

        self.panel_next.setIcon(forward_icon())
        self.panel_next.setIconSize(QSize(14, 14))

        self.panel_shuffle.setIcon(shuffle_icon(False))
        self.panel_shuffle.setIconSize(QSize(14, 14))

        self.panel_repeat.setIcon(repeat_icon(self.core.repeat_mode))
        self.panel_repeat.setIconSize(QSize(14, 14))

        self.tab_lyrics.setIcon(lyrics_icon())
        self.tab_lyrics.setIconSize(QSize(12, 12))

        self.sleep_btn.setIcon(moon_icon(self._sleep_seconds_remaining > 0))
        self.sleep_btn.setIconSize(QSize(12, 12))

        self.ribbon_open.setIcon(expand_icon())
        self.ribbon_open.setIconSize(QSize(14, 14))

        self.collapse_pill.setIcon(collapse_icon())
        self.collapse_pill.setIconSize(QSize(14, 14))

        self.find.setIcon(search_icon())
        self.find.setIconSize(QSize(15, 15))

        self.settings_btn.setIcon(settings_icon())
        self.settings_btn.setIconSize(QSize(14, 14))

        self.quit.setIcon(close_icon())
        self.quit.setIconSize(QSize(14, 14))

        self.fire_label.setPixmap(fire_icon().pixmap(16, 16))

        curr = self.core.current
        is_fav = bool(curr and self.storage and self.storage.is_favorite(curr.video_id))
        self._update_favorite_buttons(is_fav)

    # ------------------------------------------------------------------- wiring
    def _wire(self) -> None:
        core = self.core

        core.song_changed.connect(self._on_song)
        core.queue_changed.connect(self._on_queue)
        core.cursor_changed.connect(self._on_cursor)
        core.playing_changed.connect(self._on_playing)
        core.progress_changed.connect(self._on_progress)
        core.length_changed.connect(self._on_length)
        core.loading_changed.connect(self._on_loading)
        core.notice.connect(self._on_notice)
        core.repeat_mode_changed.connect(self._on_repeat_mode_changed)
        core.rate_changed.connect(self._on_rate_changed)

        self.ribbon_play.clicked.connect(core.toggle)
        self.ribbon_prev.clicked.connect(core.back)
        self.ribbon_next.clicked.connect(core.forward)
        self.ribbon_open.clicked.connect(self.expand)
        self.collapse_pill.clicked.connect(self.collapse)

        self.seek.scrubbed.connect(self._on_scrub)
        self.seek.released.connect(self._on_scrub_done)

        self.find.clicked.connect(self._on_find)
        self.field.returnPressed.connect(self._on_find)

        # Search debounce timer (350ms)
        self._debounce_timer = QTimer(self)
        self._debounce_timer.setSingleShot(True)
        self._debounce_timer.setInterval(SEARCH_DEBOUNCE_MS)
        self._debounce_timer.timeout.connect(self._on_debounced_search)
        self.field.textChanged.connect(self._on_field_changed)

        self.volume.changed.connect(self._on_volume)
        self.endless.toggled.connect(self._on_endless)
        self.quit.clicked.connect(self._on_quit)

        self._notice_timer = QTimer(self)
        self._notice_timer.setSingleShot(True)
        self._notice_timer.timeout.connect(lambda: self._set_status("ready"))

    # ------------------------------------------------------------- tabs & library
    def _switch_tab(self, tab: str) -> None:
        self._active_tab = tab
        self.tab_queue.setChecked(tab == "queue")
        self.tab_favs.setChecked(tab == "favorites")
        self.tab_history.setChecked(tab == "history")
        self.tab_lyrics.setChecked(tab == "lyrics")

        if tab == "lyrics":
            self.queue_scroll.setVisible(False)
            self.lyrics_scroll.setVisible(True)
            curr = self.core.current
            if curr:
                self.count.setText("lyrics")
                if self._lyrics_loaded_for != curr.video_id:
                    self._fetch_lyrics(curr)
            else:
                self.lyrics_text.setText("No track playing")
                self.count.setText("lyrics")
        else:
            self.lyrics_scroll.setVisible(False)
            self.queue_scroll.setVisible(True)
            self._refresh_tab_content()

    def _refresh_tab_content(self) -> None:
        if self._active_tab == "queue":
            self._render_song_list(self.core.queue, active_idx=self.core.cursor, empty_hint="search for something warm")
        elif self._active_tab == "favorites":
            favs = self.storage.get_favorites() if self.storage else []
            self._render_song_list(favs, active_idx=-1, empty_hint="no favorites pinned yet — click ♡ to save")
        elif self._active_tab == "history":
            hist = self.storage.get_history() if self.storage else []
            self._render_song_list(hist, active_idx=-1, empty_hint="no recently played history yet")

    def _render_song_list(self, songs: List[Song], active_idx: int = -1, empty_hint: str = "") -> None:
        self._view_songs = list(songs)
        # Clear existing rows
        for position in reversed(range(self.queue_list.count())):
            widget = self.queue_list.itemAt(position).widget()
            if isinstance(widget, QueueRow):
                self.queue_list.takeAt(position)
                widget.deleteLater()

        if not songs:
            self._empty.setText(empty_hint)
            self._empty.setVisible(True)
            self.count.setText("0 tracks")
            return

        self._empty.setVisible(False)
        for index, song in enumerate(songs):
            is_fav = bool(self.storage and self.storage.is_favorite(song.video_id))
            row = QueueRow(index, song, is_fav=is_fav, parent=self.queue_host)
            row.picked.connect(self._on_row_picked)
            row.fav_toggled.connect(self._on_row_fav_toggled)
            if index == active_idx:
                row.set_active(True)
            self.queue_list.insertWidget(index + 1, row)

        self.count.setText(pretty_count(len(songs), "track"))

    def _on_row_picked(self, index: int) -> None:
        if not 0 <= index < len(self._view_songs):
            return
        picked_song = self._view_songs[index]
        if self._active_tab == "queue":
            self.core.play_at(index)
        else:
            self.core.play(picked_song, expand=True)

    def _on_row_fav_toggled(self, index: int) -> None:
        if not self.storage or not 0 <= index < len(self._view_songs):
            return
        target = self._view_songs[index]
        if self.storage.is_favorite(target.video_id):
            self.storage.remove_favorite(target.video_id)
            self._set_status(f"unpinned {target.title[:18]}")
        else:
            self.storage.add_favorite(target)
            self._set_status(f"pinned {target.title[:18]} ♥")

        # Update now card hearts if it's the current song
        curr = self.core.current
        if curr and curr.video_id == target.video_id:
            self._update_favorite_buttons(self.storage.is_favorite(target.video_id))

        bar = self.queue_scroll.verticalScrollBar()
        pos = bar.value()
        self._refresh_tab_content()
        bar.setValue(pos)

    # ------------------------------------------------------------- favorites
    def _toggle_favorite(self) -> None:
        curr = self.core.current
        if not curr or not self.storage:
            return
        if self.storage.is_favorite(curr.video_id):
            self.storage.remove_favorite(curr.video_id)
            self._update_favorite_buttons(False)
            self._set_status("unpinned from favorites")
        else:
            self.storage.add_favorite(curr)
            self._update_favorite_buttons(True)
            self._set_status("pinned to favorites ♥")

        bar = self.queue_scroll.verticalScrollBar()
        pos = bar.value()
        self._refresh_tab_content()
        bar.setValue(pos)

    def _update_favorite_buttons(self, is_fav: bool) -> None:
        icon = heart_icon(is_fav)
        for btn in (self.ribbon_fav, self.hero_fav):
            btn.setIcon(icon)
            btn.setIconSize(QSize(15, 15))

    # ------------------------------------------------------------- settings
    def _open_settings(self) -> None:
        dlg = SettingsDialog(self.settings, self)
        dlg.theme_changed.connect(self.reload_theme)
        dlg.opacity_changed.connect(self.set_window_opacity_percent)
        dlg.normalization_changed.connect(self.core.set_normalize_volume)
        dlg.audio_device_changed.connect(self.core.set_audio_device)
        dlg.endless_changed.connect(self._on_endless_from_settings)
        dlg.hotkeys_changed.connect(lambda _: self.hotkeys_updated.emit())
        dlg.exec()

    def set_window_opacity_percent(self, percent: int) -> None:
        opacity = max(60, min(100, int(percent))) / 100.0
        self.setWindowOpacity(opacity)

    def _on_endless_from_settings(self, enabled: bool) -> None:
        self.endless.blockSignals(True)
        self.endless.setChecked(enabled)
        self.endless.blockSignals(False)
        self.core.set_auto_queue(enabled)

    def reload_theme(self, theme_name: str = "") -> None:
        """Apply newly selected theme across panel, dialogs, and custom-painted widgets."""
        self.setStyleSheet(panel_stylesheet())
        self.panel_hairline.reload_theme()
        self.toast.reload_theme()

        self._update_all_icons()

        # Force repaint of custom-painted elements
        self.disc.update()
        self.volume.update()
        self.seek.update()
        self.update()

        if self.expanded:
            self._refresh_tab_content()

        self.theme_reloaded.emit(Palette.current_theme)

    # ------------------------------------------------------------- appearance
    def _apply_size(self) -> None:
        height = COMPACT_HEIGHT if not self.expanded else EXPANDED_HEIGHT
        self.setFixedSize(PANEL_WIDTH + SHELL_MARGIN * 2, height + SHELL_MARGIN * 2)

    def expand(self) -> None:
        if self.expanded:
            return
        self._capture_anchor()
        self.expanded = True
        self.ribbon.setVisible(False)
        self.panel.setVisible(True)
        self._apply_anchor()
        self._refresh_tab_content()
        self.ensure_topmost()

    def collapse(self) -> None:
        if not self.expanded:
            return
        self._capture_anchor()
        self.expanded = False
        self.panel.setVisible(False)
        self.ribbon.setVisible(True)
        self._apply_anchor()
        self.ensure_topmost()

    def _capture_anchor(self) -> None:
        """Record which screen edges the panel hugs and how far it sits from them."""
        screen = self.screen()
        if screen is None:
            self._anchor = None
            return
        bounds = screen.availableGeometry()
        left_gap = self.x() - bounds.left()
        right_gap = bounds.right() - (self.x() + self.width())
        top_gap = self.y() - bounds.top()
        bottom_gap = bounds.bottom() - (self.y() + self.height())

        h_edge = "right" if right_gap <= left_gap else "left"
        v_edge = "bottom" if bottom_gap <= top_gap else "top"
        self._anchor = (
            h_edge,
            max(0, right_gap if h_edge == "right" else left_gap),
            v_edge,
            max(0, bottom_gap if v_edge == "bottom" else top_gap),
        )

    def _apply_anchor(self) -> None:
        """Resize to the current mode and re-park the panel against its anchored edges."""
        self._apply_size()
        screen = self.screen()
        if self._anchor is None or screen is None:
            self.clamp_to_screen()
            return
        bounds = screen.availableGeometry()
        h_edge, h_gap, v_edge, v_gap = self._anchor
        x = bounds.right() - self.width() - h_gap if h_edge == "right" else bounds.left() + h_gap
        y = bounds.bottom() - self.height() - v_gap if v_edge == "bottom" else bounds.top() + v_gap
        self.move(int(x), int(y))
        self.clamp_to_screen()

    def toggle_expand(self) -> None:
        self.collapse() if self.expanded else self.expand()

    def clamp_to_screen(self) -> None:
        screen = self.screen()
        if screen is None:
            return
        bounds = screen.availableGeometry()
        x = min(max(self.x(), bounds.left()), bounds.right() - self.width())
        y = min(max(self.y(), bounds.top()), bounds.bottom() - self.height())
        self.move(x, y)

    def ensure_topmost(self) -> None:
        """Re-assert z-order. Windows forgets after another window takes focus."""
        if not sys.platform.startswith("win"):
            return
        try:
            import ctypes

            ctypes.windll.user32.SetWindowPos(
                int(self.winId()),
                HWND_TOPMOST,
                0,
                0,
                0,
                0,
                SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE,
            )
        except Exception as exc:  # noqa: BLE001 - platform surface
            log.debug("topmost re-assert skipped: %s", exc)

    # ----------------------------------------------------------------- dragging
    def mousePressEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton:
            self._drag_offset = event.globalPosition().toPoint() - self.frameGeometry().topLeft()

    def mouseMoveEvent(self, event) -> None:  # noqa: N802
        if self._drag_offset is None:
            return
        self.move(event.globalPosition().toPoint() - self._drag_offset)

    def mouseReleaseEvent(self, event) -> None:  # noqa: N802
        if self._drag_offset is not None:
            self._drag_offset = None
            self.clamp_to_screen()
            self._capture_anchor()

    # ------------------------------------------------------------- art fetching
    def _request_art(self, song: Song) -> None:
        if not song.artwork_url:
            return
        if song.video_id in self._art_cache:
            # Refresh LRU access order
            cached = self._art_cache.pop(song.video_id)
            self._art_cache[song.video_id] = cached
            self._paint_art(song.video_id, cached)
            return
        if song.video_id in self._art_pending:
            return

        self._art_pending.add(song.video_id)
        job = ArtJob(song.video_id, song.artwork_url)
        job.signals.arrived.connect(self._on_art)
        job.signals.failed.connect(lambda sid, _msg: self._art_pending.discard(sid))
        self.core.pool.start(job)

    def _on_art(self, song_id: str, payload: bytes) -> None:
        self._art_pending.discard(song_id)
        source = QPixmap()
        if not source.loadFromData(payload):
            return

        if len(self._art_cache) >= ARTWORK_CACHE_LIMIT:
            self._art_cache.pop(next(iter(self._art_cache)), None)
        self._art_cache[song_id] = source
        self._paint_art(song_id, source)
        if self.core.current and self.core.current.video_id == song_id:
            self.toast.update_art(source)

    def _paint_art(self, song_id: str, source: QPixmap) -> None:
        current = self.core.current
        if current is None or current.video_id != song_id:
            return
        self.ribbon_art.setPixmap(rounded_pixmap(source, ART_COMPACT))
        self.hero_art.setPixmap(rounded_pixmap(source, ART_HERO))

    # ------------------------------------------------------------------- slots
    def _on_song(self, song: Optional[Song]) -> None:
        if not song:
            return
        elide_into(self.ribbon_title, song.title, self.ribbon_title.width() or 160)
        elide_into(self.ribbon_artist, song.byline, self.ribbon_artist.width() or 160)
        elide_into(self.hero_title, song.title, 190)
        elide_into(self.hero_artist, song.byline, 190)

        self.seek.setRange(0, 0)
        self.seek.setValue(0)
        self.elapsed.setText("0:00")
        self.total.setText("0:00")

        # Check favorite status
        if self.storage:
            self._update_favorite_buttons(self.storage.is_favorite(song.video_id))
            self.storage.record_history(song)

        cached = self._art_cache.get(song.video_id)
        if cached is not None:
            self._paint_art(song.video_id, cached)
        else:
            fallback_pix = music_icon(Palette.amber_hi).pixmap(24, 24)
            self.ribbon_art.setPixmap(fallback_pix)
            self.hero_art.setPixmap(music_icon(Palette.amber_hi).pixmap(40, 40))
            self._request_art(song)

        # Show desktop toast if enabled
        toast_enabled = str(self.settings.value(SETTINGS_TOAST_ENABLED, "true")).lower() in ("true", "1", "yes")
        if toast_enabled:
            self.toast.show_song(song, cached)

        self._lyrics_loaded_for = None
        if self._active_tab == "lyrics":
            self._fetch_lyrics(song)

        self._set_status("tuning in")

    def _on_queue(self, songs: List[Song]) -> None:
        if self._active_tab == "queue":
            self._render_song_list(songs, active_idx=self.core.cursor, empty_hint="search for something warm")

    def _on_cursor(self, index: int) -> None:
        if self._active_tab == "queue":
            for position in range(self.queue_list.count()):
                widget = self.queue_list.itemAt(position).widget()
                if isinstance(widget, QueueRow):
                    widget.set_active(widget.index == index)

    def _on_playing(self, playing: bool) -> None:
        self.ribbon_play.setIcon(pause_icon() if playing else play_icon())
        self.panel_play.setIcon(pause_icon() if playing else play_icon())
        self.disc.set_spinning(playing)
        self._set_status("playing" if playing else "paused")

    # ------------------------------------------------------------- lyrics slots
    def _fetch_lyrics(self, song: Song) -> None:
        self._current_lyrics_vid = song.video_id
        self.lyrics_text.setText(f"Searching lyrics for\n{song.title}...")
        job = LyricsJob(self.core.catalog, song.video_id)
        job.signals.lyrics_ready.connect(self._on_lyrics_ready)
        job.signals.lyrics_failed.connect(self._on_lyrics_failed)
        self.core.pool.start(job)

    def _on_lyrics_ready(self, video_id: str, lyrics: str, source: str = "") -> None:
        if self._current_lyrics_vid != video_id:
            return
        self._lyrics_loaded_for = video_id
        formatted = lyrics
        if source:
            formatted += f"\n\n— Source: {source}"
        self.lyrics_text.setText(formatted)

    def _on_lyrics_failed(self, video_id: str, message: str) -> None:
        if self._current_lyrics_vid != video_id:
            return
        self._lyrics_loaded_for = video_id
        self.lyrics_text.setText("Instrumental / No lyrics available")

    # -------------------------------------------------------- modes & playback rates
    def _on_repeat_mode_changed(self, mode: str) -> None:
        self.panel_repeat.setChecked(mode != "off")
        self.panel_repeat.setIcon(repeat_icon(mode))
        self.panel_repeat.setToolTip(f"Repeat: {mode.capitalize()}")

    def _on_rate_changed(self, rate: float) -> None:
        self.speed_btn.setText(f"{rate:g}x")

    def _cycle_speed(self) -> None:
        rates = [1.0, 1.25, 1.5, 0.75]
        cur = self.core.playback_rate
        try:
            idx = rates.index(cur)
            next_rate = rates[(idx + 1) % len(rates)]
        except ValueError:
            next_rate = 1.0
        self.core.set_playback_rate(next_rate)

    # ------------------------------------------------------------- sleep timer
    def _open_sleep_menu(self) -> None:
        menu = QMenu(self)
        presets = [
            ("15 minutes", 15),
            ("30 minutes", 30),
            ("45 minutes", 45),
            ("60 minutes", 60),
        ]
        for label, minutes in presets:
            action = menu.addAction(label)
            action.triggered.connect(lambda checked, m=minutes: self._start_sleep_timer(m))

        menu.addSeparator()
        cancel_act = menu.addAction("Turn Off Timer")
        cancel_act.setEnabled(self._sleep_seconds_remaining > 0)
        cancel_act.triggered.connect(self._cancel_sleep_timer)

        btn_pos = self.sleep_btn.mapToGlobal(QPoint(0, -menu.sizeHint().height() - 4))
        menu.exec(btn_pos)

    def _start_sleep_timer(self, minutes: int) -> None:
        self.core.cancel_fade()
        self._sleep_seconds_remaining = minutes * 60
        self._sleep_fading = False
        self._sleep_timer.start()
        self.sleep_btn.setChecked(True)
        self.sleep_btn.setText(f" {minutes}m")
        self.sleep_btn.setIcon(moon_icon(True))
        self._set_status(f"sleep timer: {minutes}m")

    def _on_sleep_tick(self) -> None:
        if self._sleep_seconds_remaining <= 0:
            self._cancel_sleep_timer()
            return

        self._sleep_seconds_remaining -= 1
        mins = self._sleep_seconds_remaining // 60
        secs = self._sleep_seconds_remaining % 60

        if mins > 0:
            self.sleep_btn.setText(f" {mins}m")
        else:
            self.sleep_btn.setText(f" {secs}s")

        # In last 15 seconds, initiate volume attenuation fade-out
        if self._sleep_seconds_remaining <= 15 and not self._sleep_fading:
            self._sleep_fading = True
            self.core.fade_out_and_pause(15000, on_done=self._on_sleep_finished)

        if self._sleep_seconds_remaining <= 0:
            self._cancel_sleep_timer()

    def _cancel_sleep_timer(self) -> None:
        self._sleep_timer.stop()
        self._sleep_seconds_remaining = 0
        if self._sleep_fading:
            self.core.cancel_fade()
            self._sleep_fading = False
        self.sleep_btn.setChecked(False)
        self.sleep_btn.setText(" Sleep")
        self.sleep_btn.setIcon(moon_icon(False))
        self._set_status("sleep timer off")

    def _on_sleep_finished(self) -> None:
        self._sleep_timer.stop()
        self._sleep_seconds_remaining = 0
        self._sleep_fading = False
        self.sleep_btn.setChecked(False)
        self.sleep_btn.setText(" Sleep")
        self.sleep_btn.setIcon(moon_icon(False))
        self._set_status("goodnight 🌙")

    def _on_progress(self, position: int) -> None:
        if self._scrubbing:
            return
        self.seek.setValue(position)
        self.elapsed.setText(clock(position))

    def _on_length(self, duration: int) -> None:
        self.seek.setRange(0, max(0, duration))
        self.total.setText(clock(duration))

    def _on_loading(self, loading: bool) -> None:
        if loading:
            self._set_status("loading")

    def _on_notice(self, message: str) -> None:
        self._set_status(message)

    def _set_status(self, message: str) -> None:
        self.status.setText(message)
        if message != "ready":
            self._notice_timer.start(4000)

    def _on_scrub(self, position: int) -> None:
        self._scrubbing = True
        self.elapsed.setText(clock(position))

    def _on_scrub_done(self, position: int) -> None:
        self._scrubbing = False
        self.core.seek(position)

    # ------------------------------------------------------------- debounced search
    def _on_field_changed(self, text: str) -> None:
        raw = text.strip()
        if len(raw) >= 3 and not looks_like_link(raw):
            self._debounce_timer.start()
        else:
            self._debounce_timer.stop()

    def _on_debounced_search(self) -> None:
        text = self.field.text().strip()
        if len(text) >= 3 and not looks_like_link(text):
            self._execute_search(text)

    def _on_find(self) -> None:
        self._debounce_timer.stop()
        text = self.field.text().strip()
        if not text:
            return
        if looks_like_link(text):
            self.core.open_link(text)
            self.field.clear()
            return
        self._execute_search(text)

    def _execute_search(self, query: str) -> None:
        self._set_status("searching")
        self._active_search = query
        job = SearchJob(self.core.catalog, query, 12)
        job.signals.done.connect(self._on_search_done)
        job.signals.failed.connect(self._on_search_failed)
        self.core.pool.start(job)

    def _on_search_done(self, query: str, songs: List[Song]) -> None:
        if getattr(self, "_active_search", None) != query:
            return  # stale search results from an older query
        if not songs:
            self._set_status("nothing found")
            return
        if self.field.text().strip() == query:
            self.field.clear()
        self._switch_tab("queue")
        self.core.adopt(songs, 0)
        self._set_status(pretty_count(len(songs), "result"))

    def _on_search_failed(self, query: str, message: str) -> None:
        if getattr(self, "_active_search", None) != query:
            return
        self._set_status("search failed")
        log.warning("search %r failed: %s", query, message)

    def _on_volume(self, percent: int) -> None:
        self.core.set_volume(percent)

    def _on_endless(self, enabled: bool) -> None:
        self.core.set_auto_queue(enabled)
        self.endless_toggled.emit(enabled)
        self._set_status("endless on" if enabled else "endless off")

    def closeEvent(self, event) -> None:  # noqa: N802
        if self._sleep_timer.isActive():
            self._sleep_timer.stop()
        self.core.cancel_fade()
        self.toast.close()
        self.closed.emit()
        super().closeEvent(event)

    def _on_quit(self) -> None:
        self.close()

    # -------------------------------------------------------------- public API
    def current_position(self) -> Tuple[int, int]:
        return self.x(), self.y()

    def place(self, x: int, y: int) -> None:
        self.move(x, y)
        self.clamp_to_screen()
        self._capture_anchor()

    def hotkeys(self) -> List[Tuple[str, Callable[[], None]]]:
        """User-configured (sequence, callback) pairs to register on the window."""
        cfg_toggle = str(self.settings.value(f"{SETTINGS_HOTKEYS}/toggle", DEFAULT_HOTKEYS["toggle"]))
        cfg_forward = str(self.settings.value(f"{SETTINGS_HOTKEYS}/forward", DEFAULT_HOTKEYS["forward"]))
        cfg_back = str(self.settings.value(f"{SETTINGS_HOTKEYS}/back", DEFAULT_HOTKEYS["back"]))
        cfg_expand = str(self.settings.value(f"{SETTINGS_HOTKEYS}/expand", DEFAULT_HOTKEYS["expand"]))

        return [
            (cfg_toggle, self.core.toggle),
            (cfg_forward, self.core.forward),
            (cfg_back, self.core.back),
            (cfg_expand, self.toggle_expand),
            ("Ctrl+Alt+Up", self.expand),
            ("Ctrl+Alt+Down", self.collapse),
            ("Ctrl+Alt+F", self._focus_field),
        ]

    def _focus_field(self) -> None:
        self.expand()
        self.field.setFocus(Qt.FocusReason.ShortcutFocusReason)
        self.field.selectAll()
