"""Signal-sequence tests for PlaybackCore, driven by a fake backend.

These assert the invariants docs/ARCHITECTURE.md states, in the order the
signals actually arrive. The bugs they cover — tracks advancing on their own,
one dead track walking the whole queue — were all ordering bugs, so they are
only reachable by replaying a sequence, not by calling one method.

No test here touches the network or a real QMediaPlayer source.
"""

from __future__ import annotations

import logging
import sys
from typing import List, Optional, Tuple
from unittest.mock import MagicMock

import pytest
from PyQt6.QtMultimedia import QMediaPlayer
from PyQt6.QtWidgets import QApplication

from ember.models import Song
from ember.player import MAX_AUTO_SKIP, PlaybackCore

# A signed URL, in shape. The extractor mints these per resolve; the tests care
# that they never reach a log record, so the host is the giveaway.
SIGNED_URL = "https://rr1---sn-fake.googlevideo.com/videoplayback?sig=abc123"


def _get_qapp() -> QApplication:
    app = QApplication.instance()
    if app is None:
        app = QApplication(sys.argv)
    return app


class FakeCache:
    """Stands in for StreamCache; records invalidations."""

    def __init__(self) -> None:
        self.invalidated: List[str] = []

    def get(self, video_id: str) -> Optional[str]:
        return None

    def put(self, video_id: str, url: str) -> None:
        return None

    def invalidate(self, video_id: str) -> None:
        self.invalidated.append(video_id)


class FakeResolver:
    """Returns a signed URL synchronously and records every resolve."""

    def __init__(self) -> None:
        self.cache = FakeCache()
        self.calls: List[str] = []
        self.result: Tuple[Optional[str], str, bool] = (SIGNED_URL, "", False)

    def resolve(self, video_id: str):
        self.calls.append(video_id)
        return self.result


def _song(video_id: str) -> Song:
    return Song(video_id=video_id, title=video_id, artist="Artist")


def _core(queue: Optional[List[Song]] = None, cursor: int = 0) -> PlaybackCore:
    """A core with both thread pools stubbed out.

    `pool.start` is stubbed rather than `_start_load`/`_start_radio` so the real
    dispatch logic runs and the assertions can see whether a job was launched.
    """
    _get_qapp()
    core = PlaybackCore(catalog=MagicMock(), resolver=FakeResolver())
    core.playback_pool.start = MagicMock()  # type: ignore[method-assign]
    core.pool.start = MagicMock()  # type: ignore[method-assign]
    # A real QMediaPlayer would try to open the fake URL over the network.
    core.player.setSource = MagicMock()  # type: ignore[method-assign]
    core.player.play = MagicMock()  # type: ignore[method-assign]
    core.player.stop = MagicMock()  # type: ignore[method-assign]
    core.player.pause = MagicMock()  # type: ignore[method-assign]
    core.player.setPosition = MagicMock()  # type: ignore[method-assign]
    if queue is not None:
        core.queue = list(queue)
        core.cursor = cursor
    return core


def _settle(core: PlaybackCore, track_id: str) -> None:
    """State a live, settled track leaves behind, ready for an EndOfMedia."""
    core._wanted = track_id
    core._loaded_id = track_id
    core._ended_id = None
    core._switching = False


# ------------------------------------------------------- play / swap hygiene
def test_play_clears_the_previous_tracks_identity() -> None:
    """A swap must not inherit _loaded_id or a wedged _switching from the old track."""
    core = _core([_song("a")])
    core._loaded_id = "old"
    core._ended_id = "old"
    core._failed_id = "old"

    core.play(core.queue[0])

    assert core._wanted == "a"
    assert core._loaded_id is None
    assert core._ended_id is None
    assert core._failed_id is None
    assert core._switching is True  # the new source is not live yet


def test_play_does_not_discard_a_pending_prefetch() -> None:
    """The prefetch describes the *next* track, not the one being replaced."""
    core = _core([_song("a"), _song("b")])
    core._prefetched = ("b", SIGNED_URL)

    core.play(core.queue[0])

    assert core._prefetched == ("b", SIGNED_URL)


def test_prefetch_hit_skips_the_load_job() -> None:
    """A ready prefetch is used directly — that is the point of prefetching."""
    core = _core([_song("a")])
    core._wanted = "a"  # _on_stream_ready drops results for a track we moved off
    core._prefetched = ("a", SIGNED_URL)

    core._start_load(core.queue[0])

    core.playback_pool.start.assert_not_called()
    assert core.queue[0].stream_url == SIGNED_URL


def test_prefetch_still_resolving_does_not_produce_an_empty_url() -> None:
    """A prefetch slot of (id, None) means 'in flight', not 'here is the URL'."""
    core = _core([_song("a")])
    core._prefetched = ("a", None)

    core._start_load(core.queue[0])

    core.playback_pool.start.assert_called_once()
    assert core.queue[0].stream_url is None or core.queue[0].stream_url != ""


# ------------------------------------------------------------ end of media
def test_end_of_media_from_the_outgoing_source_does_not_advance() -> None:
    """Qt re-emits EndOfMedia for the track being replaced; acting on it skipped tracks."""
    core = _core([_song("old"), _song("new")], cursor=0)
    core.forward = MagicMock()  # type: ignore[method-assign]
    core._wanted = "new"
    core._loaded_id = "old"
    core._switching = True

    core._relay_media_status(QMediaPlayer.MediaStatus.EndOfMedia)

    core.forward.assert_not_called()
    assert core.cursor == 0


def test_duplicate_end_of_media_advances_only_once() -> None:
    core = _core([_song("s1"), _song("s2")], cursor=0)
    core.forward = MagicMock()  # type: ignore[method-assign]
    _settle(core, "s1")

    core._relay_media_status(QMediaPlayer.MediaStatus.EndOfMedia)
    core._relay_media_status(QMediaPlayer.MediaStatus.EndOfMedia)

    core.forward.assert_called_once_with(force=True)


def test_going_live_settles_the_switch_and_prefetches() -> None:
    """LoadedMedia is the first point stale status cannot arrive."""
    core = _core([_song("a"), _song("b")], cursor=0)
    core._wanted = "a"
    core._loaded_id = "a"
    core._switching = True

    core._relay_media_status(QMediaPlayer.MediaStatus.LoadedMedia)

    assert core._switching is False
    assert core._prefetched is not None
    assert core._prefetched[0] == "b"


# -------------------------------------------------------------- dead tracks
def test_forward_walks_past_a_permanently_dead_track() -> None:
    core = _core([_song("a"), _song("b"), _song("c")], cursor=0)
    core._dead_tracks = {"b"}
    core.play_at = MagicMock()  # type: ignore[method-assign]

    core.forward(force=True)

    core.play_at.assert_called_once_with(2)


def test_forward_falls_through_to_the_radio_when_everything_ahead_is_dead() -> None:
    core = _core([_song("a"), _song("b")], cursor=0)
    core._dead_tracks = {"b"}
    core._start_radio = MagicMock()  # type: ignore[method-assign]

    core.forward(force=True)

    assert core._extending is True
    assert core._advance_after_extend is True


def test_forward_wrap_skips_dead_tracks_at_the_head() -> None:
    """Wrapping into 'all' lands on the first playable track, not the dead head."""
    core = _core([_song("a"), _song("b")], cursor=1)
    core._dead_tracks = {"a"}
    core.set_repeat_mode("all")
    core.play_at = MagicMock()  # type: ignore[method-assign]

    core.forward(force=True)

    core.play_at.assert_called_once_with(1)


def test_forward_with_everything_dead_falls_through_to_the_radio() -> None:
    """A fully dead queue must not wrap onto itself — go find new tracks."""
    core = _core([_song("a"), _song("b")], cursor=1)
    core._dead_tracks = {"a", "b"}
    core.set_repeat_mode("all")
    core.play_at = MagicMock()  # type: ignore[method-assign]
    core._start_radio = MagicMock()  # type: ignore[method-assign]

    core.forward(force=True)

    core.play_at.assert_not_called()
    assert core._extending is True


# ---------------------------------------------------------------- watchdog
def test_switch_watchdog_fails_a_source_that_never_opens() -> None:
    core = _core([_song("a"), _song("b")], cursor=0)
    core.forward = MagicMock()  # type: ignore[method-assign]
    core._switching = True

    core._on_switch_timeout()

    assert core._switching is False
    assert core._loaded_id is None
    core.forward.assert_called_once_with(force=True)


def test_switch_watchdog_is_a_noop_once_the_source_went_live() -> None:
    core = _core([_song("a"), _song("b")], cursor=0)
    core.forward = MagicMock()  # type: ignore[method-assign]
    core._switching = False

    core._on_switch_timeout()

    core.forward.assert_not_called()


# ------------------------------------------------------------------- errors
def test_error_refreshes_the_stream_exactly_once() -> None:
    """A 403 on an expired URL means the track is fine — re-resolve once."""
    core = _core([_song("a")], cursor=0)
    core._wanted = "a"
    core._loaded_id = "a"

    core._relay_error(QMediaPlayer.Error.ResourceError, "403 Forbidden")

    assert core._retried_tracks == {"a"}
    assert core.resolver.cache.invalidated == ["a"]
    assert core._switching is True  # a fresh load is in flight


def test_second_error_on_the_same_track_skips_instead_of_refreshing() -> None:
    core = _core([_song("a"), _song("b")], cursor=0)
    core._wanted = "a"
    core._loaded_id = "a"
    core._retried_tracks = {"a"}
    core.forward = MagicMock()  # type: ignore[method-assign]

    core._relay_error(QMediaPlayer.Error.ResourceError, "403 Forbidden")

    assert core.resolver.cache.invalidated == []
    core.forward.assert_called_once_with(force=True)


def test_error_for_a_replaced_source_is_ignored() -> None:
    core = _core([_song("a"), _song("b")], cursor=0)
    core._wanted = "b"
    core._loaded_id = "a"  # the outgoing track, mid-swap
    core.forward = MagicMock()  # type: ignore[method-assign]

    core._relay_error(QMediaPlayer.Error.ResourceError, "noise")

    core.forward.assert_not_called()
    assert core._retried_tracks == set()


def test_exhausted_skip_budget_leaves_failed_id_marked() -> None:
    """The whole point of the budget is that the same error is not re-handled."""
    core = _core([_song("a")], cursor=0)
    core._wanted = "a"
    core._loaded_id = "a"
    core._retried_tracks = {"a"}
    core._error_streak = MAX_AUTO_SKIP

    core._relay_error(QMediaPlayer.Error.ResourceError, "403 Forbidden")

    assert core._failed_id == "a"
    assert core._error_streak == 0


# ----------------------------------------------------------- resolve failures
def test_permanent_resolve_failure_is_remembered() -> None:
    core = _core([_song("a"), _song("b")], cursor=0)
    core._wanted = "a"
    core.forward = MagicMock()  # type: ignore[method-assign]

    core._on_stream_failed(_song("a"), "age-restricted", True)

    assert "a" in core._dead_tracks
    core.forward.assert_called_once_with(force=True)


def test_transient_resolve_failure_is_not_remembered() -> None:
    """A network blip must not blacklist a track for the rest of the session."""
    core = _core([_song("a"), _song("b")], cursor=0)
    core._wanted = "a"
    core.forward = MagicMock()  # type: ignore[method-assign]

    core._on_stream_failed(_song("a"), "connection reset", False)

    assert core._dead_tracks == set()


# ------------------------------------------------------------------ the UI
def test_playing_changed_is_not_flickered_during_a_swap() -> None:
    """Relaying our own stop() as 'paused' blinked the disc and the play icon."""
    core = _core([_song("a"), _song("b")], cursor=0)
    events: List[bool] = []
    core.playing_changed.connect(events.append)
    core._switching = True

    core._relay_state(QMediaPlayer.PlaybackState.StoppedState)

    assert events == []


def test_playing_changed_still_relays_a_real_stop() -> None:
    core = _core([_song("a")], cursor=0)
    events: List[bool] = []
    core.playing_changed.connect(events.append)
    core._switching = False

    core._relay_state(QMediaPlayer.PlaybackState.StoppedState)

    assert events == [False]


# ------------------------------------------------------------------- logging
def test_signed_url_never_reaches_a_log_record(caplog: pytest.LogCaptureFixture) -> None:
    """Signed URLs are working credentials for their lifetime; they stay out of logs.

    The backend embeds the failing URL in its own error string, so this asserts
    on the *message* path as well as on anything the core logs itself.
    """
    caplog.set_level(logging.DEBUG)

    core = _core([_song("a"), _song("b")], cursor=0)
    core.play(core.queue[0])
    core._on_stream_ready(core.queue[0], SIGNED_URL)
    _settle(core, "a")
    core._relay_media_status(QMediaPlayer.MediaStatus.EndOfMedia)
    core._relay_error(QMediaPlayer.Error.ResourceError, f"failed on {SIGNED_URL}")
    core._on_stream_failed(_song("a"), f"403 on {SIGNED_URL}", True)

    assert "googlevideo.com" not in caplog.text


def test_every_lifecycle_line_carries_the_generation(caplog: pytest.LogCaptureFixture) -> None:
    """A stale event has to be visible by eye, not inferred from timestamps."""
    caplog.set_level(logging.INFO, logger="ember.playback")

    core = _core([_song("a")])
    core.play(core.queue[0])
    core.play(core.queue[0])

    lines = [r.getMessage() for r in caplog.records if r.name == "ember.playback"]
    assert lines, "the lifecycle logger produced nothing"
    assert all("gen=" in line for line in lines)
    assert "gen=2" in lines[-1]