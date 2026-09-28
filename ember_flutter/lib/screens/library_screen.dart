import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/audio/audio_bloc.dart';
import '../blocs/audio/audio_event.dart';
import '../blocs/download/download_bloc.dart';
import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_event.dart';
import '../blocs/storage/storage_state.dart';
import '../services/python_service.dart';
import '../theme.dart';
import '../utils/result.dart';
import '../widgets/playlist_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/shared_ui.dart';
import 'playlist_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedFilter = 'Playlists';

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

              // Category Filter Chips: Playlists and Favorites ONLY
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildFilterPill('Playlists', Icons.queue_music_rounded),
                        const SizedBox(width: 10),
                        _buildFilterPill(
                          'Favorites',
                          Icons.favorite_rounded,
                        ),
                        const SizedBox(width: 10),
                        _buildFilterPill(
                          'Downloads',
                          Icons.download_done_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Conditional view based on filter
              if (_selectedFilter == 'Favorites')
                ..._buildFavoritesOnlySlivers(context, storage)
              else if (_selectedFilter == 'Downloads')
                ..._buildDownloadsSlivers(context)
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

  // Composite Library View: User Playlists + Real Favorites
  List<Widget> _buildCompositeLibrarySlivers(
    BuildContext context,
    StorageState storage,
  ) {
    final playlistNames = storage.playlists.keys.toList();

    return [
      // 1. Playlists Header with Create and Import Actions
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
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
              const Spacer(),
              // [+ Create] Button
              InkWell(
                onTap: () => showPlaylistSheet(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: YTColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: YTColors.primary, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Create',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // [📥 Import] Button
              InkWell(
                onTap: () => _showImportPlaylistDialog(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: YTColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, color: YTColors.primary, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Import',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Playlists List or Empty State
      if (playlistNames.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: YTColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    size: 40,
                    color: YTColors.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No playlists created yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create your own custom playlist or import one from YouTube or Spotify.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: YTColors.secondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: YTColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () => showPlaylistSheet(context),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.link_rounded, size: 18),
                        label: const Text('Import Link'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () => _showImportPlaylistDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildPlaylistItem(
                context,
                storage,
                playlistNames[index],
                index,
              ),
              childCount: playlistNames.length,
            ),
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
              Row(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: YTColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
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

      // Real Favorites Horizontal Carousel or Empty State
      if (storage.favorites.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: YTColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white38,
                    size: 32,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No favorites yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tap ♡ on any song to save it to your favorites.',
                          style: TextStyle(color: YTColors.secondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverToBoxAdapter(
          child: SizedBox(
            height: 168,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: storage.favorites.length,
              itemBuilder: (context, index) {
                final track = storage.favorites[index];
                return _buildFavoriteCard(context, track, storage.favorites, index);
              },
            ),
          ),
        ),
    ];
  }

  // Playlist Item Widget
  Widget _buildPlaylistItem(
    BuildContext context,
    StorageState storage,
    String playlistName,
    int index,
  ) {
    final tracks = storage.playlists[playlistName] ?? [];
    final count = tracks.length;
    final firstArt = tracks.isNotEmpty ? (tracks.first['artworkUrl'] ?? '') : '';

    Widget leadingWidget;
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaylistScreen(playlistName: playlistName),
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
                        playlistName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count ${count == 1 ? 'song' : 'songs'}',
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
                    color: Colors.white70,
                    size: 24,
                  ),
                  onPressed: () {
                    if (tracks.isNotEmpty) {
                      context.read<AudioBloc>().add(
                        AudioPlayQueue(tracks, startIndex: 0),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () => _showPlaylistMenu(context, playlistName),
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
  Widget _buildFavoriteCard(
    BuildContext context,
    Map<String, String> track,
    List<Map<String, String>> allFavorites,
    int index,
  ) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: () {
          context.read<AudioBloc>().add(
            AudioPlayQueue(allFavorites, startIndex: index),
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

  // Favorites Only Filter View
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
            (context, index) {
              final track = storage.favorites[index];
              return _buildFavoriteTile(context, track, storage.favorites, index);
            },
            childCount: storage.favorites.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildFavoriteTile(
    BuildContext context,
    Map<String, String> track,
    List<Map<String, String>> list,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.read<AudioBloc>().add(
              AudioPlayQueue(list, startIndex: index),
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
                      AudioPlayQueue(list, startIndex: index),
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

  // Playlist Options Menu (Play / Delete)
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

  // Import Playlist Dialog for YouTube & Spotify Links
  void _showImportPlaylistDialog(BuildContext context) {
    final urlCtrl = TextEditingController();
    bool isImporting = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: YTColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.download_rounded, color: YTColors.primary, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Import Playlist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paste a YouTube, YouTube Music, or Spotify playlist URL to import all tracks into Ember.',
                    style: TextStyle(color: YTColors.secondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'https://music.youtube.com/playlist?list=...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: YTColors.surfaceLight,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste_rounded, color: Colors.white70),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            urlCtrl.text = data!.text!.trim();
                          }
                        },
                        tooltip: 'Paste from clipboard',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isImporting)
                    Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: YTColors.primary),
                          const SizedBox(height: 12),
                          const Text(
                            'Fetching and resolving playlist tracks...',
                            style: TextStyle(color: YTColors.secondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: YTColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          final url = urlCtrl.text.trim();
                          if (url.isEmpty) return;

                          setSheetState(() => isImporting = true);
                          final res = await PythonService.importPlaylist(url);

                          if (context.mounted) {
                            setSheetState(() => isImporting = false);
                            if (res is Success<Map<String, dynamic>>) {
                              final title = res.data['title']?.toString() ?? 'Imported Playlist';
                              final rawTracks = res.data['tracks'] as List<dynamic>? ?? [];
                              final tracks = rawTracks.map((e) {
                                final map = e as Map;
                                return map.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
                              }).toList();

                              if (tracks.isNotEmpty) {
                                context.read<StorageBloc>().add(
                                  StorageImportPlaylist(name: title, tracks: tracks),
                                );
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Imported "$title" with ${tracks.length} songs!'),
                                    backgroundColor: YTColors.surfaceLight,
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
                        child: const Text(
                          'Import Now',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildDownloadsSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Downloaded Music',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              BlocBuilder<DownloadBloc, DownloadState>(
                builder: (context, downloadState) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: YTColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${downloadState.downloadedTracks.length} tracks',
                      style: TextStyle(
                        color: YTColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      BlocBuilder<DownloadBloc, DownloadState>(
        builder: (context, downloadState) {
          final tracks = downloadState.downloadedTracks;
          if (tracks.isEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: YTColors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.download_for_offline_rounded, size: 48, color: YTColors.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'No offline downloads yet',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap the 3 dots on any song to download for offline playback.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: YTColors.secondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final trackList = tracks.map((d) => d['trackData'] as Map<String, String>).toList();

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final track = trackList[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: track['artworkUrl'] ?? '',
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                color: YTColors.surfaceLight,
                                child: const Icon(Icons.music_note, color: YTColors.secondary),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.download_done_rounded, color: Colors.greenAccent, size: 14),
                          ),
                        ],
                      ),
                      title: Text(
                        track['title'] ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: Text(
                        track['artist'] ?? 'Unknown Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: YTColors.secondary, fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white60),
                        onPressed: () => SharedUI.showTrackOptions(context, track),
                      ),
                      onTap: () => SharedUI.playFromList(context, trackList, index),
                    ),
                  ),
                );
              },
              childCount: trackList.length,
            ),
          );
        },
      ),
    ];
  }

}
