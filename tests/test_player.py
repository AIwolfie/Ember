"""Tests for PlaybackCore queue management, pruning, and recommendation validation."""

from __future__ import annotations

import sys
from unittest.mock import MagicMock
from PyQt6.QtWidgets import QApplication

from ember.models import Song
from ember.player import MAX_QUEUE_SIZE, PlaybackCore


def _get_qapp() -> QApplication:
    app = QApplication.instance()
    if app is None:
        app = QApplication(sys.argv)
    return app


def _create_core() -> PlaybackCore:
    _get_qapp()
    mock_catalog = MagicMock()
    mock_resolver = MagicMock()
    core = PlaybackCore(catalog=mock_catalog, resolver=mock_resolver)
    core._start_load = MagicMock()  # type: ignore[method-assign]
    core._start_radio = MagicMock()  # type: ignore[method-assign]
    return core


def test_playback_core_radio_seed_validation_outdated_seed() -> None:
    core = _create_core()
    core.queue = [Song(video_id="song_A", title="Song A", artist="Artist A")]
    core.cursor = 0
    core._radio_seed = "song_B"
    core._advance_after_extend = True

    fresh_songs = [Song(video_id="rec_1", title="Rec 1", artist="Artist")]
    core._on_radio_ready("song_A", fresh_songs)

    assert len(core.queue) == 1
    assert core.queue[0].video_id == "song_A"
    assert not core._advance_after_extend


def test_playback_core_radio_seed_validation_current_mismatch() -> None:
    core = _create_core()
    core.queue = [
        Song(video_id="song_1", title="Song 1", artist="Artist"),
        Song(video_id="song_2", title="Song 2", artist="Artist"),
    ]
    core.cursor = 1
    core._radio_seed = "song_1"

    fresh_songs = [Song(video_id="rec_1", title="Rec 1", artist="Artist")]
    core._on_radio_ready("song_1", fresh_songs)

    assert len(core.queue) == 2


def test_playback_core_max_queue_size_pruning() -> None:
    core = _create_core()
    core.queue = [
        Song(video_id=f"track_{i}", title=f"Track {i}", artist="Artist")
        for i in range(195)
    ]
    core.cursor = 50
    core._radio_seed = "track_50"

    cursor_changed_events: list[int] = []
    core.cursor_changed.connect(lambda c: cursor_changed_events.append(c))

    fresh_songs = [
        Song(video_id=f"new_{i}", title=f"New {i}", artist="Artist")
        for i in range(15)
    ]
    core._on_radio_ready("track_50", fresh_songs)

    assert len(core.queue) == 165
    assert core.cursor == 5
    assert cursor_changed_events == [5]
    assert core.current is not None
    assert core.current.video_id == "track_50"


def test_playback_core_queue_pruning_skipped_when_cursor_low() -> None:
    core = _create_core()
    core.queue = [
        Song(video_id=f"track_{i}", title=f"Track {i}", artist="Artist")
        for i in range(195)
    ]
    core.cursor = 8
    core._radio_seed = "track_8"

    fresh_songs = [
        Song(video_id=f"new_{i}", title=f"New {i}", artist="Artist")
        for i in range(15)
    ]
    core._on_radio_ready("track_8", fresh_songs)

    assert len(core.queue) == 210
    assert core.cursor == 8


def test_playback_core_repeat_mode_cycle_and_signals() -> None:
    core = _create_core()
    modes: list[str] = []
    core.repeat_mode_changed.connect(lambda m: modes.append(m))

    assert core.repeat_mode == "off"
    assert core.cycle_repeat_mode() == "all"
    assert core.cycle_repeat_mode() == "one"
    assert core.cycle_repeat_mode() == "off"
    assert modes == ["all", "one", "off"]


def test_playback_core_repeat_one_and_all_behavior() -> None:
    from PyQt6.QtMultimedia import QMediaPlayer
    core = _create_core()
    core.queue = [
        Song(video_id="s1", title="Song 1", artist="Artist"),
        Song(video_id="s2", title="Song 2", artist="Artist"),
    ]
    core.cursor = 1
    core.player.setPosition = MagicMock()  # type: ignore[method-assign]
    core.player.play = MagicMock()  # type: ignore[method-assign]

    def arm(track_id: str = "s2") -> None:
        """State a genuinely-loaded, settled track leaves behind.

        _relay_media_status only trusts an EndOfMedia that matches the track it
        actually loaded, so firing the signal on a bare core is correctly
        ignored — the end-of-track handlers have to be armed to be reached.
        """
        core._wanted = track_id
        core._loaded_id = track_id
        core._ended_id = None
        core._switching = False

    # Test repeat one on EndOfMedia
    core.set_repeat_mode("one")
    arm()
    core._relay_media_status(QMediaPlayer.MediaStatus.EndOfMedia)
    core.player.setPosition.assert_called_with(0)
    core.player.play.assert_called()

    # Test repeat all on EndOfMedia at queue end wraps to 0
    core.set_repeat_mode("all")
    core.play_at = MagicMock()  # type: ignore[method-assign]
    arm()
    core._relay_media_status(QMediaPlayer.MediaStatus.EndOfMedia)
    core.play_at.assert_called_with(0)


def test_playback_core_ignores_end_of_media_from_replaced_source() -> None:
    """The outgoing track's EndOfMedia must not advance the track just loaded."""
    from PyQt6.QtMultimedia import QMediaPlayer
    core = _create_core()
    core.queue = [
        Song(video_id="old", title="Old", artist="Artist"),
        Song(video_id="new", title="New", artist="Artist"),
    ]
    core.cursor = 0
    core.forward = MagicMock()  # type: ignore[method-assign]
    # Mid-swap: the new track is wanted, the old one is still on the player.
    core._wanted = "new"
    core._loaded_id = "old"
    core._switching = True

    core._relay_media_status(QMediaPlayer.MediaStatus.EndOfMedia)

    core.forward.assert_not_called()
    assert core.cursor == 0


def test_playback_core_duplicate_end_of_media_advances_once() -> None:
    from PyQt6.QtMultimedia import QMediaPlayer
    core = _create_core()
    core.queue = [
        Song(video_id="s1", title="Song 1", artist="Artist"),
        Song(video_id="s2", title="Song 2", artist="Artist"),
        Song(video_id="s3", title="Song 3", artist="Artist"),
    ]
    core.cursor = 0
    core.forward = MagicMock()  # type: ignore[method-assign]
    core._wanted = "s1"
    core._loaded_id = "s1"
    core._ended_id = None
    core._switching = False

    core._relay_media_status(QMediaPlayer.MediaStatus.EndOfMedia)
    core._relay_media_status(QMediaPlayer.MediaStatus.EndOfMedia)

    core.forward.assert_called_once_with(force=True)


def test_playback_core_shuffle_upcoming() -> None:
    core = _create_core()
    songs = [
        Song(video_id=f"s{i}", title=f"Song {i}", artist="Artist")
        for i in range(10)
    ]
    core.queue = list(songs)
    core.cursor = 2

    # Shuffle upcoming songs (index 3..9)
    core.shuffle_upcoming()

    assert len(core.queue) == 10
    # Current and past history remain completely unchanged
    assert core.queue[0].video_id == "s0"
    assert core.queue[1].video_id == "s1"
    assert core.queue[2].video_id == "s2"
    # Upcoming contains exactly the same set of video IDs
    assert {s.video_id for s in core.queue[3:]} == {f"s{i}" for i in range(3, 10)}


def test_playback_core_playback_rate() -> None:
    core = _create_core()
    rates: list[float] = []
    core.rate_changed.connect(lambda r: rates.append(r))

    core.set_playback_rate(1.25)
    assert core.playback_rate == 1.25
    assert rates == [1.25]

    # Clamping tests
    core.set_playback_rate(5.0)
    assert core.playback_rate == 2.5

    core.set_playback_rate(0.1)
    assert core.playback_rate == 0.5


def test_playback_core_fade_out_and_cancel() -> None:
    core = _create_core()
    core.set_volume(80)

    # Calling cancel_fade without active timer should be a safe no-op
    core.cancel_fade()
    assert core.volume() == 80


def test_playback_core_is_playing_pause_resume() -> None:
    from PyQt6.QtMultimedia import QMediaPlayer
    core = _create_core()
    core.player.playbackState = MagicMock(return_value=QMediaPlayer.PlaybackState.StoppedState)
    core.player.pause = MagicMock()
    core.player.play = MagicMock()

    # Initial stopped state
    assert not core.is_playing

    # When playing
    core.player.playbackState.return_value = QMediaPlayer.PlaybackState.PlayingState
    assert core.is_playing

    # Pause
    core.pause()
    core.player.pause.assert_called_once()

    # Resume when paused
    core.player.playbackState.return_value = QMediaPlayer.PlaybackState.PausedState
    core.resume()
    core.player.play.assert_called_once()

