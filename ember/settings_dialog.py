"""
settings_dialog.py
Preferences panel for Ember: theme switching, audio normalization,
endless queue toggle, desktop notifications, and hotkey configuration.
"""

from __future__ import annotations

import logging
from typing import Dict, List, Optional

from PyQt6.QtCore import QPoint, QSettings, QSize, Qt, pyqtSignal
from PyQt6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QDialog,
    QFrame,
    QGraphicsDropShadowEffect,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QSlider,
    QVBoxLayout,
    QWidget,
)

from .config import (
    DEFAULT_OPACITY,
    Palette,
    SETTINGS_AUDIO_DEVICE,
    SETTINGS_AUDIO_QUALITY,
    SETTINGS_AUTO_QUEUE,
    SETTINGS_CACHE_ENABLED,
    SETTINGS_HOTKEYS,
    SETTINGS_LISTENBRAINZ_TOKEN,
    SETTINGS_NORMALIZE_VOLUME,
    SETTINGS_OPACITY,
    SETTINGS_THEME,
    SETTINGS_TOAST_ENABLED,
)
from .icons import close_icon, keyboard_icon, palette_icon, settings_icon, sliders_icon
from .theme import settings_stylesheet

log = logging.getLogger(__name__)

WINDOWS_CONFLICTS = {
    "Ctrl+C",
    "Ctrl+V",
    "Ctrl+X",
    "Ctrl+Z",
    "Ctrl+A",
    "Alt+F4",
    "Alt+Tab",
    "Ctrl+Alt+Del",
    "Win+L",
    "Win+D",
}

DEFAULT_HOTKEYS: Dict[str, str] = {
    "toggle": "Ctrl+Alt+Space",
    "forward": "Ctrl+Alt+Right",
    "back": "Ctrl+Alt+Left",
    "expand": "Ctrl+Alt+E",
}


class SettingsDialog(QDialog):
    """Preferences dialog with FontAwesome vector icons and hotkey conflict detection."""

    theme_changed = pyqtSignal(str)
    opacity_changed = pyqtSignal(int)
    normalization_changed = pyqtSignal(bool)
    endless_changed = pyqtSignal(bool)
    toast_changed = pyqtSignal(bool)
    hotkeys_changed = pyqtSignal(dict)
    device_changed = pyqtSignal(str)
    quality_changed = pyqtSignal(str)
    cache_toggled = pyqtSignal(bool)
    cache_cleared = pyqtSignal()
    listenbrainz_token_changed = pyqtSignal(str)

    def __init__(self, settings: QSettings, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self.settings = settings
        self._drag_offset: Optional[QPoint] = None

        self.setWindowTitle("Ember Settings")
        self.setWindowFlags(
            Qt.WindowType.Dialog
            | Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setFixedSize(400, 680)

        self._build()
        self._load_values()
        self.setStyleSheet(settings_stylesheet())

    def _build(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(10, 10, 10, 10)

        self.shell = QFrame(self)
        self.shell.setObjectName("Shell")
        outer.addWidget(self.shell)

        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(36)
        shadow.setOffset(0, 10)
        shadow.setColor(Qt.GlobalColor.black)
        self.shell.setGraphicsEffect(shadow)

        layout = QVBoxLayout(self.shell)
        layout.setContentsMargins(20, 18, 20, 18)
        layout.setSpacing(12)

        # Header with FA Gear Icon
        header = QHBoxLayout()
        icon_lbl = QLabel(self)
        icon_lbl.setPixmap(settings_icon(Palette.amber_hi).pixmap(20, 20))
        words = QVBoxLayout()
        title = QLabel("PREFERENCES & TUNABLES", self)
        title.setObjectName("SettingsTitle")
        sub = QLabel("tune your desktop music companion", self)
        sub.setObjectName("SettingsSub")
        words.addWidget(title)
        words.addWidget(sub)
        header.addWidget(icon_lbl)
        header.addLayout(words, 1)

        close_btn = QPushButton(self)
        close_btn.setObjectName("PillClose")
        close_btn.setFixedSize(26, 26)
        close_btn.setIcon(close_icon())
        close_btn.setIconSize(QSize(13, 13))
        close_btn.clicked.connect(self.accept)
        header.addWidget(close_btn)
        layout.addLayout(header)

        # Theme selection
        theme_hdr = QHBoxLayout()
        pal_ico = QLabel(self)
        pal_ico.setPixmap(palette_icon(Palette.amber).pixmap(14, 14))
        theme_sec = QLabel("APPEARANCE", self)
        theme_sec.setObjectName("SettingsSection")
        theme_hdr.addWidget(pal_ico)
        theme_hdr.addWidget(theme_sec)
        theme_hdr.addStretch(1)
        layout.addLayout(theme_hdr)

        theme_row = QHBoxLayout()
        theme_label = QLabel("Color Palette:", self)
        self.theme_combo = QComboBox(self)
        for theme_name in Palette.list_themes():
            self.theme_combo.addItem(theme_name)
        self.theme_combo.currentTextChanged.connect(self._on_theme_selected)
        theme_row.addWidget(theme_label)
        theme_row.addWidget(self.theme_combo, 1)
        layout.addLayout(theme_row)

        # Glass opacity slider
        opacity_row = QHBoxLayout()
        opacity_label = QLabel("Glass Opacity:", self)
        self.opacity_slider = QSlider(Qt.Orientation.Horizontal, self)
        self.opacity_slider.setRange(60, 100)
        self.opacity_slider.setValue(DEFAULT_OPACITY)
        self.opacity_val_lbl = QLabel(f"{DEFAULT_OPACITY}%", self)
        self.opacity_val_lbl.setFixedWidth(36)
        self.opacity_slider.valueChanged.connect(self._on_opacity_changed)
        opacity_row.addWidget(opacity_label)
        opacity_row.addWidget(self.opacity_slider, 1)
        opacity_row.addWidget(self.opacity_val_lbl)
        layout.addLayout(opacity_row)

        # Audio & Queue tunables
        audio_hdr = QHBoxLayout()
        slide_ico = QLabel(self)
        slide_ico.setPixmap(sliders_icon(Palette.amber).pixmap(14, 14))
        audio_sec = QLabel("PLAYBACK & QUEUE", self)
        audio_sec.setObjectName("SettingsSection")
        audio_hdr.addWidget(slide_ico)
        audio_hdr.addWidget(audio_sec)
        audio_hdr.addStretch(1)
        layout.addLayout(audio_hdr)

        self.chk_normalize = QCheckBox("Volume Normalization (soften loudness spikes)", self)
        self.chk_normalize.toggled.connect(self._on_normalize_toggled)
        layout.addWidget(self.chk_normalize)

        self.chk_endless = QCheckBox("Endless Recommendation Queue", self)
        self.chk_endless.toggled.connect(self._on_endless_toggled)
        layout.addWidget(self.chk_endless)

        self.chk_toast = QCheckBox("Show Now Playing Desktop Notification", self)
        self.chk_toast.toggled.connect(self._on_toast_toggled)
        layout.addWidget(self.chk_toast)

        # Output Device row
        dev_row = QHBoxLayout()
        dev_lbl = QLabel("Output Device:", self)
        self.device_combo = QComboBox(self)
        try:
            from PyQt6.QtMultimedia import QMediaDevices
            for dev in QMediaDevices.audioOutputs():
                self.device_combo.addItem(dev.description())
        except Exception:
            pass
        self.device_combo.currentTextChanged.connect(self._on_device_selected)
        dev_row.addWidget(dev_lbl)
        dev_row.addWidget(self.device_combo, 1)
        layout.addLayout(dev_row)

        # Audio Quality row
        qual_row = QHBoxLayout()
        qual_lbl = QLabel("Audio Quality:", self)
        self.quality_combo = QComboBox(self)
        self.quality_combo.addItem("Studio (Opus 48kHz / FLAC)", "studio")
        self.quality_combo.addItem("Standard (AAC / M4A)", "standard")
        self.quality_combo.currentIndexChanged.connect(self._on_quality_selected)
        qual_row.addWidget(qual_lbl)
        qual_row.addWidget(self.quality_combo, 1)
        layout.addLayout(qual_row)

        # Disk cache row
        cache_row = QHBoxLayout()
        self.chk_cache = QCheckBox("Disk Cache (0ms Replay)", self)
        self.chk_cache.toggled.connect(self._on_cache_toggled)
        self.btn_clear_cache = QPushButton("Clear Cache", self)
        self.btn_clear_cache.setObjectName("Pill")
        self.btn_clear_cache.setFixedHeight(24)
        self.btn_clear_cache.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_clear_cache.clicked.connect(self._on_clear_cache)
        cache_row.addWidget(self.chk_cache, 1)
        cache_row.addWidget(self.btn_clear_cache)
        layout.addLayout(cache_row)

        # Scrobbler section
        scrobble_hdr = QHBoxLayout()
        scrobble_sec = QLabel("SCROBBLING", self)
        scrobble_sec.setObjectName("SettingsSection")
        scrobble_hdr.addWidget(scrobble_sec)
        scrobble_hdr.addStretch(1)
        layout.addLayout(scrobble_hdr)

        lb_row = QHBoxLayout()
        lb_label = QLabel("ListenBrainz:", self)
        self.lb_token_input = QLineEdit(self)
        self.lb_token_input.setObjectName("SearchField")
        self.lb_token_input.setPlaceholderText("User Token...")
        self.lb_token_input.setFixedHeight(28)
        lb_row.addWidget(lb_label)
        lb_row.addWidget(self.lb_token_input, 1)
        layout.addLayout(lb_row)

        # Hotkeys
        hotkey_hdr = QHBoxLayout()
        key_ico = QLabel(self)
        key_ico.setPixmap(keyboard_icon(Palette.amber).pixmap(14, 14))
        hotkey_sec = QLabel("HOTKEY CHORDS", self)
        hotkey_sec.setObjectName("SettingsSection")
        hotkey_hdr.addWidget(key_ico)
        hotkey_hdr.addWidget(hotkey_sec)
        hotkey_hdr.addStretch(1)
        layout.addLayout(hotkey_hdr)

        self.hotkey_inputs: Dict[str, QLineEdit] = {}
        labels = [
            ("toggle", "Play / Pause:"),
            ("forward", "Next Track:"),
            ("back", "Previous:"),
            ("expand", "Toggle Panel:"),
        ]
        for key, text in labels:
            hrow = QHBoxLayout()
            hrow.setSpacing(6)
            hlabel = QLabel(text, self)
            hlabel.setFixedWidth(85)
            hinput = QLineEdit(self)
            hinput.setObjectName("SearchField")
            hinput.setFixedHeight(28)
            hinput.textChanged.connect(self._validate_hotkeys)
            self.hotkey_inputs[key] = hinput
            hrow.addWidget(hlabel)
            hrow.addWidget(hinput, 1)
            layout.addLayout(hrow)

        self.conflict_warn = QLabel("", self)
        self.conflict_warn.setStyleSheet("color: #E26D85; font-size: 10px; font-weight: 700;")
        self.conflict_warn.setVisible(False)
        layout.addWidget(self.conflict_warn)

        layout.addStretch(1)

        # Footer
        footer = QHBoxLayout()
        reset_btn = QPushButton("Reset Hotkeys", self)
        reset_btn.setObjectName("Pill")
        reset_btn.setFixedHeight(28)
        reset_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        reset_btn.clicked.connect(self._reset_hotkeys)
        footer.addWidget(reset_btn)

        footer.addStretch(1)

        save_btn = QPushButton("Save & Done", self)
        save_btn.setObjectName("AmberButton")
        save_btn.setFixedHeight(28)
        save_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        save_btn.clicked.connect(self._save_and_close)
        footer.addWidget(save_btn)

        layout.addLayout(footer)

    def _load_values(self) -> None:
        saved_theme = str(self.settings.value(SETTINGS_THEME, "Amber"))
        idx = self.theme_combo.findText(saved_theme)
        if idx >= 0:
            self.theme_combo.setCurrentIndex(idx)

        try:
            saved_opacity = int(self.settings.value(SETTINGS_OPACITY, DEFAULT_OPACITY))
        except (ValueError, TypeError):
            saved_opacity = DEFAULT_OPACITY
        saved_opacity = max(60, min(100, saved_opacity))
        self.opacity_slider.setValue(saved_opacity)
        self.opacity_val_lbl.setText(f"{saved_opacity}%")

        norm = str(self.settings.value(SETTINGS_NORMALIZE_VOLUME, "false")).lower() in ("true", "1", "yes")
        self.chk_normalize.setChecked(norm)

        endless = str(self.settings.value(SETTINGS_AUTO_QUEUE, "true")).lower() in ("true", "1", "yes")
        self.chk_endless.setChecked(endless)

        toast = str(self.settings.value(SETTINGS_TOAST_ENABLED, "true")).lower() in ("true", "1", "yes")
        self.chk_toast.setChecked(toast)

        saved_device = str(self.settings.value(SETTINGS_AUDIO_DEVICE, ""))
        if saved_device:
            idx = self.device_combo.findText(saved_device)
            if idx >= 0:
                self.device_combo.setCurrentIndex(idx)

        saved_quality = str(self.settings.value(SETTINGS_AUDIO_QUALITY, "studio"))
        qual_idx = self.quality_combo.findData(saved_quality)
        if qual_idx >= 0:
            self.quality_combo.setCurrentIndex(qual_idx)

        cache_en = str(self.settings.value(SETTINGS_CACHE_ENABLED, "true")).lower() in ("true", "1", "yes")
        self.chk_cache.setChecked(cache_en)

        saved_token = str(self.settings.value(SETTINGS_LISTENBRAINZ_TOKEN, ""))
        self.lb_token_input.setText(saved_token)

        for key, default_val in DEFAULT_HOTKEYS.items():
            val = str(self.settings.value(f"{SETTINGS_HOTKEYS}/{key}", default_val))
            if key in self.hotkey_inputs:
                self.hotkey_inputs[key].setText(val)

    def _on_device_selected(self, device_name: str) -> None:
        self.settings.setValue(SETTINGS_AUDIO_DEVICE, device_name)
        self.device_changed.emit(device_name)

    def _on_quality_selected(self, index: int) -> None:
        mode = self.quality_combo.currentData() or "studio"
        self.settings.setValue(SETTINGS_AUDIO_QUALITY, mode)
        self.quality_changed.emit(mode)

    def _on_cache_toggled(self, checked: bool) -> None:
        self.settings.setValue(SETTINGS_CACHE_ENABLED, checked)
        self.cache_toggled.emit(checked)

    def _on_clear_cache(self) -> None:
        self.cache_cleared.emit()
        self.btn_clear_cache.setText("Cleared ✓")

    def _on_opacity_changed(self, value: int) -> None:
        self.opacity_val_lbl.setText(f"{value}%")
        self.settings.setValue(SETTINGS_OPACITY, value)
        self.opacity_changed.emit(value)

    def _on_theme_selected(self, theme_name: str) -> None:
        self.settings.setValue(SETTINGS_THEME, theme_name)
        Palette.apply_theme(theme_name)
        self.setStyleSheet(settings_stylesheet())
        self.theme_changed.emit(theme_name)

    def _on_normalize_toggled(self, checked: bool) -> None:
        self.settings.setValue(SETTINGS_NORMALIZE_VOLUME, checked)
        self.normalization_changed.emit(checked)

    def _on_endless_toggled(self, checked: bool) -> None:
        self.settings.setValue(SETTINGS_AUTO_QUEUE, checked)
        self.endless_changed.emit(checked)

    def _on_toast_toggled(self, checked: bool) -> None:
        self.settings.setValue(SETTINGS_TOAST_ENABLED, checked)
        self.toast_changed.emit(checked)

    def _validate_hotkeys(self) -> None:
        conflicts: List[str] = []
        seen_chords: Dict[str, str] = {}
        for key, inp in self.hotkey_inputs.items():
            chord = inp.text().strip()
            if not chord:
                continue
            if chord in WINDOWS_CONFLICTS:
                conflicts.append(f"'{chord}' (Windows system)")
            elif chord in seen_chords:
                conflicts.append(f"'{chord}' (duplicate)")
            seen_chords[chord] = key
        if conflicts:
            self.conflict_warn.setText(f"Warning: {', '.join(conflicts)} conflict detected!")
            self.conflict_warn.setVisible(True)
        else:
            self.conflict_warn.setVisible(False)

    def _reset_hotkeys(self) -> None:
        for key, default_val in DEFAULT_HOTKEYS.items():
            if key in self.hotkey_inputs:
                self.hotkey_inputs[key].setText(default_val)
        self._validate_hotkeys()

    def _save_and_close(self) -> None:
        hotkeys: Dict[str, str] = {}
        for key, inp in self.hotkey_inputs.items():
            chord = inp.text().strip() or DEFAULT_HOTKEYS.get(key, "")
            hotkeys[key] = chord
            self.settings.setValue(f"{SETTINGS_HOTKEYS}/{key}", chord)
        token = self.lb_token_input.text().strip()
        self.settings.setValue(SETTINGS_LISTENBRAINZ_TOKEN, token)
        self.listenbrainz_token_changed.emit(token)
        self.settings.sync()
        self.hotkeys_changed.emit(hotkeys)
        self.accept()

    # Drag support
    def mousePressEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton:
            self._drag_offset = event.globalPosition().toPoint() - self.frameGeometry().topLeft()

    def mouseMoveEvent(self, event) -> None:  # noqa: N802
        if self._drag_offset is not None:
            self.move(event.globalPosition().toPoint() - self._drag_offset)

    def mouseReleaseEvent(self, event) -> None:  # noqa: N802
        self._drag_offset = None
