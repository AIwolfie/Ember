# Ember architecture

One picture of the chain, so the next "why did the track change" takes five
minutes instead of an hour.

## Signal flow

```
user action (panel.py)
        |
        v
PlaybackCore.play(song)                      ember/player.py
        |  bumps _generation, sets _wanted, arms the switch watchdog
        |
        +--> LoadJob  (playback_pool, 2 threads)   ember/jobs.py
        |         |
        |         v
        |    StreamResolver.resolve(video_id)      ember/stream.py
        |         |  cache hit -> url
        |         |  miss -> yt-dlp extract -> cache.put
        |         v
        |    ready(song, url) | failed(song, msg, permanent)
        |
        +--> RadioJob (pool, 6 threads) -> CatalogSource.similar -> queue grows

PlaybackCore._on_stream_ready(song, url)
        |
        v
QMediaPlayer.setSource(url)
        |
        v
mediaStatusChanged / playbackStateChanged / errorOccurred
        |
        v
PlaybackCore._relay_media_status / _relay_state / _relay_error
        |  identity checks against _wanted / _loaded_id / _ended_id
        v
pyqtSignals: song_changed, cursor_changed, queue_changed, playing_changed,
             progress_changed, length_changed, loading_changed, notice
        |
        v
FloatingPanel (ember/panel.py) repaints
```

## The playback state machine

Six fields decide whether a status signal is acted on. Most transitions go
through `_reset_source_state`, `_arm_switch_watchdog` and `_settle_switch`, so
the overlapping subsets cannot drift apart; the two deliberate exceptions are
`_on_stream_ready` (which claims the source and clears `_failed_id`/`_ended_id`
in one step) and `_on_switch_timeout` (which has to clear `_switching` before it
can re-enter `forward()`).

| field          | meaning                                                        |
| -------------- | -------------------------------------------------------------- |
| `_wanted`      | track the user is on now; every slot guards against it          |
| `_loaded_id`   | track currently handed to the backend                           |
| `_ended_id`    | track whose `EndOfMedia` we already acted on                    |
| `_failed_id`   | track whose failure we already handled                          |
| `_switching`   | a `setSource` is in flight, so status is untrustworthy          |
| `_error_streak`| consecutive failures, capped by `MAX_AUTO_SKIP`                 |

Invariants the tests assert:

1. The cursor advances **at most once per `EndOfMedia`** — `_ended_id` is what
   enforces it, because Qt re-emits `EndOfMedia` for outgoing sources.
2. `_switching` is **never left True after a terminal event**: the source going
   live, the skip budget being spent, or the `SWITCH_TIMEOUT_MS` watchdog firing.
3. `_loaded_id` is either `None` or `_wanted` once the swap has settled.

`_switching` is a timing flag and timing flags lie; the identity comparisons are
the real guard. `_switching` exists only to suppress the burst of status the
backend emits between `setSource` and the new source being live.

## Lifecycle logging

Every lifecycle event goes to the `ember.playback` logger tagged with
`gen=<n>`, bumped once per `play()`. A status carrying `gen=7` arriving after
`gen=9` started is a stale event, and it is visible by eye in the log.

Signed stream URLs are never logged — they are working credentials for their
lifetime. `tests/test_playback_sequences.py` asserts no `googlevideo.com` URL
ever reaches a log record.

`python -m ember --doctor` prints the versions that decide whether playback
works at all.