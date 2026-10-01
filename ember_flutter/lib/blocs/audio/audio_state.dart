import 'dart:ui';

import 'package:equatable/equatable.dart';

class AudioState extends Equatable {
  final List<Map<String, String>> queue;
  final int nativeIndexOffset;
  final Map<String, String>? currentTrack;
  final Color? dominantColor;
  final dynamic playerState; // just_audio PlayerState
  final int? resumePositionMs;

  const AudioState({
    this.queue = const [],
    this.nativeIndexOffset = 0,
    this.currentTrack,
    this.dominantColor,
    this.playerState,
    this.resumePositionMs,
  });

  AudioState copyWith({
    List<Map<String, String>>? queue,
    int? nativeIndexOffset,
    Map<String, String>? currentTrack,
    Color? dominantColor,
    dynamic playerState,
    int? resumePositionMs,
  }) {
    return AudioState(
      queue: queue ?? this.queue,
      nativeIndexOffset: nativeIndexOffset ?? this.nativeIndexOffset,
      currentTrack: currentTrack ?? this.currentTrack, // allow null using specific pattern if needed, but here simple
      dominantColor: dominantColor ?? this.dominantColor,
      playerState: playerState ?? this.playerState,
      resumePositionMs: resumePositionMs ?? this.resumePositionMs,
    );
  }

  // Helper method for properly nullifying currentTrack/dominantColor without confusing copyWith defaults
  AudioState copyWithNullified({
    bool currentTrack = false,
    bool dominantColor = false,
  }) {
    return AudioState(
      queue: queue,
      nativeIndexOffset: nativeIndexOffset,
      playerState: playerState,
      currentTrack: currentTrack ? null : this.currentTrack,
      dominantColor: dominantColor ? null : this.dominantColor,
    );
  }

  @override
  List<Object?> get props => [
    queue,
    nativeIndexOffset,
    currentTrack,
    dominantColor,
    playerState,
    resumePositionMs,
  ];
}
