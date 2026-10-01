import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ember_flutter/services/python_service.dart';
import 'package:ember_flutter/services/database_service.dart';
import 'package:ember_flutter/services/recommender_service.dart';
import 'package:ember_flutter/utils/result.dart';
import 'package:ember_flutter/screens/home/bloc/home_event.dart';
import 'package:ember_flutter/screens/home/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  List<Map<String, dynamic>>? _cachedBaseSections;
  bool _isColdStart = false;

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
        // Query YT for the top mood hits
        final result = await PythonService.search("${event.mood} hits", filterType: "songs");
        switch (result) {
          case Success():
            if (result.data.isEmpty) {
              emit(const HomeError("No tracks found for this mood."));
            } else {
              List<dynamic> rawHits = result.data;
              List<dynamic> curatedMix = [];

              try {
                // Grab the absolute top hits from this mood and seed them into our Recommender
                final seedIds = rawHits.take(2).map((e) => (e as Map)['videoId']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
                if (seedIds.isNotEmpty) {
                  final curatedRecs = await RecommenderService.instance.getRecommendations(seedIds);
                  if (curatedRecs.isNotEmpty) {
                    curatedMix = curatedRecs; // Highly personalized mix!
                  }
                }
              } catch (_) {}
              
              final sections = <Map<String, dynamic>>[];
              
              if (curatedMix.isNotEmpty) {
                sections.add({
                  "title": "Your ${event.mood} Mix",
                  "tracks": curatedMix.take(16).toList(), // Limit to 4 pages of 4 items
                });
              }

              if (rawHits.isNotEmpty) {
                sections.add({
                  "title": "Top ${event.mood} Hits",
                  "tracks": rawHits.take(16).toList(), // Limit to 4 pages of 4 items
                });
              }

              if (sections.isEmpty) {
                 emit(const HomeError("No tracks found for this mood."));
                 return;
              }

              emit(HomeLoaded(sections, activeMood: event.mood));
            }
          case Failure():
            emit(HomeError(result.message));
        }
      } else {
        if (!event.forceRefresh && _cachedBaseSections != null) {
           // Instantly restore base feed if available in memory
           emit(HomeLoaded(_cachedBaseSections!, activeMood: null, isColdStart: _isColdStart));
           return;
        }

        final recentPlays = await DatabaseService.instance.getPlayHistory();
        final recentIds = recentPlays
            .take(3)
            .map((e) => e['videoId'] ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
            
        _isColdStart = recentIds.isEmpty;

        final resultFuture = PythonService.getHome(
          forceRefresh: event.forceRefresh,
          recentIds: recentIds,
        );

        // We will fetch top artists dynamically based on the AI recommendations.

        final result = await resultFuture;

        switch (result) {
          case Success():
            if (result.data.isEmpty) {
              emit(const HomeError("Home feed is empty."));
            } else {
              final sections = List<Map<String, dynamic>>.from(result.data);

              // Remove generic 'Quick picks' from API
              sections.removeWhere((sec) => (sec['title'] as String).toLowerCase().contains('quick picks'));

              // Inject AI Recommendations as the new Quick Picks
              List<Future<Result<dynamic>>> artistFutures = [];
              try {
                final List<String> seedIds = recentIds.isNotEmpty ? recentIds : ['default'];
                final recs = await RecommenderService.instance.getRecommendations(seedIds);
                
                if (recs.isNotEmpty) {
                  sections.insert(0, {
                    'title': 'Quick Picks',
                    'tracks': recs.take(16).toList(), // Exactly 4 pages of 4 items
                  });

                  // Extract artists directly from recommended tracks for hyper-relevant "Top Artists"
                  final Set<String> artistsSet = {};
                  for (final rec in recs) {
                    final trackArtist = rec['artist'] ?? '';
                    if (trackArtist.isNotEmpty && trackArtist != 'Unknown' && trackArtist != 'Unknown Artist') {
                      final names = trackArtist.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
                      artistsSet.addAll(names);
                    }
                  }

                  artistFutures = artistsSet.take(6).map(
                    (name) => PythonService.search(name, filterType: 'artists')
                  ).toList();
                }
              } catch (_) {}

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
              
              _cachedBaseSections = sections;
              emit(HomeLoaded(sections, activeMood: null, isColdStart: _isColdStart));
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
