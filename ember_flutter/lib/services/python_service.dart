import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'database_service.dart';
import '../utils/result.dart';

class PythonService {
  static const MethodChannel _channel = MethodChannel('com.example.ember/python');
  static const String _homeCacheKey = 'cache_home_data';

  static Future<Result<List<Map<String, String>>>> search(String query, {String? filterType}) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('search', {'query': query, 'filter': filterType});
      final data = result.map((e) {
        final map = e as Map<dynamic, dynamic>;
        return map.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
      }).toList();
      return Success(data);
    } catch (e) {
      debugPrint("Error in search: $e");
      return Failure("Failed to search. Check internet or try again later.", e);
    }
  }

  static Future<Result<List<Map<String, String>>>> similar(String seedId) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('similar', {'seedId': seedId});
      final data = result.map((e) {
        final map = e as Map<dynamic, dynamic>;
        return map.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
      }).toList();
      return Success(data);
    } catch (e) {
      debugPrint("Error in similar: $e");
      return Failure("Failed to find similar tracks.", e);
    }
  }

  static Future<Result<Map<String, String?>>> getStreamUrl(String videoId) async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('get_stream_url', {'videoId': videoId});
      final data = result.map((key, value) => MapEntry(key.toString(), value?.toString()));
      if (data.containsKey('error') && data['error'] != null && data['error']!.isNotEmpty) {
         return Failure(data['error'] ?? "Unknown python error");
      }
      return Success(data);
    } catch (e) {
      debugPrint("Error in getStreamUrl: $e");
      return Failure("Failed to extract stream URL.", e);
    }
  }

  static Future<Result<List<Map<String, dynamic>>>> getHome({bool forceRefresh = false, List<String>? recentIds}) async {
    final db = DatabaseService.instance;

    if (!forceRefresh) {
      final cachedString = await db.getCache(_homeCacheKey);
      if (cachedString != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cachedString);
          final data = decoded.map((e) => e as Map<String, dynamic>).toList();
          return Success(data);
        } catch (e) {
          debugPrint("Error decoding cached home: $e");
        }
      }
    }

    try {
      final String result = await _channel.invokeMethod('get_home', {
        'recent_ids_str': recentIds != null ? recentIds.join(',') : ''
      });
      await db.setCache(_homeCacheKey, result); // Cache string in sqlite
      final List<dynamic> decoded = jsonDecode(result);
      final data = decoded.map((e) => e as Map<String, dynamic>).toList();
      return Success(data);
    } catch (e) {
      debugPrint("Error in getHome: $e");
      // Fallback to cache even on error 
      final cachedString = await db.getCache(_homeCacheKey);
      if (cachedString != null) {
        try {
           final List<dynamic> decoded = jsonDecode(cachedString);
           final data = decoded.map((e) => e as Map<String, dynamic>).toList();
           return Success(data);
        } catch (e2) {
           return Failure("Failed to load home feed and cache is corrupted.", e); 
        }
      }
      return Failure("Failed to load home feed. Please check your internet connection.", e);
    }
  }

  static Future<Result<String>> lyrics(String videoId, {String title = "", String artist = ""}) async {
    try {
      final res = await _channel.invokeMethod('lyrics', {
        'videoId': videoId,
        'title': title,
        'artist': artist,
      });
      if (res == null || res.toString().trim().isEmpty) {
        return const Failure("No lyrics found.");
      }
      return Success(res.toString());
    } catch (e) {
      debugPrint("Error in lyrics: $e");
      return Failure("Failed to fetch lyrics.", e);
    }
  }

  static Future<Result<Map<String, dynamic>>> getArtistDetails(String browseId) async {
    try {
      final String result = await _channel.invokeMethod('get_artist_details', {'browse_id': browseId});
      return Success(jsonDecode(result) as Map<String, dynamic>);
    } catch (e) {
      debugPrint("Error in getArtistDetails: $e");
      return Failure("Failed to load artist details.");
    }
  }

  static Future<Result<Map<String, dynamic>>> importPlaylist(String identifier) async {
    try {
      final String result = await _channel.invokeMethod('import_playlist', {'identifier': identifier});
      return Success(jsonDecode(result) as Map<String, dynamic>);
    } catch (e) {
      debugPrint("Error in importPlaylist: $e");
      return Failure("Failed to import playlist.");
    }
  }
}
