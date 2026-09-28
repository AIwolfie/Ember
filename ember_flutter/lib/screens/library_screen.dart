import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/audio/audio_bloc.dart';
import '../blocs/audio/audio_event.dart';
import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_event.dart';
import '../blocs/storage/storage_state.dart';
import '../theme.dart';
import '../widgets/playlist_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/shared_ui.dart';
import 'history_screen.dart';
import 'playlist_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedFilter = 'Playlists';

  // Curated starter playlists matching the Ember design aesthetic
  static const List<Map<String, dynamic>> _curatedPlaylists = [
    {
      'name': 'Chill Vibes',
      'count': 42,
      'gradient': [Color(0xFFE65100), Color(0xFF880E4F)],
      'icon': Icons.wb_twilight_rounded,
    },
    {
      'name': 'Late Night',
      'count': 36,
      'gradient': [Color(0xFF1A237E), Color(0xFF0D47A1)],
      'icon': Icons.nightlight_round,
    },
    {
      'name': 'Workout Mode',
      'count': 28,
      'gradient': [Color(0xFFAD1457), Color(0xFF4A148C)],
      'icon': Icons.bolt_rounded,
    },
    {
      'name': 'Focus',
      'count': 21,
      'gradient': [Color(0xFF1B5E20), Color(0xFF004D40)],
      'icon': Icons.spa_rounded,
    },
    {
      'name': 'My Mix',
      'count': 58,
      'gradient': [Color(0xFFE65100), Color(0xFFBF360C)],
      'icon': Icons.whatshot_rounded,
    },
  ];

  // Curated sample favorites matching screenshot when empty
  static const List<Map<String, String>> _sampleFavorites = [
    {
      'videoId': 'sample_1',
      'title': 'arijit singh songs',
      'artist': 'Arijit Singh',
      'artworkUrl': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300&q=80',
    },
    {
      'videoId': 'sample_2',
      'title': 'Kesariya',
      'artist': 'Arijit Singh',
      'artworkUrl': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300&q=80',
    },
    {
      'videoId': 'sample_3',
      'title': 'Phir Kabhi',
      'artist': 'Arijit Singh',
      'artworkUrl': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300&q=80',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StorageBloc, StorageState>(
      builder: (context, storage) {
        return Scaffold(
          backgroundColor: YTColors.background,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Top Bar: Flame + Ember & Settings
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 20,
                    right: 16,
                    bottom: 8,
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
                        tooltip: 'Settings & Themes',
                      ),
                    ],
                  ),
                ),
              ),

              // Title: "Your Library"
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

              // Category Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildFilterPill('Playlists', Icons.music_note_rounded),
                        const SizedBox(width: 10),
                        _buildFilterPill(
                          'Favorites',
                          Icons.favorite_border_rounded,
                        ),
                        const SizedBox(width: 10),
                        _buildFilterPill('History', Icons.access_time_rounded),
                        const SizedBox(width: 10),
                        _buildFilterPill('Downloads', Icons.download_rounded),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Conditional view based on filter or default composite view
              if (_selectedFilter == 'Favorites')
                ..._buildFavoritesOnlySlivers(context, storage)
              else if (_selectedFilter == 'History')
                ..._buildHistoryOnlySlivers(context, storage)
              else if (_selectedFilter == 'Downloads')
                ..._buildDownloadsOnlySlivers(context)
              else
                ..._buildCompositeLibrarySlivers(context, storage),

              // Bottom padding for mini player
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
        );
      },
    );
  }

  // Filter Pill Button
  Widget _buildFilterPill(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? YTColors.primary
              : YTColors.surfaceLight.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? YTColors.primary
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Composite Library View (Matching Image 2)
  List<Widget> _buildCompositeLibrarySlivers(
    BuildContext context,
    StorageState storage,
  ) {
    return [
      // 1. Playlists Header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Playlists',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                ),
              ),
              InkWell(
                onTap: () => _showAllPlaylistsDialog(context, storage),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          color: YTColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: YTColors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Playlists List
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return _buildPlaylistItem(context, storage, index);
          }, childCount: _getPlaylistCount(storage)),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 24)),

      // 2. Favorites Section Header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Favorites',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PlaylistScreen(playlistName: 'Favorites'),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          color: YTColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: YTColors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Favorites Horizontal Carousel
      SliverToBoxAdapter(
        child: SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: storage.favorites.isNotEmpty
                ? storage.favorites.length
                : _sampleFavorites.length,
            itemBuilder: (context, index) {
              final track = storage.favorites.isNotEmpty
                  ? storage.favorites[index]
                  : _sampleFavorites[index];
              return _buildFavoriteCard(context, track);
            },
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 24)),

      // 3. Recently Played Section Header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Recently Played',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          color: YTColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: YTColors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Recently Played Track Item
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final track = storage.playHistory.isNotEmpty
                  ? storage.playHistory[index]
                  : {
                      'videoId': 'sample_weeknd',
                      'title': 'The Weeknd - Blinding Lights',
                      'artist': 'The Weeknd',
                      'artworkUrl': 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=300&q=80',
                    };
              return _buildRecentTrackTile(context, track);
            },
            childCount: storage.playHistory.isNotEmpty
                ? (storage.playHistory.length > 5
                      ? 5
                      : storage.playHistory.length)
                : 1,
          ),
        ),
      ),
    ];
  }

  int _getPlaylistCount(StorageState storage) {
    if (storage.playlists.isNotEmpty) {
      return storage.playlists.length;
    }
    return _curatedPlaylists.length;
  }

  Widget _buildPlaylistItem(
    BuildContext context,
    StorageState storage,
    int index,
  ) {
    String title;
    String subtitle;
    Widget leadingWidget;

    if (storage.playlists.isNotEmpty) {
      final key = storage.playlists.keys.elementAt(index);
      final tracks = storage.playlists[key]!;
      title = key;
      subtitle = '${tracks.length} songs';
      final firstArt = tracks.isNotEmpty
          ? (tracks.first['artworkUrl'] ?? '')
          : '';

      if (firstArt.isNotEmpty) {
        leadingWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: firstArt,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _fallbackPlaylistArt(index),
          ),
        );
      } else {
        leadingWidget = _fallbackPlaylistArt(index);
      }
    } else {
      final item = _curatedPlaylists[index];
      title = item['name'] as String;
      subtitle = '${item['count']} songs';
      leadingWidget = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: item['gradient'] as List<Color>,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(item['icon'] as IconData, color: Colors.white, size: 22),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaylistScreen(playlistName: title),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: YTColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                leadingWidget,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: YTColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () => _showPlaylistMenu(context, title),
                ),
              ],
            ),
          ),
        ),
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: pair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.queue_music_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }

  // Favorite Card in Horizontal Carousel
  Widget _buildFavoriteCard(BuildContext context, Map<String, String> track) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: () {
          context.read<AudioBloc>().add(AudioPlayQueue([track], startIndex: 0));
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
                        decoration: BoxDecoration(
                          color: Colors.black38,
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

  // Recent Track Tile
  Widget _buildRecentTrackTile(
    BuildContext context,
    Map<String, String> track,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.read<AudioBloc>().add(
              AudioPlayQueue([track], startIndex: 0),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: YTColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: track['artworkUrl'] ?? '',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 48,
                      height: 48,
                      color: YTColors.surfaceLight,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: YTColors.surfaceLight,
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track['title'] ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track['artist'] ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: YTColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    context.read<AudioBloc>().add(
                      AudioPlayQueue([track], startIndex: 0),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () => SharedUI.showTrackOptions(context, track),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Filter Views
  List<Widget> _buildFavoritesOnlySlivers(
    BuildContext context,
    StorageState storage,
  ) {
    if (storage.favorites.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Center(
              child: Text(
                'No favorite tracks yet.\nTap ♡ on any song to save it here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: YTColors.secondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildRecentTrackTile(context, storage.favorites[index]),
            childCount: storage.favorites.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildHistoryOnlySlivers(
    BuildContext context,
    StorageState storage,
  ) {
    if (storage.playHistory.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Center(
              child: Text(
                'No listening history yet.',
                style: TextStyle(color: YTColors.secondary, fontSize: 15),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildRecentTrackTile(context, storage.playHistory[index]),
            childCount: storage.playHistory.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildDownloadsOnlySlivers(BuildContext context) {
    return [
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.download_done_rounded,
                  color: Colors.white24,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'No offline downloads yet.\nDownloaded tracks will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: YTColors.secondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  void _showPlaylistMenu(BuildContext context, String playlistName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: YTColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              title: Text(
                'Play "$playlistName"',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaylistScreen(playlistName: playlistName),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete Playlist',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                context.read<StorageBloc>().add(
                  StorageDeletePlaylist(playlistName),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted "$playlistName"')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAllPlaylistsDialog(BuildContext context, StorageState storage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: YTColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Playlists',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: YTColors.primary,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      showPlaylistSheet(context);
                    },
                    tooltip: 'New Playlist',
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _getPlaylistCount(storage),
                itemBuilder: (c, idx) =>
                    _buildPlaylistItem(context, storage, idx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
