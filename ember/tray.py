"""
tray.py
The tray presence and the single-instance guard.

The Ember mark is painted at runtime from the same Palette the panel uses.
Nothing binary ships with the project, and the mark re-renders cleanly at every
size the shell asks for instead of being resampled from one bitmap.
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Optional

from PyQt6.QtCore import QLockFile, QObject, QStandardPaths, Qt, pyqtSignal
from PyQt6.QtGui import (
    QAction,
    QColor,
    QIcon,
    QLinearGradient,
    QPainter,
    QPainterPath,
    QPixmap,
)
from PyQt6.QtNetwork import QLocalServer, QLocalSocket
from PyQt6.QtWidgets import QMenu, QSystemTrayIcon, QWidget

from .config import APP_NAME, Palette

log = logging.getLogger(__name__)

SOCKET_NAME = "ember.companion.instance"
LOCK_FILE = "ember-companion.lock"
HANDSHAKE_TIMEOUT_MS = 500
ICON_SIZES = (16, 24, 32, 48, 64, 128, 256)


# ------------------------------------------------------------------ the mark
def ember_mark(side: int = 256) -> QPixmap:
    """A rounded ember: warm flame on a dark tile, drawn with the active Palette."""
    canvas = QPixmap(side, side)
    canvas.fill(Qt.GlobalColor.transparent)

    painter = QPainter(canvas)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)

    tile = QPainterPath()
    tile.addRoundedRect(0.0, 0.0, float(side), float(side), side * 0.24, side * 0.24)

    backdrop = QLinearGradient(0.0, 0.0, float(side), float(side))
    backdrop.setColorAt(0.0, QColor(Palette.shell_a))
    backdrop.setColorAt(1.0, QColor(Palette.void))
    painter.setPen(Qt.PenStyle.NoPen)
    painter.setBrush(backdrop)
    painter.drawPath(tile)

    light = QLinearGradient(0.0, float(side) * 0.80, 0.0, float(side) * 0.16)
    light.setColorAt(0.0, QColor(Palette.amber_lo))
    light.setColorAt(0.55, QColor(Palette.amber))
    light.setColorAt(1.0, QColor(Palette.amber_hi))

    flame = QPainterPath()
    flame.moveTo(side * 0.50, side * 0.17)
    flame.cubicTo(side * 0.79, side * 0.41, side * 0.77, side * 0.69, side * 0.50, side * 0.83)
    flame.cubicTo(side * 0.23, side * 0.69, side * 0.21, side * 0.41, side * 0.50, side * 0.17)
    flame.closeSubpath()
    painter.setBrush(light)
    painter.drawPath(flame)

    heart = QPainterPath()
    heart.moveTo(side * 0.50, side * 0.43)
    heart.cubicTo(side * 0.63, side * 0.56, side * 0.61, side * 0.69, side * 0.50, side * 0.74)
    heart.cubicTo(side * 0.39, side * 0.69, side * 0.37, side * 0.56, side * 0.50, side * 0.43)
    heart.closeSubpath()
    painter.setBrush(QColor(Palette.text))
    painter.drawPath(heart)

    painter.end()
    return canvas


def ember_icon() -> QIcon:
    """Multi-resolution icon built from the painted mark."""
    icon = QIcon()
    for side in ICON_SIZES:
        icon.addPixmap(ember_mark(side))
    return icon


def write_icon(path: str, side: int = 256) -> bool:
    """Persist a real .ico for shortcuts and taskbar pins. Best effort."""
    target = Path(path)
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            return True
        return ember_mark(side).toImage().save(str(target), "ICO")
    except OSError as exc:
        log.debug("icon write skipped: %s", exc)
        return False


# ---------------------------------------------------------- single instance
class InstanceGuard(QObject):
    """Keeps one Ember alive. A second launch nudges the first instead of splitting audio."""

    reveal_requested = pyqtSignal()

    def __init__(self, socket_name: str = SOCKET_NAME, parent: Optional[QObject] = None) -> None:
        super().__init__(parent)
        self.socket_name = socket_name
        self._lock: Optional[QLockFile] = None
        self._server: Optional[QLocalServer] = None

    def claim(self) -> bool:
        """True when this process owns the instance lock."""
        folder = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.TempLocation)
        if not folder:
            folder = "."
        try:
            Path(folder).mkdir(parents=True, exist_ok=True)
        except OSError:
            folder = "."

        self._lock = QLockFile(str(Path(folder) / LOCK_FILE))
        self._lock.setStaleLockTime(10000)  # 10s stale timeout (0 disables detection)
        if not self._lock.tryLock(200):
            if self._nudge_existing():
                log.info("instance lock held elsewhere — nudging the running copy")
                return False
            log.warning("detected abandoned lock file from previous crash — reclaiming")
            self._lock.removeStaleLockFile()
            if not self._lock.tryLock(200):
                log.error("unable to claim instance lock after clearing stale lock")
                return False

        QLocalServer.removeServer(self.socket_name)
        self._server = QLocalServer(self)
        self._server.newConnection.connect(self._on_connection)
        if not self._server.listen(self.socket_name):
            log.warning("instance socket unavailable: %s", self._server.errorString())
        return True

    def release(self) -> None:
        if self._server is not None:
            self._server.close()
            self._server = None
        if self._lock is not None:
            self._lock.unlock()
            self._lock = None

    def _nudge_existing(self) -> bool:
        probe = QLocalSocket()
        probe.connectToServer(self.socket_name)
        if probe.waitForConnected(HANDSHAKE_TIMEOUT_MS):
            probe.write(b"reveal")
            probe.flush()
            probe.waitForBytesWritten(HANDSHAKE_TIMEOUT_MS)
            probe.waitForDisconnected(HANDSHAKE_TIMEOUT_MS)
            probe.disconnectFromServer()
            return True
        probe.abort()
        return False

    def _on_connection(self) -> None:
        if self._server is None:
            return
        connection = self._server.nextPendingConnection()
        if connection is None:
            return
        if connection.bytesAvailable() > 0:
            self._consume(connection)
        else:
            connection.readyRead.connect(lambda: self._consume(connection))
        connection.disconnected.connect(connection.deleteLater)

    def _consume(self, connection: QLocalSocket) -> None:
        payload = bytes(connection.readAll()).strip()
        if payload == b"reveal":
            self.reveal_requested.emit()
        connection.disconnectFromServer()


# ------------------------------------------------------------------ presence
class TrayPresence(QObject):
    """Tray icon and menu. Emits intent only — the app decides what happens."""

    toggle_requested = pyqtSignal()
    back_requested = pyqtSignal()
    forward_requested = pyqtSignal()
    reveal_requested = pyqtSignal()
    quit_requested = pyqtSignal()

    def __init__(self, parent: Optional[QObject] = None) -> None:
        super().__init__(parent)
        self.icon = QSystemTrayIcon(ember_icon(), self)
        self.icon.setToolTip(f"{APP_NAME} — cozy listening")

        parent_widget = parent if isinstance(parent, QWidget) else None
        self.menu = QMenu(parent_widget)
        self._toggle = QAction("play / pause", self.menu)
        self._back = QAction("previous track", self.menu)
        self._forward = QAction("next track", self.menu)
        self._reveal = QAction("show ember", self.menu)
        self._quit = QAction("quit", self.menu)

        self.menu.addAction(self._toggle)
        self.menu.addAction(self._back)
        self.menu.addAction(self._forward)
        self.menu.addSeparator()
        self.menu.addAction(self._reveal)
        self.menu.addSeparator()
        self.menu.addAction(self._quit)

        self._toggle.triggered.connect(self.toggle_requested)
        self._back.triggered.connect(self.back_requested)
        self._forward.triggered.connect(self.forward_requested)
        self._reveal.triggered.connect(self.reveal_requested)
        self._quit.triggered.connect(self.quit_requested)

        self.icon.setContextMenu(self.menu)
        self.icon.activated.connect(self._on_activated)

    def _on_activated(self, reason: QSystemTrayIcon.ActivationReason) -> None:
        if reason in (
            QSystemTrayIcon.ActivationReason.Trigger,
            QSystemTrayIcon.ActivationReason.DoubleClick,
        ):
            self.reveal_requested.emit()

    def show(self) -> None:
        if QSystemTrayIcon.isSystemTrayAvailable():
            self.icon.show()
        else:
            log.info("no system tray here — the panel stands on its own")

    def hide(self) -> None:
        self.icon.hide()

    def cleanup(self) -> None:
        """Hide tray icon to eliminate Windows ghost tray icon and release menu."""
        self.icon.hide()
        if self.menu is not None:
            self.menu.close()
            self.menu.deleteLater()

    def notify(self, message: str, title: str = APP_NAME) -> None:
        if self.icon.isVisible():
            self.icon.showMessage(title, message, ember_icon(), 3500)

    def set_playing(self, playing: bool) -> None:
        self._toggle.setText("pause" if playing else "play")