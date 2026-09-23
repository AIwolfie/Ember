"""
test_sleep_exporter_visualizer.py
Unit tests for the three upgraded systems:
1. Smart Sleep Timer & Cosine Easing Fade-Out
2. 1-Click Tagged Offline Library Exporter
3. Dynamic Waveform Seekbar & Live Visualizer
"""

from __future__ import annotations

import math
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
from PyQt6.QtWidgets import QApplication

from ember.exporter import AudioExporter, sanitize_filename
from ember.models import Song
from ember.panel import SeekBar
from ember.player import PlaybackCore


@pytest.fixture(scope="session")
def qapp() -> QApplication:
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    return app


# ----------------------------------------------------------------- Seekbar tests
def test_waveform_seekbar_initialization_and_range(qapp: QApplication) -> None:
    bar = SeekBar()
    assert bar.height() == 22
    assert len(bar._bars) == 64
    # All bar heights bounded within [0.15, 1.0]
    for b in bar._bars:
        assert 0.15 <= b <= 1.0

    bar.setRange(0, 180000)
    assert bar._minimum == 0
    assert bar._maximum == 180000

    bar.setValue(90000)
    assert bar.value() == 90000


def test_waveform_seekbar_track_seed_and_animation(qapp: QApplication) -> None:
    bar = SeekBar()
    initial_bars = list(bar._bars)

    # Different track seed creates distinct acoustic profile
    bar.set_track_seed("video_xyz_789")
    assert bar._seed_key == "video_xyz_789"
    assert bar._bars != initial_bars

    # Same seed should not recompute
    cached_bars = list(bar._bars)
    bar.set_track_seed("video_xyz_789")
    assert bar._bars == cached_bars

    # Animation pulse toggling
    bar.set_playing(True)
    assert bar._is_playing is True
    assert bar._timer.isActive() is True

    prev_phase = bar._anim_phase
    bar._on_tick()
    assert bar._anim_phase != prev_phase

    bar.set_playing(False)
    assert bar._is_playing is False
    assert bar._timer.isActive() is False


# ----------------------------------------------------------------- Exporter tests
def test_sanitize_filename() -> None:
    assert sanitize_filename('Song: "The Best" / <Remix>? *') == "Song The Best  Remix"
    assert sanitize_filename("Artist Name...   ") == "Artist Name"
    assert sanitize_filename("") == "untitled"
    long_name = "A" * 200
    assert len(sanitize_filename(long_name, max_length=100)) == 100


def test_audio_exporter_local_file_copy_and_tagging() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        base_dir = Path(tmpdir) / "Music" / "Ember"
        source_dir = Path(tmpdir) / "source"
        source_dir.mkdir(parents=True)

        # Create dummy source audio file
        source_file = source_dir / "sample.m4a"
        source_file.write_bytes(b"\x00\x00\x00 ftypM4A \x00\x00\x00\x00isomiso2")

        exporter = AudioExporter(base_dir=base_dir)
        song = Song(
            video_id=f"local_{source_file}",
            title="Starman",
            artist="David Bowie",
            duration="4:14",
        )

        with patch.object(exporter, "_tag_audio_file") as mock_tag:
            exported_path = exporter.export_song(song)

            assert exported_path.exists()
            assert exported_path.parent.name == "David Bowie"
            assert exported_path.name == "Starman.m4a"
            assert mock_tag.call_count == 1


# ----------------------------------------------------------------- Sleep Timer tests
def test_fade_out_and_pause_cosine_curve(qapp: QApplication) -> None:
    from PyQt6.QtMultimedia import QMediaPlayer

    core = PlaybackCore(catalog=MagicMock(), resolver=MagicMock())
    core.set_volume(100)
    assert core.volume() == 100

    # Mock player as playing
    core.player.playbackState = MagicMock(return_value=QMediaPlayer.PlaybackState.PlayingState)
    with patch.object(core, "pause") as mock_pause:
        done_called = False

        def on_done() -> None:
            nonlocal done_called
            done_called = True

        core.fade_out_and_pause(duration_ms=100, on_done=on_done)
        assert core._fade_timer is not None
        assert core._pre_fade_volume == 100

        # Cancel restores original volume
        core.cancel_fade()
        assert core._fade_timer is None
        assert core.volume() == 100

