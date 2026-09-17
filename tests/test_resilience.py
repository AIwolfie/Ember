"""Tests for retry backoff resilience in catalog and stream."""

from __future__ import annotations

import pytest

from ember.catalog import _with_retry, CatalogSource
from ember.models import Song


def test_retry_success_on_first_attempt() -> None:
    calls = 0

    def mock_fn() -> str:
        nonlocal calls
        calls += 1
        return "success"

    result = _with_retry(mock_fn, max_attempts=3, base_delay=0.01)
    assert result == "success"
    assert calls == 1


def test_retry_success_after_failure() -> None:
    calls = 0

    def fail_twice() -> str:
        nonlocal calls
        calls += 1
        if calls < 3:
            raise ConnectionError("temporary network drop")
        return "recovered"

    result = _with_retry(fail_twice, max_attempts=3, base_delay=0.01)
    assert result == "recovered"
    assert calls == 3


def test_retry_eventual_failure() -> None:
    def always_fail() -> None:
        raise TimeoutError("connection timed out")

    with pytest.raises(TimeoutError):
        _with_retry(always_fail, max_attempts=2, base_delay=0.01)


def test_catalog_build_parser() -> None:
    valid_raw = {
        "videoId": "vid_abc",
        "title": "Song Title",
        "artists": [{"name": "Artist 1"}, {"name": "Artist 2"}],
        "duration": "3:45",
        "thumbnails": [
            {"url": "http://small.jpg", "width": 100, "height": 100},
            {"url": "http://large.jpg", "width": 500, "height": 500},
        ],
    }
    song = CatalogSource._build(valid_raw)
    assert song is not None
    assert song.video_id == "vid_abc"
    assert song.artist == "Artist 1, Artist 2"
    assert song.artwork_url == "http://large.jpg"


def test_catalog_build_parser_malformed_thumbnails() -> None:
    malformed_raw = {
        "videoId": "vid_xyz",
        "title": "Malformed Thumbs",
        "artists": [{"name": "Artist"}],
        "thumbnails": [
            {"url": "http://bad1.jpg", "width": "not_an_int", "height": "bad"},
            {"url": "http://bad2.jpg", "width": None, "height": None},
            {"url": "http://good.jpg", "width": 300, "height": 300},
        ],
    }
    song = CatalogSource._build(malformed_raw)
    assert song is not None
    assert song.video_id == "vid_xyz"
    assert song.artwork_url == "http://good.jpg"


def test_art_job_signals() -> None:
    from ember.jobs import ArtJob

    job = ArtJob("vid_test", "http://example.com/fake.jpg")
    assert hasattr(job.signals, "arrived")
    assert hasattr(job.signals, "failed")


def test_job_cancellation() -> None:
    from ember.jobs import CancellableJob, SearchJob
    from unittest.mock import MagicMock

    job = CancellableJob()
    assert not job.is_cancelled
    job.cancel()
    assert job.is_cancelled

    mock_catalog = MagicMock()
    search_job = SearchJob(mock_catalog, "test query")
    search_job.cancel()
    search_job.run()
    # When cancelled, search_job must exit without calling catalog.search
    mock_catalog.search.assert_not_called()


def test_stream_pick_url_filters_dash_and_frag() -> None:
    from ember.stream import StreamResolver

    info = {
        "formats": [
            {"acodec": "mp4a.40.2", "ext": "m4a", "url": "https://dash.audio", "protocol": "http_dash_segments", "abr": 160},
            {"acodec": "opus", "ext": "webm", "url": "https://frag.audio", "protocol": "m3u8_native", "abr": 160},
            {"acodec": "mp4a.40.2", "ext": "m4a", "url": "https://clean.audio/stream.m4a", "protocol": "https", "abr": 128},
        ]
    }
    url = StreamResolver._pick_url(info)
    assert url == "https://clean.audio/stream.m4a"


def test_catalog_unescapes_html_and_formats_numeric_duration() -> None:
    from ember.catalog import CatalogSource

    raw = {
        "videoId": "test_123",
        "title": "Rock &amp; Roll &#39;26",
        "author": "Simon &amp; Garfunkel",
        "duration": 215,  # 3:35
    }
    song = CatalogSource._build(raw)
    assert song is not None
    assert song.title == "Rock & Roll '26"
    assert song.artist == "Simon & Garfunkel"
    assert song.duration == "3:35"

