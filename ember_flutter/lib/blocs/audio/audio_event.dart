import 'package:equatable/equatable.dart';

abstract class AudioEvent extends Equatable {
  const AudioEvent();

  @override
  List<Object?> get props => [];
}

class AudioPlayQueue extends AudioEvent {
  final List<Map<String, String>> tracks;
  final int startIndex;
  
  const AudioPlayQueue(this.tracks, {this.startIndex = 0});

  @override
  List<Object?> get props => [tracks, startIndex];
}

class AudioPause extends AudioEvent {}

class AudioResume extends AudioEvent {}

class AudioStop extends AudioEvent {}

class AudioSeekToNext extends AudioEvent {}

class AudioSeekToPrevious extends AudioEvent {}

class AudioJumpToQueueIndex extends AudioEvent {
  final int targetIndex;
  const AudioJumpToQueueIndex(this.targetIndex);

  @override
  List<Object?> get props => [targetIndex];
}

class AudioPlayerStateChanged extends AudioEvent {
  final dynamic playerState; // just_audio PlayerState
  const AudioPlayerStateChanged(this.playerState);
  @override
  List<Object?> get props => [playerState];
}

class AudioCurrentIndexChanged extends AudioEvent {
  final int? index;
  const AudioCurrentIndexChanged(this.index);
  @override
  List<Object?> get props => [index];
}

class AudioDominantColorUpdated extends AudioEvent {
  final dynamic color; // dart:ui Color
  const AudioDominantColorUpdated(this.color);
}

class AudioUpdateQueue extends AudioEvent {
  final List<Map<String, String>> newQueue;
  const AudioUpdateQueue(this.newQueue);
  @override
  List<Object?> get props => [newQueue];
}
