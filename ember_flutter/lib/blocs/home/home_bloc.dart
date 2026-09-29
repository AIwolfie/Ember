import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/python_service.dart';
import '../../services/database_service.dart';
import '../../utils/result.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeLoading()) {
    on<HomeLoadRequested>(_onLoadRequested);
  }

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state is! HomeLoaded) {
      emit(HomeLoading());
    }

    try {
      if (event.mood != null) {
        final result = await PythonService.search("${event.mood} music");
        switch (result) {
          case Success():
            if (result.data.isEmpty) {
              emit(const HomeError("No tracks found for this mood."));
            } else {
              final section = {
                "title": "${event.mood} Picks",
                "tracks": result.data,
              };
              emit(HomeLoaded([section], activeMood: event.mood));
            }
          case Failure():
            emit(HomeError(result.message));
        }
      } else {
        final recentPlays = await DatabaseService.instance.getPlayHistory();
        final recentIds = recentPlays
            .take(3)
            .map((e) => e['videoId'] ?? '')
            .where((id) => id.isNotEmpty)
            .toList();

        final resultFuture = PythonService.getHome(
          forceRefresh: event.forceRefresh,
          recentIds: recentIds,
        );

        String? favoriteArtist;
        final counts = <String, int>{};
        if (recentPlays.isNotEmpty) {
          for (var p in recentPlays) {
            final artist = p['artist'] as String?;
            if (artist != null && artist.isNotEmpty && artist != 'Unknown' && artist != 'Unknown Artist') {
              // we can split by comma if multiple
              final names = artist.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
              for (var name in names) {
                counts[name] = (counts[name] ?? 0) + 1;
              }
            }
          }
        }
        final topArtists = counts.isEmpty
            ? <String>[]
            : (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                .take(6)
                .map((e) => e.key)
                .toList();

        final artistFutures = topArtists.map(
          (name) => PythonService.search(name, filterType: 'artists'),
        ).toList();

        final result = await resultFuture;

        switch (result) {
          case Success():
            if (result.data.isEmpty) {
              emit(const HomeError("Home feed is empty."));
            } else {
              final sections = List<Map<String, dynamic>>.from(result.data);

              if (artistFutures.isNotEmpty) {
                try {
                  final artistResults = await Future.wait(artistFutures);
                  final validArtists = <Map<String, dynamic>>[];
                  
                  for (var res in artistResults) {
                    if (res is Success) {
                      final data = (res as Success).data;
                      if (data is List && data.isNotEmpty) {
                        final items = data.cast<Map<String, dynamic>>();
                        if (items.isNotEmpty) {
                          final artistData = Map<String, dynamic>.from(items.first);
                          artistData['type'] = 'artist'; // Force type for SharedUI routing
                          validArtists.add(artistData);
                        }
                      }
                    }
                  }

                  if (validArtists.isNotEmpty) {
                    sections.insert(0, {
                      'title': 'Your Top Artists',
                      'type': 'artists',
                      'tracks': validArtists,
                    });
                  }
                } catch (_) {}
              }
              
              emit(HomeLoaded(sections, activeMood: null));
            }
          case Failure():
            emit(HomeError(result.message));
        }
      }
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }
}
