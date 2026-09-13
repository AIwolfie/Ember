"""
theme.py
Every stylesheet Ember uses, built from the Palette with string.Template.

Template (not f-strings) because Qt stylesheets are full of braces and
doubling them all would be unreadable.
"""

from __future__ import annotations

from string import Template
from typing import Any, Dict

from .config import Palette


def _tokens() -> Dict[str, Any]:
    """Extract string design tokens and dynamic RGB channels from Palette."""
    tokens: Dict[str, Any] = {}
    for name in dir(Palette):
        if not name.startswith("_") and name not in ("THEMES", "list_themes", "apply_theme", "current_theme"):
            val = getattr(Palette, name)
            if isinstance(val, str):
                tokens[name] = val
                if val.startswith("#") and len(val) == 7:
                    try:
                        r = int(val[1:3], 16)
                        g = int(val[3:5], 16)
                        b = int(val[5:7], 16)
                        tokens[f"{name}_rgb"] = f"{r}, {g}, {b}"
                    except ValueError:
                        pass
    return tokens


_PANEL = Template(
    """
QWidget {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    color: $text;
}

/* ---------------------------------------------------------- window shell */
#Shell {
    background: qlineargradient(x1:0, y1:0, x2:0.9, y2:1,
                stop:0 $shell_a, stop:0.55 $void, stop:1 $shell_b);
    border: 1px solid rgba($text_rgb, 0.12);
    border-radius: 22px;
}
#Ribbon, #Panel { background: transparent; }

/* --------------------------------------------------------------- typography */
#Display {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    font-size: 16px;
    font-weight: 800;
    color: $amber_hi;
    letter-spacing: 2px;
}
#Tagline { color: $faint; font-size: 9px; letter-spacing: 1.5px; font-weight: 600; }
#Credit { color: $faint; font-size: 9px; letter-spacing: 0.4px; font-weight: 500; font-style: italic; }
#RibbonTitle { color: $text; font-size: 12px; font-weight: 600; }
#RibbonArtist { color: $muted; font-size: 11px; }
#HeroTitle {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    font-size: 14px;
    font-weight: 700;
    color: $text;
}
#HeroArtist { color: $muted; font-size: 11px; }
#SectionLabel { color: $faint; font-size: 9px; letter-spacing: 2px; font-weight: 700; }
#Clock {
    color: $muted;
    font-size: 10px;
    font-family: "Consolas", "Courier New", monospace;
    font-weight: 600;
}
#Hint { color: $faint; font-size: 11px; }

#StatusChip {
    color: $amber_hi;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.5px;
    background: rgba($amber_rgb, 0.12);
    border: 1px solid rgba($amber_rgb, 0.32);
    border-radius: 11px;
    padding: 3px 10px;
}

/* ------------------------------------------------------------------ cards */
#NowCard {
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                stop:0 rgba($text_rgb, 0.05),
                stop:1 rgba($text_rgb, 0.02));
    border: 1px solid rgba($text_rgb, 0.08);
    border-radius: 18px;
}

/* ----------------------------------------------------------------- inputs */
#SearchField {
    background: $raised;
    border: 1px solid $line;
    border-radius: 14px;
    padding: 8px 14px;
    color: $text;
    font-size: 12px;
    selection-background-color: $amber_lo;
    selection-color: $ink;
}
#SearchField:focus {
    border: 1px solid $amber;
    background: $raised;
}

/* ---------------------------------------------------------------- buttons */
#AmberButton {
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 $amber_hi, stop:1 $amber);
    color: $ink;
    font-weight: 700;
    font-size: 11px;
    letter-spacing: 0.5px;
    border: none;
    border-radius: 14px;
    padding: 0 16px;
}
#AmberButton:hover {
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #FFF, stop:1 $amber_hi);
}
#AmberButton:pressed { background: $amber_lo; }
#AmberButton:disabled { background: $raised; color: $faint; }

#RoundPlay {
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 $amber_hi, stop:1 $amber);
    border: none;
    border-radius: 19px;
}
#RoundPlay:hover {
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #FFFFFF, stop:1 $amber_hi);
}
#RoundPlay:pressed { background: $amber_lo; }

#Ghost {
    background: transparent;
    border: none;
    border-radius: 15px;
}
#Ghost:hover { background: rgba($text_rgb, 0.10); }
#Ghost:pressed { background: rgba($text_rgb, 0.16); }

#Pill {
    background: rgba($text_rgb, 0.05);
    border: 1px solid rgba($text_rgb, 0.06);
    border-radius: 13px;
}
#Pill:hover { background: rgba($text_rgb, 0.14); }
#PillClose {
    background: rgba($text_rgb, 0.05);
    border: 1px solid rgba($text_rgb, 0.06);
    border-radius: 13px;
}
#PillClose:hover { background: rgba($clay_rgb, 0.35); }

#HeartButton {
    background: transparent;
    border: none;
    border-radius: 13px;
}
#HeartButton:hover { background: rgba($clay_rgb, 0.16); }

#Chip {
    background: rgba($text_rgb, 0.04);
    border: 1px solid $line;
    border-radius: 12px;
    color: $muted;
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.5px;
    padding: 4px 12px;
}
#Chip:hover { color: $text; border: 1px solid $faint; background: rgba($text_rgb, 0.08); }
#Chip:checked {
    background: rgba($amber_rgb, 0.18);
    border: 1px solid rgba($amber_rgb, 0.45);
    color: $amber_hi;
}

#TabButton {
    background: rgba($text_rgb, 0.03);
    border: 1px solid transparent;
    border-radius: 11px;
    color: $muted;
    font-size: 10px;
    letter-spacing: 0.6px;
    padding: 4px 11px;
    font-weight: 700;
}
#TabButton:hover { color: $text; background: rgba($text_rgb, 0.08); }
#TabButton:checked {
    background: rgba($amber_rgb, 0.16);
    border: 1px solid rgba($amber_rgb, 0.38);
    color: $amber_hi;
}

/* ------------------------------------------------------------------ lyrics */
#LyricsScroll { background: transparent; border: none; }
#LyricsScroll > QWidget > QWidget { background: transparent; }
#LyricsText {
    color: $text;
    font-size: 13px;
    font-weight: 500;
}

/* ------------------------------------------------------------------ mode toggles */
#ModeToggle {
    background: transparent;
    border: 1px solid transparent;
    border-radius: 13px;
}
#ModeToggle:hover { background: rgba($text_rgb, 0.10); }
#ModeToggle:checked {
    background: rgba($amber_rgb, 0.18);
    border: 1px solid rgba($amber_rgb, 0.40);
}

#SleepPill {
    background: rgba($text_rgb, 0.04);
    border: 1px solid $line;
    border-radius: 11px;
    color: $muted;
    font-size: 10px;
    font-weight: 600;
    padding: 2px 7px;
}
#SleepPill:hover { color: $text; border: 1px solid $faint; background: rgba($text_rgb, 0.08); }
#SleepPill:checked {
    background: rgba($amber_rgb, 0.18);
    border: 1px solid rgba($amber_rgb, 0.45);
    color: $amber_hi;
}

#SpeedPill {
    background: rgba($text_rgb, 0.04);
    border: 1px solid $line;
    border-radius: 11px;
    color: $muted;
    font-size: 10px;
    font-weight: 700;
    padding: 2px 7px;
}
#SpeedPill:hover { color: $text; border: 1px solid $faint; background: rgba($text_rgb, 0.08); }

/* ------------------------------------------------------------------ queue */
#QueueScroll { background: transparent; border: none; }
#QueueScroll > QWidget > QWidget { background: transparent; }
QScrollBar:vertical { background: transparent; width: 6px; margin: 2px 0; }
QScrollBar::handle:vertical { background: $line; border-radius: 3px; min-height: 28px; }
QScrollBar::handle:vertical:hover { background: $faint; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical { background: transparent; }
"""
)

_MENU = Template(
    """
QMenu {
    background: $surface;
    border: 1px solid $line;
    border-radius: 14px;
    padding: 6px;
}
QMenu::item {
    padding: 8px 22px 8px 14px;
    border-radius: 8px;
    color: $text;
    font-size: 12px;
}
QMenu::item:selected { background: rgba($amber_rgb, 0.20); color: $amber_hi; }
QMenu::item:disabled { color: $faint; }
QMenu::separator { height: 1px; background: $line; margin: 5px 8px; }
QToolTip {
    background: $surface;
    color: $text;
    border: 1px solid $line;
    border-radius: 8px;
    padding: 5px 9px;
    font-size: 11px;
}
"""
)

_SETTINGS = Template(
    """
QDialog {
    background: $surface;
    border: 1px solid rgba($text_rgb, 0.14);
    border-radius: 20px;
    color: $text;
}
QLabel { color: $text; font-size: 12px; }
#SettingsTitle {
    font-size: 15px;
    font-weight: 800;
    letter-spacing: 1.5px;
    color: $amber_hi;
}
#SettingsSub { color: $faint; font-size: 10px; font-weight: 500; }
#SettingsSection { color: $amber; font-size: 11px; font-weight: 800; letter-spacing: 1.2px; }
QCheckBox { color: $text; font-size: 12px; spacing: 8px; }
QCheckBox::indicator { width: 16px; height: 16px; border: 1px solid $line; border-radius: 5px; background: $raised; }
QCheckBox::indicator:checked { background: $amber; border: 1px solid $amber_hi; }
QComboBox {
    background: $raised;
    color: $text;
    border: 1px solid $line;
    border-radius: 10px;
    padding: 6px 12px;
    font-size: 12px;
    font-weight: 600;
}
QComboBox QAbstractItemView {
    background: $surface;
    color: $text;
    selection-background-color: $raised;
    border: 1px solid $line;
}
QSlider::groove:horizontal {
    height: 4px;
    background: $line;
    border-radius: 2px;
}
QSlider::sub-page:horizontal {
    background: $amber;
    border-radius: 2px;
}
QSlider::handle:horizontal {
    background: $amber_hi;
    width: 14px;
    height: 14px;
    margin-top: -5px;
    margin-bottom: -5px;
    border-radius: 7px;
}
QSlider::handle:horizontal:hover {
    background: #FFFFFF;
}
"""
)

_TOAST = Template(
    """
#ToastShell {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 $shell_a, stop:1 $void);
    border: 1px solid rgba($text_rgb, 0.16);
    border-radius: 16px;
}
#ToastTitle { color: $text; font-size: 12px; font-weight: 700; }
#ToastArtist { color: $muted; font-size: 11px; }
#ToastBadge { color: $amber_hi; font-size: 9px; letter-spacing: 1.2px; font-weight: 800; }
"""
)


def panel_stylesheet() -> str:
    """Full stylesheet for the floating panel and everything inside it."""
    return _PANEL.substitute(_tokens())


def popup_stylesheet() -> str:
    """Applied application-wide — only touches menus and tooltips."""
    return _MENU.substitute(_tokens())


def settings_stylesheet() -> str:
    """Stylesheet for the preferences and settings dialog."""
    return _SETTINGS.substitute(_tokens())


def toast_stylesheet() -> str:
    """Stylesheet for the now-playing desktop toast notification."""
    return _TOAST.substitute(_tokens())