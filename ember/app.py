from __future__ import annotations

import logging
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any, List

from PyQt6.QtCore import QSettings, QStandardPaths, QTimer
from PyQt6.QtGui import QKeySequence, QShortcut
from PyQt6.QtWidgets import QApplication

from .cache import AudioDiskCache
from .catalog import CatalogSource
from .config import (
    APP_NAME,
    APP_TAGLINE,
    DEFAULT_VOLUME,
    ORG_NAME,
    Palette,
    SETTINGS_AUDIO_DEVICE,
    SETTINGS_AUDIO_QUALITY,
    SETTINGS_AUTO_QUEUE,
    SETTINGS_CACHE_ENABLED,
    SETTINGS_EXPANDED,
    SETTINGS_LISTENBRAINZ_TOKEN,
    SETTINGS_NORMALIZE_VOLUME,
    SETTINGS_POS_X,
    SETTINGS_POS_Y,
    SETTINGS_THEME,
    SETTINGS_VIEW_MODE,
    SETTINGS_VOLUME,
)
from .panel import FloatingPanel
from .player import PlaybackCore
from .scrobbler import ScrobbleEngine
from .storage import DB_FILENAME, EmberStorage
from .stream import StreamResolver
from .smtc import WindowsMediaControls
from .discord_rpc import DiscordPresence
from .theme import popup_stylesheet
from .tray import InstanceGuard, TrayPresence, ember_icon, write_icon

log = logging.getLogger(__name__)

PLACEHOLDER_X = 24
PLACEHOLDER_Y = 24
SCREEN_INSET = 24
TOPMOST_REFRESH_MS = 4000
ICON_FILENAME = "ember.ico"
LOG_FILENAME = "ember.log"
MAX_LOG_BYTES = 2 * 1024 * 1024  # 2 MB per log rotation
LOG_BACKUP_COUNT = 3


# ------------------------------------------------------------------- coercion
def _as_int(raw: Any, fallback: int) -> int:
    """Safe integer conversion with fallback."""
    try:
        return int(raw)
    except (TypeError, ValueError):
        return fallback


def _as_bool(raw: Any, fallback: bool) -> bool:
    """Coerce boolean or string representation into bool."""
    if raw is None:
        return fallback
    if isinstance(raw, bool):
        return raw
    text = str(raw).strip().lower()
    if text in {"true", "1", "yes", "on"}:
        return True
    if text in {"false", "0", "no", "off"}:
        return False
    return fallback


# -------------------------------------------------------------------- logging
def _configure_logging(log_dir: Path) -> None:
    """Initialize stream and rotating file logging handlers."""
    try:
        log_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        log_dir = Path(".")

    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stderr)]
    try:
        handlers.append(
            RotatingFileHandler(
                log_dir / LOG_FILENAME,
                maxBytes=MAX_LOG_BYTES,
                backupCount=LOG_BACKUP_COUNT,
                encoding="utf-8",
            )
        )
    except OSError:
        pass

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
        handlers=handlers,
    )


# ------------------------------------------------------------------ lifecycle
def _surface(panel: FloatingPanel) -> None:
    """Bring the floating panel to front and assert topmost focus."""
    panel.show()
    panel.raise_()
    panel.activateWindow()
    panel.ensure_topmost()


def _restore_session(panel: FloatingPanel, core: PlaybackCore, settings: QSettings) -> None:
    """Restore window geometry, audio settings, theme, and queue state from previous run."""
    # Restore theme
    saved_theme = str(settings.value(SETTINGS_THEME, "Amber"))
    if saved_theme in Palette.THEMES:
        Palette.apply_theme(saved_theme)
        panel.reload_theme(saved_theme)

    screen = QApplication.primaryScreen()
    if screen is not None:
        bounds = screen.availableGeometry()
        fallback_x = max(PLACEHOLDER_X, bounds.right() - panel.width() - SCREEN_INSET)
        fallback_y = max(PLACEHOLDER_Y, bounds.bottom() - panel.height() - SCREEN_INSET)
    else:
        fallback_x, fallback_y = PLACEHOLDER_X, PLACEHOLDER_Y

    panel.place(
        _as_int(settings.value(SETTINGS_POS_X), fallback_x),
        _as_int(settings.value(SETTINGS_POS_Y), fallback_y),
    )

    volume = max(0, min(100, _as_int(settings.value(SETTINGS_VOLUME), DEFAULT_VOLUME)))
    core.set_volume(volume)
    panel.volume.set_value(volume)

    norm = _as_bool(settings.value(SETTINGS_NORMALIZE_VOLUME), False)
    core.set_normalize_volume(norm)

    endless = _as_bool(settings.value(SETTINGS_AUTO_QUEUE), True)
    core.set_auto_queue(endless)
    panel.endless.blockSignals(True)
    panel.endless.setChecked(endless)
    panel.endless.blockSignals(False)

    saved_mode = str(settings.value(SETTINGS_VIEW_MODE, "expanded" if _as_bool(settings.value(SETTINGS_EXPANDED), False) else "ribbon"))
    if saved_mode == "pill":
        panel.to_pill()
    elif saved_mode == "expanded":
        panel.expand()
    else:
        panel.to_ribbon()

    saved_device = str(settings.value(SETTINGS_AUDIO_DEVICE, ""))
    if saved_device:
        core.set_audio_device(saved_device)


def _persist(panel: FloatingPanel, core: PlaybackCore, settings: QSettings) -> None:
    """Persist session values on exit."""
    x, y = panel.current_position()
    settings.setValue(SETTINGS_POS_X, x)
    settings.setValue(SETTINGS_POS_Y, y)
    settings.setValue(SETTINGS_VIEW_MODE, panel.view_mode)
    settings.setValue(SETTINGS_EXPANDED, panel.expanded)
    settings.setValue(SETTINGS_VOLUME, core.volume())
    settings.setValue(SETTINGS_AUTO_QUEUE, core.auto_queue)
    settings.setValue(SETTINGS_NORMALIZE_VOLUME, core.normalize_volume)
    settings.setValue(SETTINGS_AUDIO_DEVICE, core.current_audio_device_name())
    settings.setValue(SETTINGS_THEME, Palette.current_theme)
    settings.sync()


def _wire_tray(
    tray: TrayPresence,
    panel: FloatingPanel,
    core: PlaybackCore,
    app: QApplication,
) -> None:
    """Connect tray context actions to playback engine and window control."""
    tray.toggle_requested.connect(core.toggle)
    tray.forward_requested.connect(core.forward)
    tray.back_requested.connect(core.back)
    tray.reveal_requested.connect(lambda: _surface(panel))
    tray.quit_requested.connect(app.quit)
    core.playing_changed.connect(tray.set_playing)
    panel.closed.connect(app.quit)


def _wire_shortcuts(panel: FloatingPanel) -> List[QShortcut]:
    """Register window-level hotkeys."""
    shortcuts: List[QShortcut] = []
    for sequence, callback in panel.hotkeys():
        if sequence:
            shortcut = QShortcut(QKeySequence(sequence), panel)
            shortcut.activated.connect(callback)
            shortcuts.append(shortcut)
    return shortcuts


# ----------------------------------------------------------------------- main
def main() -> int:
    """Main application lifecycle runner."""
    app = QApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    app.setApplicationDisplayName(APP_NAME)
    app.setOrganizationName(ORG_NAME)
    app.setDesktopFileName("ember")
    app.setQuitOnLastWindowClosed(False)
    app.setWindowIcon(ember_icon())
    app.setStyleSheet(popup_stylesheet())

    data_dir = Path(
        QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppDataLocation)
        or "."
    )
    _configure_logging(data_dir)
    log.info("%s starting — %s", APP_NAME, APP_TAGLINE)
    write_icon(str(data_dir / ICON_FILENAME))

    guard = InstanceGuard()
    if not guard.claim():
        log.info("another instance is already running — waking existing window")
        return 0

    settings = QSettings(ORG_NAME, APP_NAME)
    storage = EmberStorage(data_dir / DB_FILENAME)

    cache_enabled = _as_bool(settings.value(SETTINGS_CACHE_ENABLED), True)
    disk_cache = AudioDiskCache(cache_dir=data_dir / "cache" / "tracks", enabled=cache_enabled)

    catalog = CatalogSource()
    resolver = StreamResolver(disk_cache=disk_cache)
    saved_quality = str(settings.value(SETTINGS_AUDIO_QUALITY, "studio"))
    resolver.set_quality_mode(saved_quality)

    core = PlaybackCore(catalog, resolver, disk_cache=disk_cache)
    panel = FloatingPanel(core, storage, settings)
    tray = TrayPresence()

    # Scrobble Engine (ListenBrainz / Last.fm)
    lb_token = str(settings.value(SETTINGS_LISTENBRAINZ_TOKEN, ""))
    scrobbler = ScrobbleEngine(listenbrainz_token=lb_token, parent=panel)
    core.song_changed.connect(lambda s: scrobbler.on_song_changed(s, core._generation))
    core.progress_changed.connect(lambda pos: scrobbler.on_progress(pos, core.player.duration()))

    _restore_session(panel, core, settings)
    _wire_tray(tray, panel, core, app)
    guard.reveal_requested.connect(lambda: _surface(panel))

    registered_shortcuts = _wire_shortcuts(panel)

    def _on_hotkeys_updated() -> None:
        for shortcut in registered_shortcuts:
            shortcut.setEnabled(False)
            shortcut.deleteLater()
        registered_shortcuts.clear()
        registered_shortcuts.extend(_wire_shortcuts(panel))
        log.info("registered %d updated shortcuts", len(registered_shortcuts))

    panel.hotkeys_updated.connect(_on_hotkeys_updated)

    def _on_theme_reloaded(_: str) -> None:
        app.setStyleSheet(popup_stylesheet())
        tray.icon.setIcon(ember_icon())

    panel.theme_reloaded.connect(_on_theme_reloaded)

    topmost_guard = QTimer(panel)
    topmost_guard.setInterval(TOPMOST_REFRESH_MS)
    topmost_guard.timeout.connect(panel.ensure_topmost)
    topmost_guard.start()

    # Native Windows SMTC & Discord Rich Presence
    smtc = WindowsMediaControls(panel)
    discord = DiscordPresence(parent=panel)
    discord.connect_async()

    def _sync_media_metadata(song: Any) -> None:
        if song:
            smtc.update_metadata(song.title, song.byline, song.artwork_url or "")
            pos = core.player.position()
            dur = core.player.duration()
            discord.update(song.title, song.byline, pos, dur, core.is_playing)
        else:
            discord.clear()

    def _sync_media_playing(playing: bool) -> None:
        smtc.set_playback_status(playing)
        curr = core.current
        if curr:
            pos = core.player.position()
            dur = core.player.duration()
            discord.update(curr.title, curr.byline, pos, dur, playing)

    core.song_changed.connect(_sync_media_metadata)
    core.playing_changed.connect(_sync_media_playing)

    smtc.play_requested.connect(core.resume)
    smtc.pause_requested.connect(core.pause)
    smtc.toggle_requested.connect(core.toggle)
    smtc.next_requested.connect(lambda: core.forward(force=True))
    smtc.previous_requested.connect(core.back)
    smtc.stop_requested.connect(core.pause)

    app.aboutToQuit.connect(lambda: _persist(panel, core, settings))
    app.aboutToQuit.connect(guard.release)
    app.aboutToQuit.connect(tray.cleanup)
    app.aboutToQuit.connect(storage.close)
    app.aboutToQuit.connect(smtc.close)
    app.aboutToQuit.connect(discord.close)

    panel.show()
    panel.ensure_topmost()
    tray.show()

    return app.exec()
