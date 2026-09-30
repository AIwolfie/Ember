import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_event.dart';
import '../blocs/storage/storage_state.dart';
import '../services/python_service.dart';
import '../theme.dart';
import '../utils/result.dart';
import '../widgets/playlist_sheet.dart';
import '../widgets/shared_ui.dart';
import 'history_screen.dart';
import 'playlist_screen.dart';
import 'about_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, EmberThemeOption>(
      builder: (context, themeOption) {
        return BlocBuilder<StorageBloc, StorageState>(
          builder: (context, storage) {
            int customPlaylistsCount = storage.playlists.length;
            int favoritesCount = storage.favorites.length;

            return Scaffold(
              backgroundColor: YTColors.background,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Cinematic Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 60,
                    bottom: 24,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    children: [
                      // Avatar with glow
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [YTColors.primary, Colors.deepPurpleAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: YTColors.primary.withValues(alpha: 0.3),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: YTColors.surfaceLight,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 60,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Your Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$customPlaylistsCount Playlists  •  $favoritesCount Favorites',
                        style: const TextStyle(
                          color: YTColors.secondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bento Grid for Actions
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildBentoCard(
                      context,
                      title: 'History',
                      icon: Icons.history_rounded,
                      color: Colors.blueAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      ),
                    ),
                    _buildBentoCard(
                      context,
                      title: 'Favorites',
                      icon: Icons.favorite_rounded,
                      color: Colors.redAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const PlaylistScreen(playlistName: 'Favorites'),
                        ),
                      ),
                    ),
                    _buildBentoCard(
                      context,
                      title: 'New Playlist',
                      icon: Icons.add_circle_outline_rounded,
                      color: Colors.greenAccent,
                      onTap: () => showPlaylistSheet(context),
                    ),
                    _buildBentoCard(
                      context,
                      title: 'Import',
                      icon: Icons.link_rounded,
                      color: YTColors.primary,
                      onTap: () => _showImportPlaylistDialog(context),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Recently Played UI
              if (storage.playHistory.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SharedUI.buildSectionTitle(
                    'Recently Played',
                    onMoreTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: SharedUI.buildHorizontalList(
                    storage.playHistory,
                    listId: 'history',
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],

              // Custom Playlists (Your Library)
              SliverToBoxAdapter(
                child: SharedUI.buildSectionTitle('Your Library'),
              ),

              if (storage.playlists.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Center(
                      child: Text(
                        'No custom playlists yet.',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final key = storage.playlists.keys.elementAt(index);
                      final list = storage.playlists[key]!;
                      final firstArt = list.isNotEmpty
                          ? (list.first['artworkUrl'] ?? '')
                          : '';
                      return _buildCustomPlaylistItem(
                        context: context,
                        title: key,
                        subtitle: '${list.length} songs',
                        imageUrl: firstArt,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistScreen(playlistName: key),
                            ),
                          );
                        },
                      );
                    }, childCount: storage.playlists.length),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 48)),

              // About the Developers (Premium Card)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildAboutCard(context),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 150)),
            ],
          ),
        );
      },
      );
    });
  }

  Widget _buildBentoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: YTColors.surfaceLight,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: -16,
                bottom: -16,
                child: Icon(
                  icon,
                  size: 80,
                  color: color.withValues(alpha: 0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPlaylistItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: YTColors.surfaceLight.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            placeholder: (c, u) =>
                Container(width: 56, height: 56, color: YTColors.surfaceLight),
            errorWidget: (c, err, s) => Container(
              width: 56,
              height: 56,
              color: YTColors.surfaceLight,
              child: const Icon(Icons.queue_music, color: YTColors.secondary),
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: YTColors.secondary, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white38,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          );
        },
        borderRadius: BorderRadius.circular(32),
        child: Container(
          decoration: BoxDecoration(
            color: YTColors.surfaceLight,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                YTColors.primary.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: YTColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: YTColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Ember',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Features, Open Source, and Credits',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white24,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImportPlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: YTColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Import Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'URL (YT Music, YouTube, Spotify)',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: YTColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: CircularProgressIndicator(color: YTColors.primary),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (controller.text.trim().isEmpty) return;
                          setState(() => isLoading = true);
                          final res = await PythonService.importPlaylist(
                            controller.text.trim(),
                          );
                          setState(() => isLoading = false);
                          Navigator.pop(ctx);
                          if (res is Success<Map<String, dynamic>>) {
                            final data = res.data;
                            final title = data['title'] as String;
                            final tracksRaw = data['tracks'] as List<dynamic>;
                            final tracks = tracksRaw
                                .map(
                                  (e) => (e as Map).map(
                                    (k, v) => MapEntry(
                                      k.toString(),
                                      v?.toString() ?? '',
                                    ),
                                  ),
                                )
                                .toList();
                            if (tracks.isNotEmpty) {
                              context.read<StorageBloc>().add(
                                StorageImportPlaylist(
                                  name: title,
                                  tracks: tracks,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Imported ${tracks.length} tracks into "$title"',
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No tracks found.'),
                                ),
                              );
                            }
                          } else if (res is Failure) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  (res as Failure<Map<String, dynamic>>)
                                      .message,
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: YTColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Import',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
