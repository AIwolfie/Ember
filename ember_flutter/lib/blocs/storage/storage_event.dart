import 'package:equatable/equatable.dart';

abstract class StorageEvent extends Equatable {
  const StorageEvent();

  @override
  List<Object?> get props => [];
}

class StorageLoadAll extends StorageEvent {}

class StorageAddSearch extends StorageEvent {
  final String query;
  const StorageAddSearch(this.query);
  @override
  List<Object?> get props => [query];
}

class StorageRemoveSearch extends StorageEvent {
  final String query;
  const StorageRemoveSearch(this.query);
  @override
  List<Object?> get props => [query];
}

class StorageClearSearch extends StorageEvent {}

class StorageClearPlayHistory extends StorageEvent {}

class StorageAddPlayHistory extends StorageEvent {
  final Map<String, String> track;
  const StorageAddPlayHistory(this.track);
  @override
  List<Object?> get props => [track];
}

class StorageToggleFavorite extends StorageEvent {
  final Map<String, String> track;
  const StorageToggleFavorite(this.track);
  @override
  List<Object?> get props => [track];
}

class StorageCreatePlaylist extends StorageEvent {
  final String name;
  const StorageCreatePlaylist(this.name);
  @override
  List<Object?> get props => [name];
}

class StorageImportPlaylist extends StorageEvent {
  final String name;
  final List<Map<String, String>> tracks;
  const StorageImportPlaylist({required this.name, required this.tracks});
  @override
  List<Object?> get props => [name, tracks];
}

class StorageAddToPlaylist extends StorageEvent {
  final String name;
  final Map<String, String> track;
  const StorageAddToPlaylist({required this.name, required this.track});
  @override
  List<Object?> get props => [name, track];
}

class StorageRemoveFromPlaylist extends StorageEvent {
  final String name;
  final String videoId;
  const StorageRemoveFromPlaylist({required this.name, required this.videoId});
  @override
  List<Object?> get props => [name, videoId];
}

class StorageReorderPlaylist extends StorageEvent {
  final String name;
  final int oldIndex;
  final int newIndex;
  const StorageReorderPlaylist({
    required this.name,
    required this.oldIndex,
    required this.newIndex,
  });
  @override
  List<Object?> get props => [name, oldIndex, newIndex];
}

class StorageDeletePlaylist extends StorageEvent {
  final String name;
  const StorageDeletePlaylist(this.name);
  @override
  List<Object?> get props => [name];
}
