"""Tests for upgraded features: spring equalizer physics and opacity settings."""

from __future__ import annotations

from ember.config import DEFAULT_OPACITY, SETTINGS_OPACITY, SETTINGS_REPEAT, SETTINGS_SPEED
from ember.panel import SpringPhysics


def test_spring_physics_simulation_steps() -> None:
    pos = [3.5, 3.5, 3.5, 3.5]
    vel = [0.0, 0.0, 0.0, 0.0]

    # Step through 20 simulation frames
    for step_idx in range(1, 21):
        pos, vel = SpringPhysics.step(pos, vel, step_idx)
        assert len(pos) == 4
        assert len(vel) == 4
        for p in pos:
            # Heights are bounded within visual bar canvas [2.5, 13.5]
            assert 2.5 <= p <= 13.5

    # Ensure dynamic movement occurred
    assert any(abs(v) > 0.01 for v in vel)


def test_spring_physics_custom_damping_and_stiffness() -> None:
    pos = [1.0, 1.0]
    vel = [0.0, 0.0]
    new_pos, new_vel = SpringPhysics.step(pos, vel, step_idx=5, stiffness=0.5, damping=0.8)
    assert len(new_pos) == 2
    assert len(new_vel) == 2


def test_feature_settings_keys() -> None:
    assert 60 <= DEFAULT_OPACITY <= 100
    assert SETTINGS_OPACITY == "ui/opacity"
    assert SETTINGS_REPEAT == "playback/repeat"
    assert SETTINGS_SPEED == "playback/speed"



def test_as_repeat_mode_accepts_valid_modes() -> None:
    from ember.app import _as_repeat_mode

    assert _as_repeat_mode("all", "off") == "all"
    assert _as_repeat_mode("ONE", "off") == "one"
    assert _as_repeat_mode(" off ", "all") == "off"


def test_as_repeat_mode_falls_back_on_garbage() -> None:
    from ember.app import _as_repeat_mode

    assert _as_repeat_mode("shuffle", "off") == "off"
    assert _as_repeat_mode("", "off") == "off"
    assert _as_repeat_mode(None, "off") == "off"


def test_as_playback_rate_valid_range() -> None:
    from ember.app import _as_playback_rate

    assert _as_playback_rate("1.25", 1.0) == 1.25
    assert _as_playback_rate(1.5, 1.0) == 1.5
    assert _as_playback_rate("0.75", 1.0) == 0.75


def test_as_playback_rate_clamps_and_falls_back() -> None:
    from ember.app import _as_playback_rate

    assert _as_playback_rate("9.9", 1.0) == 2.5
    assert _as_playback_rate("0.1", 1.0) == 0.5
    assert _as_playback_rate("not-a-number", 1.0) == 1.0
    assert _as_playback_rate(None, 1.0) == 1.0
    assert _as_playback_rate(float("nan"), 1.0) == 1.0
