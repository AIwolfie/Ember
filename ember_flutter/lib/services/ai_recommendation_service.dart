import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ember_flutter/services/database_service.dart';
import 'package:ember_flutter/services/recommender_service.dart';
import 'package:ember_flutter/services/python_service.dart';

class AiRecommendationResponse {
  final List<Map<String, String>> songs;
  final String reason;

  AiRecommendationResponse({required this.songs, required this.reason});
}

class AiRecommendationService {
  // Directly using Groq API for 100% free serverless architecture
  static const String endpoint = "https://api.groq.com/openai/v1/chat/completions";
  static String get apiKey => dotenv.env['GROQ_KEY'] ?? 'YOUR_GROQ_API_KEY';

  static final Map<String, Future<AiRecommendationResponse>> _activeRequests = {};

  /// Gets an AI Recommendation Mix, falling back to local SQLite if it fails
  static Future<AiRecommendationResponse> getAiMix(String mood) async {
    // 1. Debounce and Lock (Prevent users from spamming the button)
    if (_activeRequests.containsKey(mood)) {
      return _activeRequests[mood]!;
    }

    final future = _getAiMixInternal(mood);
    _activeRequests[mood] = future;

    try {
      return await future;
    } finally {
      _activeRequests.remove(mood);
    }
  }

  static Future<AiRecommendationResponse> _getAiMixInternal(String mood) async {
    try {
      final db = DatabaseService.instance;
      
      // 2. Cache Layer (Your local 'Redis')
      final cacheKey = 'ai_mix_$mood';
      final cachedString = await db.getCache(cacheKey);
      if (cachedString != null) {
        try {
           final decoded = jsonDecode(cachedString);
           final timestamp = decoded['timestamp'] ?? 0;
           // 12 hour cache expiration (12 * 60 * 60 * 1000 = 43200000 ms)
           if (DateTime.now().millisecondsSinceEpoch - timestamp < 43200000) {
             final List<Map<String, String>> cachedSongs = (decoded['songs'] as List).map((e) => Map<String, String>.from(e)).toList();
             return AiRecommendationResponse(songs: cachedSongs, reason: decoded['reason']);
           }
        } catch (_) {}
      }

      final playHistory = await db.getPlayHistory();
      
      // Get unique recent artists
      final Set<String> artistsSet = {};
      for (var track in playHistory.take(20)) {
        if (track['artist'] != null && track['artist'] != 'Unknown Artist') {
          artistsSet.add(track['artist']!);
        }
      }
      final recentArtists = artistsSet.take(5).toList();

      String contextLine = "";
      if (recentArtists.isNotEmpty) {
         contextLine = "The user recently listened to artists: ${recentArtists.join(", ")}.\nRecommend exactly 3 new songs they might like (do not repeat their recent artists).";
      } else {
         contextLine = "The user is brand new to the music app and has no listening history.\nRecommend exactly 3 universally loved, extremely popular songs that perfectly fit their mood.";
      }

      final prompt = '''
You are an expert DJ AI for the Ember music app. 
$contextLine
Their current context/mood is: $mood.
Explain WHY you recommended these songs in one short engaging sentence.

Format your response exactly as JSON like this:
{
  "recommendations": [
    {"song_title": "Title 1", "artist": "Artist 1"},
    {"song_title": "Title 2", "artist": "Artist 2"}
  ],
  "reason": "Because you've been listening to X, here is some Y."
}
''';

      // 2. Make request directly to Groq (No Cloudflare Middleman)
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            { "role": "system", "content": "You are a helpful JSON music recommendation API. Only output valid JSON without markdown wrapping." },
            { "role": "user", "content": prompt }
          ],
          "response_format": { "type": "json_object" }
        }),
      ).timeout(const Duration(seconds: 15)); // Increased slightly to give Groq breathing room

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiString = data['choices']?[0]?['message']?['content'] ?? "";
        
        // Try parsing JSON out of the AI response
        try {
          final start = aiString.indexOf('{');
          final end = aiString.lastIndexOf('}');
          if (start != -1 && end != -1) {
             final cleanJson = aiString.substring(start, end + 1);
             final aiContent = jsonDecode(cleanJson);
             
             final List<Map<String, String>> resolvedSongs = [];
             final List recommendations = aiContent['recommendations'] ?? [];
             
             // Convert AI response into actual YouTube Playable IDs via native python
             for (var rec in recommendations) {
               final title = rec['song_title'] ?? '';
               final artist = rec['artist'] ?? '';
               if (title.isNotEmpty && artist.isNotEmpty) {
                  final searchRes = await PythonService.search("$title $artist", filterType: "songs");
                  if (searchRes.isSuccess && searchRes.data != null && (searchRes.data as List).isNotEmpty) {
                    final item = (searchRes.data as List).first;
                    resolvedSongs.add(Map<String, String>.from(item.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''))));
                  }
               }
             }

             if (resolvedSongs.isNotEmpty) {
               final responseObj = AiRecommendationResponse(songs: resolvedSongs, reason: aiContent['reason'] ?? "Here is your custom mix!");
               // Save to Cache
               await db.setCache(cacheKey, jsonEncode({
                 'timestamp': DateTime.now().millisecondsSinceEpoch,
                 'songs': resolvedSongs,
                 'reason': responseObj.reason
               }));
               return responseObj;
             }
          }
        } catch (e) {
          debugPrint("Failed to parse AI JSON: $e");
        }
      } else {
         debugPrint("Groq request failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("AI Request Failed or Timed out. Falling back... $e");
    }

    // 3. Fallback to Local Recommendations
    return _getLocalFallback(mood);
  }

  static Future<AiRecommendationResponse> _getLocalFallback(String mood) async {
    final localRecs = await RecommenderService.instance.getRecommendations(['default']);
    return AiRecommendationResponse(
      songs: localRecs.take(5).toList(), 
      reason: "Groq is taking a break! Here are some local tracks picked from your favorites."
    );
  }
}
