"""Tests for LyricsJob and CatalogSource.lyrics."""

from __future__ import annotations

from unittest.mock import MagicMock, patch
from ember.catalog import CatalogSource
from ember.jobs import LyricsJob


def test_lyrics_job_signals() -> None:
    catalog = MagicMock(spec=CatalogSource)
    job = LyricsJob(catalog, "test_vid")
    assert hasattr(job.signals, "done")
    assert hasattr(job.signals, "ready")
    assert hasattr(job.signals, "lyrics_ready")
    assert hasattr(job.signals, "failed")
    assert hasattr(job.signals, "lyrics_failed")


def test_lyrics_job_success_emission() -> None:
    catalog = MagicMock(spec=CatalogSource)
    catalog.lyrics.return_value = "Hello from the other side\nI must have called a thousand times"

    done_events: list[tuple[str, str]] = []
    ready_events: list[tuple[str, str, str]] = []
    failed_events: list[tuple[str, str]] = []

    job = LyricsJob(catalog, "test_vid")
    job.signals.done.connect(lambda vid, text: done_events.append((vid, text)))
    job.signals.lyrics_ready.connect(lambda vid, text, src: ready_events.append((vid, text, src)))
    job.signals.failed.connect(lambda vid, err: failed_events.append((vid, err)))

    job.run()

    assert len(done_events) == 1
    assert done_events[0][0] == "test_vid"
    assert "Hello from the other side" in done_events[0][1]

    assert len(ready_events) == 1
    assert ready_events[0][0] == "test_vid"
    assert "Hello from the other side" in ready_events[0][1]
    assert len(failed_events) == 0


def test_lyrics_job_none_fallback_emission() -> None:
    catalog = MagicMock(spec=CatalogSource)
    catalog.lyrics.return_value = None

    done_events: list[tuple[str, str]] = []
    failed_events: list[tuple[str, str]] = []
    lyrics_failed_events: list[tuple[str, str]] = []

    job = LyricsJob(catalog, "test_vid_instrumental")
    job.signals.done.connect(lambda vid, text: done_events.append((vid, text)))
    job.signals.failed.connect(lambda vid, err: failed_events.append((vid, err)))
    job.signals.lyrics_failed.connect(lambda vid, err: lyrics_failed_events.append((vid, err)))

    job.run()

    assert len(done_events) == 0
    assert len(failed_events) == 1
    assert failed_events[0][0] == "test_vid_instrumental"
    assert "No lyrics found" in failed_events[0][1]
    assert len(lyrics_failed_events) == 1
    assert lyrics_failed_events[0][0] == "test_vid_instrumental"


def test_clean_title() -> None:
    from ember.lyrics import clean_title
    assert clean_title("Coldplay - Yellow (Official Video)") == "Coldplay - Yellow"
    assert clean_title("Eminem - Stan [Audio]") == "Eminem - Stan"
    assert clean_title("Song Name feat. Someone (HD)") == "Song Name"
    assert clean_title("Simple Song") == "Simple Song"


def test_parse_lrc_and_find_active_index() -> None:
    from ember.lyrics import find_active_index, parse_lrc

    raw_lrc = """
    [00:05.50]Look at the stars
    [00:11.20]Look how they shine for you
    [00:18.00]And everything you do
    """
    parsed = parse_lrc(raw_lrc)
    assert len(parsed) == 3
    assert parsed[0] == (5500, "Look at the stars")
    assert parsed[1] == (11200, "Look how they shine for you")
    assert parsed[2] == (18000, "And everything you do")

    # Before first line
    assert find_active_index(parsed, 1000) == -1
    # Right on first line
    assert find_active_index(parsed, 5500) == 0
    # Between first and second line
    assert find_active_index(parsed, 8000) == 0
    # On second line
    assert find_active_index(parsed, 11200) == 1
    # After last line
    assert find_active_index(parsed, 25000) == 2


def test_lyrics_job_lrclib_priority() -> None:
    catalog = MagicMock(spec=CatalogSource)
    # Even if catalog returns nothing, LRCLIB hit should succeed
    catalog.lyrics.return_value = None

    done_events: list[tuple[str, str]] = []
    ready_events: list[tuple[str, str, str]] = []

    job = LyricsJob(catalog, "test_vid", title="Yellow", artist="Coldplay", duration_sec=269)
    job.signals.done.connect(lambda vid, text: done_events.append((vid, text)))
    job.signals.lyrics_ready.connect(lambda vid, text, src: ready_events.append((vid, text, src)))

    mock_synced = "[00:10.00]Look at the stars"
    with patch("ember.lyrics.fetch_lrclib", return_value=(mock_synced, None)):
        job.run()

    assert len(done_events) == 1
    assert done_events[0][0] == "test_vid"
    assert done_events[0][1] == mock_synced

    assert len(ready_events) == 1
    assert ready_events[0][2] == "LRCLIB"
