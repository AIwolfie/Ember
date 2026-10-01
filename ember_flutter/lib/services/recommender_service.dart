import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ember_flutter/services/database_service.dart';
import 'package:ember_flutter/services/python_service.dart';
import 'package:ember_flutter/utils/result.dart';

class RecommenderService {
  static final RecommenderService instance = RecommenderService._init();
  RecommenderService._init();

  Map<String, double> _artistAffinityCache = {};
  Map<String, Map<String, double>> _affinityGraph = {};
  bool _isInitialized = false;
  
  Map<String, double> get artistAffinityCache => _artistAffinityCache;

  /// Call this when app starts or when new plays happen to rebuild affinities
  Future<void> initializeAffinities() async {
    final history = await DatabaseService.instance.getPlayHistory();
    _artistAffinityCache.clear();
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (var track in history) {
      final artist = track['artist'];
      final tsStr = track['timestamp'];
      // Default to now if no timestamp to avoid crashes, though we shouldn't hit it.
      final ts = (tsStr != null) ? (int.tryParse(tsStr.toString()) ?? now) : now;
      
      if (artist != null && artist.isNotEmpty && artist != 'Unknown Artist') {
         // Exponential decay: weight halves every 30 days
         final double daysOld = (now - ts) / (1000 * 60 * 60 * 24);
         final weight = 1.0 * (daysOld > 0 ? (1.0 / (1.0 + (daysOld / 30.0))) : 1.0);
        _artistAffinityCache[artist] = (_artistAffinityCache[artist] ?? 0.0) + weight;
      }
    }
    
    // Check favorites
    final favorites = await DatabaseService.instance.getFavorites();
    for (var track in favorites) {
      final artist = track['artist'];
      if (artist != null && artist.isNotEmpty && artist != 'Unknown Artist') {
        _artistAffinityCache[artist] = (_artistAffinityCache[artist] ?? 0.0) + 3.0; // Favorites count more, no decay
      }
    }
    
    // Check Playlists (Imported Playlist Learning)
    final playlists = await DatabaseService.instance.getAllPlaylists();
    for (var pList in playlists.values) {
       for (var track in pList) {
          final artist = track['artist'];
          if (artist != null && artist.isNotEmpty && artist != 'Unknown Artist') {
            _artistAffinityCache[artist] = (_artistAffinityCache[artist] ?? 0.0) + 2.0; 
          }
       }
    }

    _isInitialized = true;
    
    // Build ML graph in background
    _buildGraphInBackground(history);
  }

  Future<void> _buildGraphInBackground(List<Map<String, String>> history) async {
    try {
       final historyJson = jsonEncode(history);
       final res = await PythonService.buildAffinityGraph(historyJson);
       if (res is Success<Map<String, Map<String, double>>>) {
         _affinityGraph = res.data;
       }
    } catch(e) {
       debugPrint("Graph build silently failed: \$e");
    }
  }

  Future<void> saveColdStartArtists(List<Map<String, String>> artists) async {
    // We can simulate saving these as favorites or just boosting their affinity in memory/db.
    // We'll write to a "cache" table specifically for user onboarding affinity.
    for (var artist in artists) {
      final name = artist['title'] ?? artist['artist']; // Usually top artists return title as name
      if (name != null) {
        _artistAffinityCache[name] = (_artistAffinityCache[name] ?? 0.0) + 10.0;
        await DatabaseService.instance.setCache('affinity_boost_\$name', '10.0');
      }
    }
  }

  /// Advanced Youtube-style Recommendation Algorithm
  Future<List<Map<String, String>>> getRecommendations(List<String> seedIds, {String? currentArtist}) async {
    if (!_isInitialized) await initializeAffinities();

    final db = DatabaseService.instance;
    final playHistory = await db.getPlayHistory();
    final recentVideoIds = playHistory.take(20).map((t) => t['videoId']).toSet();
    
    List<Map<String, String>> candidates = [];

    // Stage 1: Candidate Generation (Retrieval)
    
    // Source A: YT Music Similar Graph (Collaborative Filtering)
    try {
      if (seedIds.contains('default')) {
        // Cold start fallback: Fetch top global hits for first-time users
        final searchRes = await PythonService.search("top global hits", filterType: "songs");
        if (searchRes is Success) {
          final data = (searchRes as Success).data as List<dynamic>;
          for (var item in data) {
             final itemMap = (item as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
             candidates.add(itemMap);
          }
        }
      } else {
        final futures = seedIds.take(3).map((id) => PythonService.similar(id)).toList();
        final results = await Future.wait(futures);
        for (final similarResult in results) {
          if (similarResult is Success<List<Map<String, String>>>) {
            candidates.addAll(similarResult.data);
          }
        }
      }
    } catch (e) {
      debugPrint("Similar fetch failed: $e");
    }

    // Source B: Random Favorites (Locally loved items)
    final favorites = await db.getFavorites();
    if (favorites.isNotEmpty) {
      favorites.shuffle();
      candidates.addAll(favorites.take(5));
    }

    // Stage 2: Ranking
    Map<String, double> scores = {};
    for (int i = 0; i < candidates.length; i++) {
      final track = candidates[i];
      final videoId = track['videoId'];
      if (videoId == null) continue;
      
      // Base Score depends on exact duplicate merge
      if (scores.containsKey(videoId)) {
        scores[videoId] = scores[videoId]! + 1.0; 
        continue;
      }
      
      double score = 100.0 - (i * 1.5); // Base score higher for early candidates
      
      // Affinity Multiplier
      final artist = track['artist'];
      if (artist != null) {
        if (_artistAffinityCache.containsKey(artist)) {
          score += (_artistAffinityCache[artist]! * 2.0); // Boost by affinity
        }
        
        // Co-Occurrence Graph Boost
        if (currentArtist != null && _affinityGraph.containsKey(currentArtist)) {
           final related = _affinityGraph[currentArtist]!;
           if (related.containsKey(artist)) {
              score += related[artist]! * 1.5; // Boost based on historical sessions
           }
        }
      }

      // Context-aware: Time of Day checking not deeply integrated into tracks yet, 
      // but we could boost specific lists based on time!

      // Fatigue Penalty
      if (recentVideoIds.contains(videoId)) {
        score -= 200.0; // Heavily penalize recently played tracks
      }

      scores[videoId] = score;
    }

    // Remove duplicates from candidate list by making a unique map
    Map<String, Map<String, String>> uniqueCandidates = {};
    for (var track in candidates) {
      final vId = track['videoId'];
      if (vId != null && !uniqueCandidates.containsKey(vId)) {
        uniqueCandidates[vId] = track;
      }
    }

    // Sort by final score
    List<Map<String, String>> ranked = uniqueCandidates.values.toList();
    ranked.sort((a, b) {
      final scoreA = scores[a['videoId']] ?? 0.0;
      final scoreB = scores[b['videoId']] ?? 0.0;
      return scoreB.compareTo(scoreA); // Descending
    });

    // Return the top tracks
    return ranked;
  }
}
