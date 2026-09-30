import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ember_storage.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Safe migration: User playlists, favorites, history, and downloads are strictly preserved.
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT UNIQUE,
        timestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE play_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        videoId TEXT UNIQUE,
        trackData TEXT,
        timestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        videoId TEXT UNIQUE,
        trackData TEXT,
        timestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        timestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlistName TEXT,
        videoId TEXT,
        trackData TEXT,
        timestamp INTEGER,
        FOREIGN KEY (playlistName) REFERENCES playlists (name) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cache (
        key TEXT PRIMARY KEY,
        data TEXT,
        timestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE downloads (
        videoId TEXT PRIMARY KEY,
        filePath TEXT,
        trackData TEXT,
        timestamp INTEGER
      )
    ''');
  }

  // --- Downloads ---
  Future<void> addDownload(Map<String, String> track, String filePath) async {
    final db = await instance.database;
    final videoId = track['videoId'];
    if (videoId == null) return;

    await db.insert('downloads', {
      'videoId': videoId,
      'filePath': filePath,
      'trackData': jsonEncode(track),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeDownload(String videoId) async {
    final db = await instance.database;
    await db.delete('downloads', where: 'videoId = ?', whereArgs: [videoId]);
  }

  Future<Map<String, dynamic>?> getDownload(String videoId) async {
    final db = await instance.database;
    final res = await db.query(
      'downloads',
      where: 'videoId = ?',
      whereArgs: [videoId],
    );
    if (res.isNotEmpty) {
      return {
        'filePath': res.first['filePath'],
        'trackData': Map<String, String>.from(
          jsonDecode(res.first['trackData'] as String),
        ),
      };
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllDownloads() async {
    final db = await instance.database;
    final res = await db.query('downloads', orderBy: 'timestamp DESC');
    return res.map((e) {
      return {
        'filePath': e['filePath'],
        'trackData': Map<String, String>.from(
          jsonDecode(e['trackData'] as String),
        ),
      };
    }).toList();
  }

  // --- Search History ---
  Future<void> addSearch(String query) async {
    final db = await instance.database;
    await db.insert('search_history', {
      'query': query,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeSearch(String query) async {
    final db = await instance.database;
    await db.delete('search_history', where: 'query = ?', whereArgs: [query]);
  }

  Future<void> clearSearchHistory() async {
    final db = await instance.database;
    await db.delete('search_history');
  }

  Future<List<String>> getSearchHistory() async {
    final db = await instance.database;
    final res = await db.query(
      'search_history',
      orderBy: 'timestamp DESC',
      limit: 20,
    );
    return res.map((e) => e['query'] as String).toList();
  }

  // --- Play History ---
  Future<void> addPlayHistory(Map<String, String> track) async {
    final db = await instance.database;
    final videoId = track['videoId'];
    if (videoId == null) return;

    await db.insert('play_history', {
      'videoId': videoId,
      'trackData': jsonEncode(track),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Limits
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM play_history'),
        ) ??
        0;
    if (count > 50) {
      await db.execute(
        'DELETE FROM play_history WHERE id IN (SELECT id FROM play_history ORDER BY timestamp ASC LIMIT ?)',
        [count - 50],
      );
    }
  }

  Future<List<Map<String, String>>> getPlayHistory() async {
    final db = await instance.database;
    final res = await db.query('play_history', orderBy: 'timestamp DESC');
    return res.map((e) {
      return Map<String, String>.from(jsonDecode(e['trackData'] as String));
    }).toList();
  }

  Future<void> clearPlayHistory() async {
    final db = await instance.database;
    await db.delete('play_history');
  }

  // --- Favorites ---
  Future<void> toggleFavorite(Map<String, String> track) async {
    final db = await instance.database;
    final videoId = track['videoId'];
    if (videoId == null) return;

    final existing = await db.query(
      'favorites',
      where: 'videoId = ?',
      whereArgs: [videoId],
    );
    if (existing.isNotEmpty) {
      await db.delete('favorites', where: 'videoId = ?', whereArgs: [videoId]);
    } else {
      await db.insert('favorites', {
        'videoId': videoId,
        'trackData': jsonEncode(track),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<List<Map<String, String>>> getFavorites() async {
    final db = await instance.database;
    final res = await db.query('favorites', orderBy: 'timestamp DESC');
    return res.map((e) {
      return Map<String, String>.from(jsonDecode(e['trackData'] as String));
    }).toList();
  }

  // --- Playlists ---
  Future<void> createPlaylist(String name) async {
    final db = await instance.database;
    await db.insert(
      'playlists',
      {'name': name, 'timestamp': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore, // Don't override if exists
    );
  }

  Future<void> deletePlaylist(String name) async {
    final db = await instance.database;
    await db.delete('playlists', where: 'name = ?', whereArgs: [name]);
    // cascade deletes playlist_tracks
  }

  Future<void> addToPlaylist(String name, Map<String, String> track) async {
    final db = await instance.database;
    final videoId = track['videoId'];
    if (videoId == null) return;

    // verify playlist exists
    final pRes = await db.query(
      'playlists',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (pRes.isEmpty) return;

    // Avoid duplicate in playlist
    final existing = await db.query(
      'playlist_tracks',
      where: 'playlistName = ? AND videoId = ?',
      whereArgs: [name, videoId],
    );
    if (existing.isNotEmpty) return;

    await db.insert('playlist_tracks', {
      'playlistName': name,
      'videoId': videoId,
      'trackData': jsonEncode(track),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> removeFromPlaylist(String name, String videoId) async {
    final db = await instance.database;
    await db.delete(
      'playlist_tracks',
      where: 'playlistName = ? AND videoId = ?',
      whereArgs: [name, videoId],
    );
  }

  Future<Map<String, List<Map<String, String>>>> getAllPlaylists() async {
    final db = await instance.database;
    final playlistsRes = await db.query('playlists', orderBy: 'timestamp ASC');

    Map<String, List<Map<String, String>>> result = {};
    for (var p in playlistsRes) {
      final name = p['name'] as String;
      result[name] = [];
    }

    final tracksRes = await db.query(
      'playlist_tracks',
      orderBy: 'timestamp ASC',
    );
    for (var t in tracksRes) {
      final pName = t['playlistName'] as String;
      if (result.containsKey(pName)) {
        result[pName]!.add(
          Map<String, String>.from(jsonDecode(t['trackData'] as String)),
        );
      }
    }

    return result;
  }

  // --- Cache (For Home Feed, etc) ---
  Future<void> setCache(String key, String data) async {
    final db = await instance.database;
    await db.insert('cache', {
      'key': key,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getCache(String key) async {
    final db = await instance.database;
    final res = await db.query('cache', where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) {
      return res.first['data'] as String;
    }
    return null;
  }

  // --- Resume State ---
  Future<void> saveResumeState(Map<String, String> track, int positionMs) async {
    final db = await instance.database;
    final data = {
      'track': track,
      'positionMs': positionMs,
    };
    await db.insert('cache', {
      'key': 'resume_state',
      'data': jsonEncode(data),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getResumeState() async {
    final db = await instance.database;
    final res = await db.query('cache', where: 'key = ?', whereArgs: ['resume_state']);
    if (res.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.first['data'] as String) as Map<String, dynamic>;
        return {
          'track': Map<String, String>.from(decoded['track']),
          'positionMs': decoded['positionMs'] as int,
        };
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
