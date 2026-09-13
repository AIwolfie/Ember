"""Tests for upgraded features: spring equalizer physics and opacity settings."""

from __future__ import annotations

import ember.config as config_module
from ember.audio_devices import DEFAULT_AUDIO_DEVICE_ID
from ember.config import (
    CLOSE_ACTION_EXIT,
    CLOSE_ACTION_TRAY,
    DEFAULT_CLOSE_ACTION,
    DEFAULT_OPACITY,
    SETTINGS_CLOSE_ACTION,
    SETTINGS_OPACITY,
    SETTINGS_REPEAT,
    SETTINGS_SPEED,
)
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
    assert DEFAULT_AUDIO_DEVICE_ID == "default"
    assert not hasattr(config_module, "SETTINGS_AUDIO_DEVICE")
    assert SETTINGS_CLOSE_ACTION == "ui/close_action"
    assert DEFAULT_CLOSE_ACTION == CLOSE_ACTION_EXIT
    assert {CLOSE_ACTION_EXIT, CLOSE_ACTION_TRAY} == {
        "exit",
        "tray",
    }
    assert SETTINGS_OPACITY == "ui/opacity"
    assert SETTINGS_REPEAT == "playback/repeat"
    assert SETTINGS_SPEED == "playback/speed"

