import 'package:cached_network_image/cached_network_image.dart';
import 'package:ember_flutter/blocs/audio/audio_bloc.dart';
import 'package:ember_flutter/blocs/audio/audio_event.dart';
import 'package:ember_flutter/blocs/storage/storage_bloc.dart';
import 'package:ember_flutter/blocs/storage/storage_event.dart';
import 'package:ember_flutter/blocs/storage/storage_state.dart';
import 'package:ember_flutter/screens/favorites/favorites_screen.dart';
import 'package:ember_flutter/screens/history/history_screen.dart';
import 'package:ember_flutter/services/database_service.dart';
import 'package:ember_flutter/services/python_service.dart';
import 'package:ember_flutter/theme.dart';
import 'package:ember_flutter/utils/result.dart';
import 'package:ember_flutter/widgets/bento_tile.dart';
import 'package:ember_flutter/widgets/playlist_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../widgets/shared_ui.dart';
import '../download/downloads_screen.dart';
import '../playlist/playlist_screen.dart';
import '../settings/settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Map<String, String>> _recentlyPlayed = [];
  bool _isLoadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecentlyPlayed();
  }

  Future<void> _loadRecentlyPlayed() async {
    final history = await DatabaseService.instance.getPlayHistory();
    final Set<String> seen = {};
    final List<Map<String, String>> uniqueHistory = [];
    for (var track in history) {
      if (track['videoId'] != null && !seen.contains(track['videoId']!)) {
        seen.add(track['videoId']!);
        uniqueHistory.add(track);
      }
    }
    if (mounted) {
      setState(() {
        _recentlyPlayed = uniqueHistory.take(20).toList();
        _isLoadingRecent = false;
      });
    }
  }

  void _showImportPlaylistDialog(BuildContext context) {
    final TextEditingController urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isImporting = false;
            return AlertDialog(
              backgroundColor: YTColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Import Playlist', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Paste a YouTube or Spotify playlist link to import its tracks into Ember.',
                    style: TextStyle(color: YTColors.secondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: YTColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (isImporting)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                if (!isImporting)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                if (!isImporting)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: YTColors.primary,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      final url = urlController.text.trim();
                      if (url.isNotEmpty) {
                        setDialogState(() => isImporting = true);
                        final res = await PythonService.importPlaylist(url);
                        if (!mounted) return;
                        setDialogState(() => isImporting = false);

                        if (res is Success<Map<String, dynamic>>) {
                          final data = res.data;
                          final tracks = data['tracks'] as List<dynamic>;
                          if (tracks.isNotEmpty) {
                            final playlistName = data['title'] ?? 'Imported Playlist';

                            await DatabaseService.instance.createPlaylist(playlistName);
                            for (var t in tracks) {
                              if (t is Map) {
                                final trackMap = (t).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
                                await DatabaseService.instance.addToPlaylist(playlistName, trackMap);
                              }
                            }
                            context.read<StorageBloc>().add(StorageLoadAll());
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Imported ${tracks.length} tracks to "$playlistName"'),
                                backgroundColor: YTColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No tracks could be found in this playlist.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        } else if (res is Failure) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text((res as Failure).message),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Import Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, EmberThemeOption>(
      builder: (context, themeOption) {
        return BlocBuilder<StorageBloc, StorageState>(
          builder: (context, storage) {
            return Scaffold(
              backgroundColor: YTColors.background,
              body: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  // Top Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 20,
                        right: 16,
                        bottom: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.whatshot, color: YTColors.primary, size: 28),
                          const SizedBox(width: 8),
                          const Text(
                            'Ember',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.settings_outlined,
                              color: Colors.white70,
                              size: 24,
                            ),
                            onPressed: () => showSettingsSheet(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'Your Library',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ),

                  // 1. Recently Played Section
                  if (!_isLoadingRecent && _recentlyPlayed.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                            child: Text(
                              'Recently Played',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 156,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _recentlyPlayed.length,
                              itemBuilder: (context, index) {
                                final track = _recentlyPlayed[index];
                                return _buildRecentCard(context, track, index);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // 2. Main Tile Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: BentoTile(
                                  title: 'Favorites',
                                  subtitle: '${storage.favorites.length} songs',
                                  icon: Icons.favorite_rounded,
                                  color: Colors.pinkAccent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const FavoritesScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: BentoTile(
                                  title: 'Downloads',
                                  subtitle: 'Offline listening',
                                  icon: Icons.download_done_rounded,
                                  color: Colors.greenAccent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DownloadsScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: BentoTile(
                                  title: 'Playlists',
                                  subtitle: '${storage.playlists.length} saved',
                                  icon: Icons.queue_music_rounded,
                                  color: Colors.purpleAccent,
                                  onTap: () => showPlaylistSheet(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: BentoTile(
                                  title: 'History',
                                  subtitle: 'Recently played',
                                  icon: Icons.history_rounded,
                                  color: Colors.blueAccent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const HistoryScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: BentoTile(
                                  title: 'Import',
                                  subtitle: 'From YouTube',
                                  icon: Icons.link_rounded,
                                  color: YTColors.primary,
                                  onTap: () => _showImportPlaylistDialog(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: const SizedBox()), // Placeholder for symmetry
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Playlists List (Below Navigation Tiles)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(left: 20, right: 20, top: 32, bottom: 8),
                      child: Text(
                        'Your Playlists',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  _buildPlaylistsList(context, storage),

                  const SliverToBoxAdapter(child: SizedBox(height: 140)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentCard(BuildContext context, Map<String, String> track, int index) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: () {
          context.read<AudioBloc>().add(
                AudioPlayQueue(_recentlyPlayed, startIndex: index),
              );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: track['artworkUrl'] ?? '',
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 110,
                      height: 110,
                      color: YTColors.surfaceLight,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 110,
                      height: 110,
                      color: YTColors.surfaceLight,
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white54,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => SharedUI.showTrackOptions(context, track),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              track['title'] ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              track['artist'] ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: YTColors.secondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsList(BuildContext context, StorageState storage) {
    final playlistNames = storage.playlists.keys.toList();
    if (playlistNames.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: YTColors.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'No custom playlists found',
                style: TextStyle(color: YTColors.secondary, fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final playlistName = playlistNames[index];
          final tracks = storage.playlists[playlistName] ?? [];
          final count = tracks.length;
          final firstArt = tracks.isNotEmpty ? (tracks.first['artworkUrl'] ?? '') : '';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaylistScreen(playlistName: playlistName),
                  ),
                );
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: firstArt.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: firstArt,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _fallbackPlaylistArt(index),
                      ),
                    )
                  : _fallbackPlaylistArt(index),
              title: Text(
                playlistName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '$count ${count == 1 ? 'song' : 'songs'}',
                style: const TextStyle(color: YTColors.secondary, fontSize: 13),
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                color: YTColors.surfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'delete') {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: YTColors.surfaceLight,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Delete Playlist', style: TextStyle(color: Colors.white)),
                        content: Text(
                          'Are you sure you want to delete "$playlistName"? This cannot be undone.',
                          style: const TextStyle(color: YTColors.secondary, fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              context.read<StorageBloc>().add(StorageDeletePlaylist(playlistName));
                              Navigator.pop(dialogCtx);
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        SizedBox(width: 12),
                        Text('Delete Playlist', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: playlistNames.length,
      ),
    );
  }

  Widget _fallbackPlaylistArt(int index) {
    final colors = [
      [const Color(0xFFE65100), const Color(0xFF880E4F)],
      [const Color(0xFF1A237E), const Color(0xFF0D47A1)],
      [const Color(0xFFAD1457), const Color(0xFF4A148C)],
      [const Color(0xFF1B5E20), const Color(0xFF004D40)],
    ];
    final pair = colors[index % colors.length];
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: pair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.queue_music_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
