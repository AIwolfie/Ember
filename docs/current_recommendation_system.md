# Ember Current Recommendation System

The Ember app currently utilizes a hybrid approach for its music recommendations, combining external collaborative filtering via YouTube Music's API with local heuristic-based scoring.

## Architecture

The recommendation engine spans both the Dart backend services (`RecommenderService`) and Python microservices (`PythonService` communicating with `catalog.py`).

### Stage 1: Candidate Generation (Retrieval)
When a song finishes or the user skips tracks, the system must choose a new track to queue. It compiles a "candidate pool" from two primary sources:

1.  **YT Music Similar Graph:**
    *   The app sends the `videoId` of the currently playing track to the Python backend (`android_api.py` -> `catalog.py`).
    *   The Python backend fetches the "watch playlist" from YouTube Music, effectively acting as an external collaborative filtering system that knows what other users listened to alongside that track.
2.  **Local Favorites:**
    *   To inject user preference directly, the system randomly samples up to 5 tracks from the user's local database of favorite songs.

### Stage 2: Ranking Pipeline
Once candidates are pooled, they pass through a lightweight, synchronous ranking algorithm running in Dart:

1.  **Base Scoring:**
    *   Songs are scored initially based on their order in the candidate list. Higher-ranked candidates from YT Music start with a slightly higher base score (`100.0 - (index * 1.5)`).
    *   Tracks that appear in both candidates (e.g., in favorites and similar) get a `+1.0` fusion bonus.
2.  **Artist Affinity Multiplier:**
    *   The most significant step is personalization based on the `_artistAffinityCache`.
    *   The app dynamically calculates an "affinity score" for each artist based on:
        *   **Play History:** `+1` point every time a song by that artist is played.
        *   **Favorites:** `+3` points for each favorited song by that artist.
        *   **Cold Start:** `+10` points for artists selected during the initial app onboarding.
    *   If a candidate track belongs to an artist with a recorded affinity, its final score significantly boosts (`score += affinity * 2.0`).
3.  **Fatigue Penalty:**
    *   To prevent endless loops, the engine checks the 20 most recently played `videoId`s. If a candidate was recently played, it receives a `-200.0` penalty, ensuring it sinks to the bottom of the recommendations.

### Limitations of Current Model
- Lacks semantic understanding of music (like tempo, genre, or mood).
- Heavily relies on internet connectivity for the initial "similar graph" generation.
- The scoring model only uses artists, completely ignoring genres or collaborative clustering based on the user's explicit listening sessions locally.
