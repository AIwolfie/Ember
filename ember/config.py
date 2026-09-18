"""
config.py
Branding, palette, geometry and tunables for Ember.

Everything visual lives here so the theme can be re-tuned in one place
without touching layout logic.
"""

from __future__ import annotations

from typing import Dict

APP_NAME = "Ember"
APP_TAGLINE = "cozy listening"
ORG_NAME = "Ember Audio"
APP_ID = "ember.desktop.companion"

# ---------------------------------------------------------------- attribution
APP_AUTHOR = "Mayank Malaviya"
APP_AUTHOR_HANDLE = "AIwolfie"
APP_CREDIT = f"developed by {APP_AUTHOR} aka {APP_AUTHOR_HANDLE}"

# ---------------------------------------------------------------- geometry
PANEL_WIDTH = 392
SHELL_MARGIN = 10          # transparent gutter that gives the drop shadow room
COMPACT_HEIGHT = 62        # ribbon shell height
ART_COMPACT = 38
ART_HERO = 76
QUEUE_VIEW_HEIGHT = 168
EXPANDED_HEIGHT = 556      # full panel shell height
PILL_WIDTH = 216           # micro-pill / dynamic island width
PILL_HEIGHT = 38           # micro-pill / dynamic island height

# ---------------------------------------------------------------- behaviour
RADIO_DEPTH = 26           # how many look-alike tracks we pull per seed
SEARCH_DEPTH = 12
DEFAULT_VOLUME = 78
SEEK_MS_BACKSTEP = 3500    # "previous" restarts the song if we're past this
VINYL_TICK_MS = 55
VINYL_DEGREES = 0.5        # rotation per tick while audio is playing
ARTWORK_CACHE_LIMIT = 64
ANIM_MS = 240
SEARCH_DEBOUNCE_MS = 350   # ms before search query auto-fires while typing
SWITCH_TIMEOUT_MS = 28000  # a setSource that never opens fails the load instead of spinning
STREAM_CACHE_TTL_S = 2700  # 45 min — resolved URLs are signed and expire
YTDLP_MAX_AGE_DAYS = 30    # warn past this; extractor breakage is the #1 bug report
DEFAULT_CACHE_MAX_MB = 500 # persistent audio cache cap

# ---------------------------------------------------------------- settings keys
SETTINGS_POS_X = "panel/x"
SETTINGS_POS_Y = "panel/y"
SETTINGS_EXPANDED = "panel/expanded"
SETTINGS_VIEW_MODE = "ui/view_mode"
SETTINGS_VOLUME = "audio/volume"
SETTINGS_NORMALIZE_VOLUME = "audio/normalize_volume"
SETTINGS_AUDIO_DEVICE = "audio/device"
SETTINGS_AUDIO_QUALITY = "audio/quality"
SETTINGS_CACHE_ENABLED = "cache/enabled"
SETTINGS_CACHE_MAX_MB = "cache/max_mb"
SETTINGS_LISTENBRAINZ_TOKEN = "scrobble/listenbrainz_token"
SETTINGS_AUTO_QUEUE = "queue/endless"
SETTINGS_THEME = "ui/theme"
SETTINGS_TOAST_ENABLED = "ui/toast_enabled"
SETTINGS_HOTKEYS = "ui/hotkeys"
SETTINGS_OPACITY = "ui/opacity"
SETTINGS_REPEAT = "playback/repeat"
SETTINGS_SPEED = "playback/speed"
DEFAULT_OPACITY = 96


class Palette:
    """Warm, low-light palette. Espresso base, amber light, cream type.

    Extended to support dynamic theme presets while serving as the single source
    of visual truth across the application.
    """

    current_theme: str = "Amber"

    # Default Amber palette tokens
    void = "#1B1411"
    shell_a = "#281B15"
    shell_b = "#191210"
    surface = "#2A1E18"
    raised = "#34241C"
    line = "#3E2C22"

    text = "#F4E9DD"
    muted = "#B79B86"
    faint = "#8A7060"

    amber = "#E8A468"
    amber_hi = "#F5C495"
    amber_lo = "#C07A38"

    clay = "#C97F6A"
    sage = "#9FBFA3"

    ink = "#2A1A0E"  # text drawn on top of amber fills

    THEMES: Dict[str, Dict[str, str]] = {
        "Amber": {
            "void": "#1B1411",
            "shell_a": "#281B15",
            "shell_b": "#191210",
            "surface": "#2A1E18",
            "raised": "#34241C",
            "line": "#3E2C22",
            "text": "#F4E9DD",
            "muted": "#B79B86",
            "faint": "#8A7060",
            "amber": "#E8A468",
            "amber_hi": "#F5C495",
            "amber_lo": "#C07A38",
            "clay": "#C97F6A",
            "sage": "#9FBFA3",
            "ink": "#2A1A0E",
        },
        "Emerald": {
            "void": "#0F1812",
            "shell_a": "#15241B",
            "shell_b": "#0C140F",
            "surface": "#1A2E22",
            "raised": "#223B2C",
            "line": "#2C4A38",
            "text": "#E3F2E7",
            "muted": "#8BA893",
            "faint": "#5F7866",
            "amber": "#5BC479",
            "amber_hi": "#88DC9F",
            "amber_lo": "#3BA357",
            "clay": "#D97B66",
            "sage": "#78C9A8",
            "ink": "#0A1F11",
        },
        "Amethyst": {
            "void": "#15101E",
            "shell_a": "#221731",
            "shell_b": "#100C18",
            "surface": "#291B3C",
            "raised": "#35244C",
            "line": "#453160",
            "text": "#F0EAFA",
            "muted": "#A799BF",
            "faint": "#75668C",
            "amber": "#B07BE0",
            "amber_hi": "#CDA2F3",
            "amber_lo": "#9052C9",
            "clay": "#E07B9E",
            "sage": "#8E94DB",
            "ink": "#1B0D2C",
        },
        "Solar": {
            "void": "#171510",
            "shell_a": "#262116",
            "shell_b": "#12100C",
            "surface": "#302A1C",
            "raised": "#3D3524",
            "line": "#4C422D",
            "text": "#F9F5EB",
            "muted": "#BDB49A",
            "faint": "#8C836A",
            "amber": "#E5B842",
            "amber_hi": "#F8D572",
            "amber_lo": "#BF9220",
            "clay": "#D67554",
            "sage": "#B4C276",
            "ink": "#2B2105",
        },
        "Rose": {
            "void": "#1C1215",
            "shell_a": "#2C1B21",
            "shell_b": "#160C10",
            "surface": "#372028",
            "raised": "#452833",
            "line": "#563441",
            "text": "#FAEDF0",
            "muted": "#BA99A3",
            "faint": "#8A6973",
            "amber": "#E26D85",
            "amber_hi": "#F69CB0",
            "amber_lo": "#BD4760",
            "clay": "#E0836A",
            "sage": "#A4C7B5",
            "ink": "#2D0A14",
        },
    }

    @classmethod
    def apply_theme(cls, theme_name: str) -> None:
        """Dynamically apply a theme preset without altering token bindings."""
        if theme_name not in cls.THEMES:
            return
        cls.current_theme = theme_name
        for key, value in cls.THEMES[theme_name].items():
            setattr(cls, key, value)

    @classmethod
    def list_themes(cls) -> list[str]:
        """Return available theme preset names."""
        return list(cls.THEMES.keys())