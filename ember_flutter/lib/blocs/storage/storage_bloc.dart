import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ember_flutter/services/database_service.dart';
import 'package:ember_flutter/blocs/storage/storage_event.dart';
import 'package:ember_flutter/blocs/storage/storage_state.dart';

class StorageBloc extends Bloc<StorageEvent, StorageState> {
  final DatabaseService _db = DatabaseService.instance;

  StorageBloc() : super(const StorageState()) {
    on<StorageLoadAll>(_onLoadAll);
    on<StorageAddSearch>(_onAddSearch);
    on<StorageRemoveSearch>(_onRemoveSearch);
    on<StorageClearSearch>(_onClearSearch);
    on<StorageAddPlayHistory>(_onAddPlayHistory);
    on<StorageClearPlayHistory>(_onClearPlayHistory);
    on<StorageToggleFavorite>(_onToggleFavorite);
    on<StorageCreatePlaylist>(_onCreatePlaylist);
    on<StorageImportPlaylist>(_onImportPlaylist);
    on<StorageAddToPlaylist>(_onAddToPlaylist);
    on<StorageRemoveFromPlaylist>(_onRemoveFromPlaylist);
    on<StorageDeletePlaylist>(_onDeletePlaylist);
    on<StorageReorderPlaylist>(_onReorderPlaylist);
  }

  Future<void> init() async {
    // initialize db implicit via getter
    await _db.database;
    add(StorageLoadAll());
  }

  Future<void> _onLoadAll(
    StorageLoadAll event,
    Emitter<StorageState> emit,
  ) async {
    final sh = await _db.getSearchHistory();
    final ph = await _db.getPlayHistory();
    final fav = await _db.getFavorites();
    final pl = await _db.getAllPlaylists();

    emit(
      state.copyWith(
        searchHistory: sh,
        playHistory: ph,
        favorites: fav,
        playlists: pl,
      ),
    );
  }

  Future<void> _onAddSearch(
    StorageAddSearch event,
    Emitter<StorageState> emit,
  ) async {
    final cur = event.query.trim();
    if (cur.isEmpty) return;

    await _db.addSearch(cur);
    final sh = await _db.getSearchHistory();
    emit(state.copyWith(searchHistory: sh));
  }

  Future<void> _onRemoveSearch(
    StorageRemoveSearch event,
    Emitter<StorageState> emit,
  ) async {
    await _db.removeSearch(event.query);
    final sh = await _db.getSearchHistory();
    emit(state.copyWith(searchHistory: sh));
  }

  Future<void> _onClearSearch(
    StorageClearSearch event,
    Emitter<StorageState> emit,
  ) async {
    await _db.clearSearchHistory();
    emit(state.copyWith(searchHistory: []));
  }

  Future<void> _onAddPlayHistory(
    StorageAddPlayHistory event,
    Emitter<StorageState> emit,
  ) async {
    await _db.addPlayHistory(event.track);
    final ph = await _db.getPlayHistory();
    emit(state.copyWith(playHistory: ph));
  }

  Future<void> _onClearPlayHistory(
    StorageClearPlayHistory event,
    Emitter<StorageState> emit,
  ) async {
    await _db.clearPlayHistory();
    emit(state.copyWith(playHistory: []));
  }

  Future<void> _onToggleFavorite(
    StorageToggleFavorite event,
    Emitter<StorageState> emit,
  ) async {
    await _db.toggleFavorite(event.track);
    final fav = await _db.getFavorites();
    emit(state.copyWith(favorites: fav));
  }

  Future<void> _onCreatePlaylist(
    StorageCreatePlaylist event,
    Emitter<StorageState> emit,
  ) async {
    if (event.name.trim().isEmpty) return;
    await _db.createPlaylist(event.name);
    final pl = await _db.getAllPlaylists();
    emit(state.copyWith(playlists: pl));
  }

  Future<void> _onImportPlaylist(
    StorageImportPlaylist event,
    Emitter<StorageState> emit,
  ) async {
    if (event.name.trim().isEmpty || event.tracks.isEmpty) return;
    await _db.createPlaylist(event.name);
    for (final track in event.tracks) {
      await _db.addToPlaylist(event.name, track);
    }
    final pl = await _db.getAllPlaylists();
    emit(state.copyWith(playlists: pl));
  }

  Future<void> _onAddToPlaylist(
    StorageAddToPlaylist event,
    Emitter<StorageState> emit,
  ) async {
    await _db.addToPlaylist(event.name, event.track);
    final pl = await _db.getAllPlaylists();
    emit(state.copyWith(playlists: pl));
  }

  Future<void> _onRemoveFromPlaylist(
    StorageRemoveFromPlaylist event,
    Emitter<StorageState> emit,
  ) async {
    await _db.removeFromPlaylist(event.name, event.videoId);
    final pl = await _db.getAllPlaylists();
    emit(state.copyWith(playlists: pl));
  }

  Future<void> _onDeletePlaylist(
    StorageDeletePlaylist event,
    Emitter<StorageState> emit,
  ) async {
    await _db.deletePlaylist(event.name);
    final pl = await _db.getAllPlaylists();
    emit(state.copyWith(playlists: pl));
  }

  Future<void> _onReorderPlaylist(
    StorageReorderPlaylist event,
    Emitter<StorageState> emit,
  ) async {
    final currentList = state.playlists[event.name];
    if (currentList == null) return;
    final newList = List<Map<String, String>>.from(currentList);

    final item = newList.removeAt(event.oldIndex);
    newList.insert(event.newIndex, item);

    // SQLite playlist tracks are ordered by insertion time currently.
    // To reorder, we delete and re-insert the tracks.
    await _db.deletePlaylist(event.name);
    await _db.createPlaylist(event.name);
    for (final track in newList) {
      await _db.addToPlaylist(event.name, track);
    }

    final pl = await _db.getAllPlaylists();
    emit(state.copyWith(playlists: pl));
  }
}
