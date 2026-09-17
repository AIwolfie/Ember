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


def test_playlist_url_detection() -> None:
    from ember.importer import is_playlist_url, extract_spotify_id

    assert is_playlist_url("https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M") is True
    assert is_playlist_url("https://open.spotify.com/album/4aawyAB9vmqN3uQ7FjRGTy") is True
    assert is_playlist_url("https://www.youtube.com/playlist?list=PLrAl6t_qY9k0a2bM3N") is True
    assert is_playlist_url("https://music.youtube.com/playlist?list=RDCLAK5uy_k") is True
    assert is_playlist_url("radiohead karma police") is False
    assert is_playlist_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ") is False

    kind, id_val = extract_spotify_id("https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M")
    assert kind == "playlist"
    assert id_val == "37i9dQZF1DXcBWIGoYBM5M"


def test_spotify_fetch_tracks_mocked() -> None:
    from unittest.mock import MagicMock, patch
    from ember.importer import fetch_spotify_tracks

    mock_html = """
    <html><head><script id="__NEXT_DATA__" type="application/json">
    {"props": {"pageProps": {"state": {"data": {"entity": {"trackList": [
        {"title": "Track 1", "subtitle": "Artist 1"},
        {"title": "Track 2", "subtitle": "Artist 2"}
    ]}}}}}}
    </script></head></html>
    """
    with patch("requests.get") as mock_get:
        resp = MagicMock()
        resp.status_code = 200
        resp.text = mock_html
        mock_get.return_value = resp

        tracks = fetch_spotify_tracks("https://open.spotify.com/playlist/dummy")
        assert len(tracks) == 2
        assert tracks[0]["title"] == "Track 1"
        assert tracks[1]["subtitle"] == "Artist 2"


def test_smtc_graceful_call() -> None:
    from ember.smtc import WindowsMediaControls
    smtc = WindowsMediaControls()
    # Ensure all methods run gracefully without throwing exceptions
    smtc.update_metadata("Song", "Artist", "")
    smtc.set_playback_status(True)
    smtc.set_playback_status(False)
    smtc.close()


def test_discord_presence_graceful_call() -> None:
    from ember.discord_rpc import DiscordPresence
    rpc = DiscordPresence()
    assert rpc.client_id
    rpc.update("Track", "Artist", 0, 180000, True)
    rpc.clear()
    rpc.close()


