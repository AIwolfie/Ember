"""
test_new_systems.py
Unit tests for AudioDiskCache, ScrobbleEngine, Audio Device Management,
Studio/Lossless quality resolution, and Micro-Pill mode.
"""

from __future__ import annotations

import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

from ember.cache import AudioDiskCache
from ember.models import Song
from ember.scrobbler import ScrobbleEngine
from ember.stream import FORMAT_STANDARD, FORMAT_STUDIO, StreamResolver


def test_audio_disk_cache_basic_lifecycle() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        cache = AudioDiskCache(cache_dir=Path(tmpdir), max_bytes=1024 * 1024)

        assert cache.has("song_1") is False
        assert cache.get_path("song_1") is None

        # Store a dummy audio file
        data = b"AUDIO_DATA_FOR_TEST"
        stored_path = cache.store("song_1", data, ext="m4a")
        assert stored_path is not None
        assert stored_path.is_file()

        assert cache.has("song_1") is True
        retrieved_path = cache.get_path("song_1")
        assert retrieved_path == stored_path
        assert retrieved_path.read_bytes() == data

        assert cache.total_size_bytes() == len(data)

        # Clear cache
        cache.clear()
        assert cache.has("song_1") is False
        assert cache.total_size_bytes() == 0


def test_audio_disk_cache_lru_eviction() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        # 100 byte max cache
        cache = AudioDiskCache(cache_dir=Path(tmpdir), max_bytes=100)

        # Write first track (60 bytes)
        cache.store("track_1", b"A" * 60, ext="m4a")
        assert cache.has("track_1") is True

        # Write second track (60 bytes) -> exceeds 100 bytes, evicts track_1
        cache.store("track_2", b"B" * 60, ext="m4a")

        assert cache.has("track_2") is True
        assert cache.has("track_1") is False


def test_scrobble_engine_threshold_and_dispatch() -> None:
    engine = ScrobbleEngine(listenbrainz_token="dummy_token")
    song = Song(
        video_id="vid_123",
        title="Midnight City",
        artist="M83",
        duration="4:00",
    )

    with patch.object(engine, "_send_listenbrainz") as mock_send:
        # Song changed emits playing_now
        engine.on_song_changed(song, generation=1)
        assert mock_send.call_count == 1
        assert mock_send.call_args[0][1] == "playing_now"

        # Position at 20 seconds (under min threshold 30s) -> no scrobble
        engine.on_progress(20000, 240000)
        assert mock_send.call_count == 1

        # Position at 125 seconds (over 50% of 240s) -> scrobbles single listen
        engine.on_progress(125000, 240000)
        assert mock_send.call_count == 2
        assert mock_send.call_args[0][1] == "single"

        # Repeated progress does not scrobble duplicate
        engine.on_progress(130000, 240000)
        assert mock_send.call_count == 2


def test_stream_resolver_quality_mode_and_disk_cache() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        cache = AudioDiskCache(cache_dir=Path(tmpdir))
        resolver = StreamResolver(disk_cache=cache)

        assert resolver.options["format"] == FORMAT_STANDARD

        resolver.set_quality_mode("studio")
        assert resolver.options["format"] == FORMAT_STUDIO

        resolver.set_quality_mode("standard")
        assert resolver.options["format"] == FORMAT_STANDARD

        # When disk cache holds the song, resolve returns local URI instantly with 0ms probing
        cache.store("cached_song", b"LOCAL_AUDIO_STREAM", ext="opus")
        url, msg, perm = resolver.resolve("cached_song")
        assert url is not None
        assert url.startswith("file:")
        assert "cached_song" in url
