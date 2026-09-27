import 'dart:math' as math;

class SearchAlgorithm {
  /// Optimizes raw search results by handling heuristics and edge cases.
  /// Modifies and prioritizes items based on exact match metrics.
  static List<Map<String, String>> optimizeResults(List<Map<String, String>> rawItems, String query) {
    if (rawItems.isEmpty) return rawItems;

    // Create a new list to avoid mutating the original
    final items = List<Map<String, String>>.from(rawItems);
    final queryLower = query.trim().toLowerCase();
    
    // Find precise match for title, or closest match using Levenshtein distance
    int bestMatchIndex = -1;
    int minDistance = 999999;

    for (int i = 0; i < items.length; i++) {
      final track = items[i];
      final type = track['type'];
      if (type == null || type == 'song' || type == 'video' || type == 'album' || type == 'artist' || type == 'playlist') {
        final titleLower = (track['title'] ?? '').toLowerCase();
        
        // Exact match takes immediate precedence
        if (titleLower == queryLower) {
          bestMatchIndex = i;
          minDistance = 0;
          break;
        }

        // Calculate Levenshtein distance for fuzzy matching
        final distance = _levenshtein(titleLower, queryLower);
        if (distance < minDistance) {
          minDistance = distance;
          bestMatchIndex = i;
        }
      }
    }

    // Only hoist if the best match is reasonably close (e.g. less than 3 typos, or exact)
    // If it's a long query, allow more typos proportionally.
    final maxAllowedDistance = math.max(2, (queryLower.length * 0.3).ceil());

    if (bestMatchIndex >= 0 && minDistance <= maxAllowedDistance) {
        if (bestMatchIndex > 0) {
            final bestMatch = items.removeAt(bestMatchIndex);
            items.insert(0, bestMatch);
        }
        
        // Hoist associated artists immediately under the Top Match seamlessly
        final topArtistStr = items[0]['artist'] ?? '';
        final validArtistIds = <String>{};
        if (topArtistStr.isNotEmpty) {
           final artistNames = topArtistStr.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
           
           final artistsToHoist = <Map<String, String>>[];

           // Collect all artist matching items
           items.removeWhere((track) {
             if (track['type'] == 'artist') {
               final trackTitle = (track['title'] ?? '').toLowerCase();
               if (artistNames.any((aName) => trackTitle.contains(aName) || aName.contains(trackTitle))) {
                 artistsToHoist.add(track);
                 validArtistIds.add(track['browseId'] ?? track['videoId'] ?? '');
                 return true; 
               }
             }
             return false;
           });

           // Insert hoisted artists right below the top match
           items.insertAll(1, artistsToHoist);
        }
        
        // Remove completely unrelated artist suggestions to keep the list focused on songs
        items.removeWhere((track) => 
           track['type'] == 'artist' && 
           !validArtistIds.contains(track['browseId'] ?? track['videoId'] ?? '') 
        );
    }

    return items;
  }

  /// Calculates the Levenshtein distance between two strings
  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    
    List<int> v0 = List.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        v1[j + 1] = math.min(math.min(v1[j] + 1, v0[j + 1] + 1), v0[j] + cost);
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }

  /// Extracts explicitly unmasked subtitles for UI displaying.
  static String getSubtitle(Map<String, String> track, String type, {required bool isTopCard}) {
    final topArtist = track['artist'] ?? '';
    final duration = track['duration'] ?? '';

    // If it is a standard list item for a track, YTMusic style shows just "Artist • length"
    if (!isTopCard && (type == 'song' || type == 'video')) {
      if (topArtist.isNotEmpty && duration.isNotEmpty) return '$topArtist • $duration';
      if (topArtist.isNotEmpty) return topArtist;
      return 'Unknown';
    }

    if (type == 'artist') {
      return 'Artist';
    } else if (type == 'album') {
      return topArtist.isNotEmpty ? 'Album • $topArtist' : 'Album';
    } else if (type == 'playlist') {
      return topArtist.isNotEmpty ? 'Playlist • $topArtist' : 'Playlist';
    } else if (type == 'video') {
      return topArtist.isNotEmpty ? 'Video • $topArtist' : 'Video';
    } else {
      return topArtist.isNotEmpty ? 'Song • $topArtist' : 'Song';
    }
  }
}
