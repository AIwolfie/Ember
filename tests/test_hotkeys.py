"""Tests for hotkey conflict detection (system, reserved, and duplicate chords)."""

from __future__ import annotations

from ember.settings_dialog import (
    DEFAULT_HOTKEYS,
    RESERVED_COLLAPSE,
    RESERVED_EXPAND,
    RESERVED_FOCUS_SEARCH,
    RESERVED_HOTKEYS,
    find_hotkey_conflicts,
)


def test_reserved_chords_are_declared() -> None:
    # The three built-in chords FloatingPanel.hotkeys() always registers.
    assert RESERVED_EXPAND == "Ctrl+Alt+Up"
    assert RESERVED_COLLAPSE == "Ctrl+Alt+Down"
    assert RESERVED_FOCUS_SEARCH == "Ctrl+Alt+F"
    assert len(RESERVED_HOTKEYS) == 3


def test_default_hotkeys_have_no_conflicts() -> None:
    assert find_hotkey_conflicts(DEFAULT_HOTKEYS) == []


def test_windows_system_chord_flagged() -> None:
    conflicts = find_hotkey_conflicts({"toggle": "Ctrl+C"})
    assert conflicts == ["'Ctrl+C' (Windows system)"]


def test_reserved_chord_flagged_with_builtin_action() -> None:
    conflicts = find_hotkey_conflicts({"toggle": RESERVED_EXPAND})
    assert conflicts == [f"'{RESERVED_EXPAND}' (built-in: expand panel)"]


def test_duplicate_chord_flagged() -> None:
    conflicts = find_hotkey_conflicts({"toggle": "Ctrl+Alt+P", "forward": "Ctrl+Alt+P"})
    assert conflicts == ["'Ctrl+Alt+P' (duplicate)"]


def test_empty_chords_ignored() -> None:
    assert find_hotkey_conflicts({"toggle": "", "forward": "   "}) == []


def test_no_false_positive_on_similar_chords() -> None:
    # Ctrl+Alt+Left/Right/Space/E (defaults) must not trip the reserved set.
    chords = dict(DEFAULT_HOTKEYS)
    chords["back"] = "Ctrl+Alt+Left"
    assert find_hotkey_conflicts(chords) == []
