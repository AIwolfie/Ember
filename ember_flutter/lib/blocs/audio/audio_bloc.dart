import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../services/python_service.dart';
import '../../services/database_service.dart';
import '../../utils/result.dart';
import 'audio_event.dart';
import 'audio_state.dart';

class AudioBloc extends Bloc<AudioEvent, AudioState> {
  late final AndroidEqualizer equalizer;
  late final AudioPlayer player;

  // ignore: deprecated_member_use
  ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  bool _isPreloading = false;

  // Storage of stream subs
  StreamSubscription? _currentIndexSub;
  StreamSubscription? _playerStateSub;

  AudioBloc() : super(const AudioState()) {
    equalizer = AndroidEqualizer();
    final pipeline = AudioPipeline(androidAudioEffects: [equalizer]);
    player = AudioPlayer(audioPipeline: pipeline);

    // Default enable equalizer dynamically when ready
    equalizer.setEnabled(true);

    on<AudioPlayQueue>(_onPlayQueue);
    on<AudioPause>((event, emit) => player.pause());
    on<AudioResume>((event, emit) => player.play());
    on<AudioStop>((event, emit) => player.stop());
    on<AudioSeekToNext>((event, emit) => player.seekToNext());
    on<AudioSeekToPrevious>(_onSeekToPrevious);
    on<AudioJumpToQueueIndex>(_onJumpToQueueIndex);

    // Internal state updates from streams
    on<AudioPlayerStateChanged>((event, emit) {
      emit(state.copyWith(playerState: event.playerState));
      if (event.playerState.processingState == ProcessingState.completed) {
        _checkAndLoadRadio();
      }
    });

    on<AudioCurrentIndexChanged>(_onCurrentIndexChanged);
    on<AudioDominantColorUpdated>((event, emit) {
      emit(state.copyWith(dominantColor: event.color));
    });

    on<AudioUpdateQueue>((event, emit) {
      emit(state.copyWith(queue: event.newQueue));
    });

    on<AudioPlayNext>(_onPlayNext);
    on<AudioAddToQueue>(_onAddToQueue);

    _currentIndexSub = player.currentIndexStream.listen((index) {
      add(AudioCurrentIndexChanged(index));
    });

    _playerStateSub = player.playerStateStream.listen((state) {
      add(AudioPlayerStateChanged(state));
    });
  }

  @override
  Future<void> close() {
    _currentIndexSub?.cancel();
    _playerStateSub?.cancel();
    player.dispose();
    return super.close();
  }

  Future<void> _updatePalette(String url) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
      );
      final dominantColor =
          palette.dominantColor?.color ?? palette.mutedColor?.color;
      if (dominantColor != null && !isClosed) {
        add(AudioDominantColorUpdated(dominantColor));
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _onPlayQueue(
    AudioPlayQueue event,
    Emitter<AudioState> emit,
  ) async {
    player.stop();
    final queue = List<Map<String, String>>.from(event.tracks);
    final offset = event.startIndex;
    final currentTrack = queue[offset];

    emit(
      state
          .copyWithNullified(dominantColor: true)
          .copyWith(
            queue: queue,
            nativeIndexOffset: offset,
            currentTrack: currentTrack,
          ),
    );

    if (currentTrack['artworkUrl'] != null &&
        currentTrack['artworkUrl']!.isNotEmpty) {
      _updatePalette(currentTrack['artworkUrl']!);
    }

    // ignore: deprecated_member_use
    _playlist = ConcatenatingAudioSource(children: []);
    await player.setAudioSource(_playlist);

    final success = await _addTrackToPlaylist(offset, queue);
    if (success) {
      player.play();
      // Preload next tracks
      _preloadNext(offset + 1); // Trigger async preloading
    }
  }

  Future<void> _onCurrentIndexChanged(
    AudioCurrentIndexChanged event,
    Emitter<AudioState> emit,
  ) async {
    final index = event.index;
    if (index != null && state.queue.isNotEmpty) {
      final queueIndex = state.nativeIndexOffset + index;
      if (queueIndex < state.queue.length) {
        final track = state.queue[queueIndex];

        emit(
          state
              .copyWithNullified(dominantColor: true)
              .copyWith(currentTrack: track),
        );

        if (track['artworkUrl'] != null && track['artworkUrl']!.isNotEmpty) {
          _updatePalette(track['artworkUrl']!);
        }

        // Ensure gapless playback by preloading the next 3 tracks instead of just 1
        _preloadNext(queueIndex + 1);
      }
    }
  }

  Future<void> _onSeekToPrevious(
    AudioSeekToPrevious event,
    Emitter<AudioState> emit,
  ) async {
    if (player.hasPrevious) {
      player.seekToPrevious();
    } else {
      if (state.nativeIndexOffset > 0) {
        add(
          AudioPlayQueue(state.queue, startIndex: state.nativeIndexOffset - 1),
        );
      }
    }
  }

  Future<void> _onJumpToQueueIndex(
    AudioJumpToQueueIndex event,
    Emitter<AudioState> emit,
  ) async {
    final targetIndex = event.targetIndex;
    if (targetIndex < 0 || targetIndex >= state.queue.length) return;

    if (targetIndex >= state.nativeIndexOffset &&
        targetIndex < (state.nativeIndexOffset + _playlist.length)) {
      final nativeIndex = targetIndex - state.nativeIndexOffset;
      await player.seek(Duration.zero, index: nativeIndex);
    } else {
      add(AudioPlayQueue(state.queue, startIndex: targetIndex));
    }
  }

  Future<void> _onPlayNext(
    AudioPlayNext event,
    Emitter<AudioState> emit,
  ) async {
    if (state.queue.isEmpty || state.currentTrack == null) {
      add(AudioPlayQueue([event.track], startIndex: 0));
      return;
    }

    final currNative = player.currentIndex ?? 0;
    final currQueue = state.nativeIndexOffset + currNative;
    final insertQueueIndex = (currQueue + 1).clamp(0, state.queue.length);
    final insertNativeIndex = (currNative + 1).clamp(0, _playlist.length);

    final newQueue = List<Map<String, String>>.from(state.queue);
    newQueue.insert(insertQueueIndex, event.track);
    emit(state.copyWith(queue: newQueue));

    final source = await _createAudioSource(event.track);
    if (source != null) {
      // ignore: deprecated_member_use
      await _playlist.insert(insertNativeIndex, source);
    }
  }

  Future<void> _onAddToQueue(
    AudioAddToQueue event,
    Emitter<AudioState> emit,
  ) async {
    if (state.queue.isEmpty || state.currentTrack == null) {
      add(AudioPlayQueue([event.track], startIndex: 0));
      return;
    }

    final newQueue = List<Map<String, String>>.from(state.queue)..add(event.track);
    emit(state.copyWith(queue: newQueue));

    // If preloading is near the end, ensure next track is queued
    _preloadNext(state.nativeIndexOffset + _playlist.length);
  }

  Future<AudioSource?> _createAudioSource(Map<String, String> track) async {
    final videoId = track['videoId'];
    if (videoId == null) return null;

    try {
      // Offline/Local check first
      final dbDownload = await DatabaseService.instance.getDownload(videoId);
      String? audioUrl;

      if (dbDownload != null) {
        audioUrl = 'file://${dbDownload['filePath']}';
      } else {
        final infoResult = await PythonService.getStreamUrl(videoId);
        if (infoResult is Success<Map<String, String?>>) {
          audioUrl = infoResult.data['url'];
        }
      }

      if (audioUrl != null && audioUrl.isNotEmpty) {
        Uri? artUri;
        if (track['artworkUrl'] != null && track['artworkUrl']!.isNotEmpty) {
          artUri = Uri.tryParse(track['artworkUrl']!);
        }
        return AudioSource.uri(
          Uri.parse(audioUrl),
          tag: MediaItem(
            id: videoId,
            album: 'Ember Music',
            artist: track['artist'] ?? 'Unknown Artist',
            title: track['title'] ?? 'Unknown',
            artUri: artUri,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fetching track url for Queue: $e");
    }
    return null;
  }

  Future<bool> _addTrackToPlaylist(
    int index,
    List<Map<String, String>> currentQueue,
  ) async {
    if (index >= currentQueue.length) return false;

    final track = currentQueue[index];
    final audioSource = await _createAudioSource(track);
    if (audioSource != null) {
      // ignore: deprecated_member_use
      await _playlist.add(audioSource);
      return true;
    }
    return false;
  }

  Future<void> _preloadNext(int nextIndexBase) async {
    if (_isPreloading) return;
    _isPreloading = true;

    // Check if we reached the end of the explicit queue dynamically.
    if (nextIndexBase >= state.queue.length) {
      await _checkAndLoadRadio();
    }

    // Aggressive multi-track prefetching (up to 3 tracks ahead)
    for (int i = 0; i < 3; i++) {
      if (isClosed) break;
      final targetIndex = nextIndexBase + i;
      if (targetIndex < state.queue.length &&
          targetIndex == (state.nativeIndexOffset + _playlist.length)) {
        await _addTrackToPlaylist(targetIndex, state.queue);
      } else {
        break;
      }
    }

    _isPreloading = false;
  }

  Future<void> _checkAndLoadRadio() async {
    if (state.queue.isEmpty) return;

    final lastTrack = state.queue.last;
    final videoId = lastTrack['videoId'];
    if (videoId == null) return;

    try {
      final similarResult = await PythonService.similar(videoId);
      if (similarResult is Success<List<Map<String, String>>>) {
        final similarTracks = similarResult.data;
        if (similarTracks.isNotEmpty) {
          final currentVideoIds = state.queue.map((e) => e['videoId']).toSet();
          final newTracks = similarTracks
              .where((t) => !currentVideoIds.contains(t['videoId']))
              .toList();

          if (newTracks.isNotEmpty) {
            final updatedQueue = List<Map<String, String>>.from(state.queue)
              ..addAll(newTracks);
            if (!isClosed) {
              _internalEmitQueueUpdate(updatedQueue);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Autoplay fetch error: $e");
    }
  }

  // A helper method if we need to emit explicitly from inside an async background op safely.
  // Note: standard BLoC says all emits must be from on<Event>, so we should properly add an event.
  // Let's refactor this slightly by just appending to the state using a custom event.
  void _internalEmitQueueUpdate(List<Map<String, String>> newQueue) {
    add(AudioUpdateQueue(newQueue));
  }
}
