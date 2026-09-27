import 'package:equatable/equatable.dart';

class StorageState extends Equatable {
  final List<String> searchHistory;
  final List<Map<String, String>> playHistory;
  final List<Map<String, String>> favorites;
  final Map<String, List<Map<String, String>>> playlists;

  const StorageState({
    this.searchHistory = const [],
    this.playHistory = const [],
    this.favorites = const [],
    this.playlists = const {},
  });

  StorageState copyWith({
    List<String>? searchHistory,
    List<Map<String, String>>? playHistory,
    List<Map<String, String>>? favorites,
    Map<String, List<Map<String, String>>>? playlists,
  }) {
    return StorageState(
      searchHistory: searchHistory ?? this.searchHistory,
      playHistory: playHistory ?? this.playHistory,
      favorites: favorites ?? this.favorites,
      playlists: playlists ?? this.playlists,
    );
  }

  bool isFavorite(String videoId) {
    return favorites.any((t) => t['videoId'] == videoId);
  }

  @override
  List<Object?> get props => [searchHistory, playHistory, favorites, playlists];
}

class StorageInitial extends StorageState {}
