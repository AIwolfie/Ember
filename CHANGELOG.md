# Changelog

## Unreleased

### Fixed

- **Tracks no longer skip or restart on their own.** `EndOfMedia` is emitted by
  Qt for the *outgoing* source during a swap as well as for a genuinely finished
  track. The end-of-track handler now matches on track identity (`_loaded_id`
  vs `_wanted`) instead of a timing flag, and `_ended_id` makes a duplicate
  `EndOfMedia` a no-op — the cursor advances at most once per real track end.
- Media player errors are matched on track identity rather than the source URL.
  Every resolve mints a new signed URL, so the old URL comparison never matched,
  the guard failed open, and the backend walked the queue retrying one dead
  track.
- A `setSource` that never opens no longer spins forever: an 18s watchdog fails
  the load and moves on.
- **Auto-advance no longer steps onto a track that already failed permanently.**
  `forward()` walks past ids in `_dead_tracks` instead of burning the skip budget
  re-resolving an age-gated or deleted video, which is what made one dead track
  look like a runaway player.
- `play()` clears the previous track's identity through the shared
  `_reset_source_state()`, so a swap can no longer inherit a stale `_loaded_id`
  or a `_switching` flag left wedged by the track it replaced.
- **Signed stream URLs no longer reach the log.** The backend hands the failing
  URL back inside its own error string — on a `ResourceError` that string *is*
  the URL — so the core was writing a live `googlevideo.com` credential into both
  the `ember.playback` lifecycle line and the `ember.player` warning. Every
  message logged from a backend error is now passed through `_redact()`, which
  strips the URL. The new tests caught this one.

### Added

- **Next-track prefetch.** The following track's stream is resolved while the
  current one plays, so transitions no longer pay full resolution latency.
- **Resolved-stream cache** (45 min TTL, invalidated on rejection) so replaying
  or going back to a track is instant.
- **`ember.playback` lifecycle log** with a generation counter on every event.
- **`python -m ember --doctor`** prints Python, OS, Qt, yt-dlp (with age), audio
  format and log path.
- Permanent extractor failures (age gate, members-only, deleted) are now
  distinguished from transient ones: permanent failures skip and are remembered,
  transient failures get one fresh resolve.
- `docs/ARCHITECTURE.md` with the signal-flow diagram and the state-machine
  invariants.
- Signal-sequence tests driven by a fake backend
  (`tests/test_playback_sequences.py`).

### Changed

- `yt-dlp` is pinned to a range with a startup age warning; an unpinned install
  meant "worked yesterday" was not a stable state.
- `StreamResolver.resolve()` reports failure cause alongside the URL;
  `stream_url()` remains as a thin wrapper.
- `_on_stream_failed`, `_relay_error` and `play` share one
  `_reset_source_state()` instead of hand-clearing overlapping field subsets.
- `playing_changed` is no longer emitted for the outgoing source's transient
  `StoppedState` during a swap, which flickered the disc and the play icon.
- `_prefetched` is no longer cleared by `_reset_source_state()`: it describes a
  *future* track, and dropping it threw away exactly the resolution prefetching
  exists to provide.