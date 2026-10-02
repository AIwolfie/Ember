import json
import logging
import math
from collections import defaultdict
from typing import Any, Dict, List

log = logging.getLogger("recommendation_engine")

def build_cooccurrence_matrix(history: List[Dict[str, Any]], session_threshold_ms: int = 30 * 60 * 1000) -> Dict[str, Dict[str, float]]:
    """
    Builds an item-item co-occurrence matrix from play history based on sessions.
    Args:
        history: List of play history track definitions containing 'videoId', 'artist', 'timestamp'
        session_threshold_ms: Time difference in ms to consider tracks as part of the same session
    Returns:
        JSON serializable dict mapping artist to related artists and their affinity scores.
    """
    if not history:
        return {}

    # Sort history by timestamp just in case
    def get_ts(x: Dict[str, Any]) -> int:
        try:
            return int(x.get("timestamp", 0))
        except (ValueError, TypeError):
            return 0

    sorted_history = sorted(history, key=get_ts)
    
    sessions = []
    current_session = []
    last_ts = 0

    for track in sorted_history:
        ts = get_ts(track)
        artist = track.get("artist")
        if not artist or artist.lower() == "unknown artist":
            continue

        if not current_session:
            current_session.append(artist)
            last_ts = ts
        else:
            if ts - last_ts <= session_threshold_ms:
                current_session.append(artist)
            else:
                sessions.append(current_session)
                current_session = [artist]
            last_ts = ts

    if current_session:
        sessions.append(current_session)

    # Build co-occurrence map
    co_occurrence = defaultdict(lambda: defaultdict(int))
    artist_counts = defaultdict(int)

    for session in sessions:
        # Unique artists in this session to avoid self-loop bias inside a single long playlist
        unique_artists = list(set(session))
        for i in range(len(unique_artists)):
            artist_a = unique_artists[i]
            artist_counts[artist_a] += 1
            for j in range(i + 1, len(unique_artists)):
                artist_b = unique_artists[j]
                co_occurrence[artist_a][artist_b] += 1
                co_occurrence[artist_b][artist_a] += 1

    # Normalize into a graph with similarities based on Jaccard-like index
    affinity_graph = {}
    for artist_a, related in co_occurrence.items():
        edges = {}
        for artist_b, count in related.items():
            # Standard association rule metric: count / (freq(a) + freq(b) - count)
            # We scale it up so it's a usable integer/float multiplier for Dart
            score = (count / float(artist_counts[artist_a] + artist_counts[artist_b] - count)) * 100.0
            if score > 0:
                edges[artist_b] = round(score, 2)
        if edges:
            affinity_graph[artist_a] = edges

    return affinity_graph

def analyze_history(history_json: str) -> str:
    """
    Parses the JSON play history string from Dart and builds the graph.
    Returns stringified JSON.
    """
    try:
        data = json.loads(history_json)
        if not isinstance(data, list):
            return "{}"
        graph = build_cooccurrence_matrix(data)
        return json.dumps(graph)
    except Exception as exc:
        log.error("Failed to build affinity graph: %s", exc)
        return "{}"
