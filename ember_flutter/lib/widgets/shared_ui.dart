import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/audio/audio_bloc.dart';
import '../blocs/audio/audio_event.dart';
import '../blocs/audio/audio_state.dart';
import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_event.dart';
import '../screens/full_player_screen.dart';
import '../theme.dart';
import 'playlist_sheet.dart';
import '../screens/artist_screen.dart';
import '../screens/playlist_screen.dart';

class SharedUI {
  static Widget buildSectionTitle(String title, {VoidCallback? onMoreTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          if (onMoreTap != null)
            InkWell(
              onTap: onMoreTap,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(
                  'More',
                  style: TextStyle(color: YTColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static void showTrackOptions(BuildContext context, Map<String, String> track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              color: YTColors.surface.withValues(alpha: 0.8),
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Wrap(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: track['artworkUrl'] ?? '',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorWidget: (context, error, stackTrace) => Container(
                              width: 48,
                              height: 48,
                              color: YTColors.surfaceLight,
                              child: const Icon(Icons.music_note, color: YTColors.secondary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track['title'] ?? 'Unknown',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track['artist'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: YTColors.secondary, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    leading: const Icon(Icons.favorite_border, color: Colors.white),
                    title: const Text(
                      'Toggle Favorite',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      context.read<StorageBloc>().add(StorageToggleFavorite(track));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated Favorites')));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add, color: Colors.white),
                    title: const Text(
                      'Add to Playlist',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      showPlaylistSheet(context, track: track);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void handleItemTap(BuildContext context, Map<String, String> track, List<Map<String, String>> contextItems, int index) {
    final type = track['type'] ?? 'song';
    if (type == 'artist') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistScreen(artistInfo: track)));
    } else if (type == 'playlist' || type == 'album' || type == 'podcast') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistScreen(playlistName: track['title'] ?? 'Playlist', remoteIdentifier: track['browseId'] ?? track['videoId']),
        ),
      );
    } else {
      playFromList(context, contextItems, index);
    }
  }

  static void playFromList(BuildContext context, List<Map<String, String>> list, int index) {
    context.read<AudioBloc>().add(AudioPlayQueue(list, startIndex: index));
    context.read<StorageBloc>().add(StorageAddPlayHistory(list[index]));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (context) => const FullPlayerScreen(),
    );
  }

  static Widget buildHorizontalList(List<Map<String, String>> items, {String listId = 'default'}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 220,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final track = items[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            width: 140,
            child: InkWell(
              onLongPress: () => showTrackOptions(context, track),
              onTap: () => handleItemTap(context, track, items, index),
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.white12,
              highlightColor: Colors.white10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Hero(
                      tag: 'album_art_${track['videoId']}_${listId}_$index',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: track['artworkUrl'] ?? '',
                              width: 140,
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(width: 140, color: YTColors.surfaceLight),
                              errorWidget: (context, error, stackTrace) => Container(
                                width: 140,
                                color: YTColors.surfaceLight,
                                child: const Icon(Icons.music_note, color: YTColors.secondary, size: 48),
                              ),
                            ),
                            BlocBuilder<AudioBloc, AudioState>(
                              builder: (context, audioState) {
                                if (audioState.currentTrack?['videoId'] == track['videoId']) {
                                  return Container(
                                    color: Colors.black54,
                                    child: const Center(child: Icon(Icons.equalizer, color: Colors.white, size: 48)),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    track['title'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track['artist'] ?? '',
                    style: const TextStyle(color: YTColors.secondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget buildQuickPicksGrid(BuildContext context, List<Map<String, String>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Instead of completely generic layout, this 3-row grid mimics YT Music closely
    const int numRows = 3;
    final List<List<Map<String, String>>> chunks = [];
    for (var i = 0; i < items.length; i += numRows) {
      chunks.add(items.sublist(i, i + numRows > items.length ? items.length : i + numRows));
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: chunks.length,
        itemBuilder: (context, chunkIndex) {
          final chunk = chunks[chunkIndex];
          return SizedBox(
            width: MediaQuery.of(context).size.width * 0.88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: chunk.asMap().entries.map((entry) {
                final track = entry.value;
                final internalIndex = (chunkIndex * numRows) + entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
                  child: InkWell(
                    onTap: () => handleItemTap(context, track, items, internalIndex),
                    onLongPress: () => showTrackOptions(context, track),
                    borderRadius: BorderRadius.circular(8),
                    splashColor: Colors.white12,
                    highlightColor: Colors.white10,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: track['artworkUrl'] ?? '',
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => Container(color: YTColors.surfaceLight),
                                  errorWidget: (c, e, s) => Container(
                                    color: YTColors.surfaceLight,
                                    child: const Icon(Icons.music_note, color: Colors.white54, size: 24),
                                  ),
                                ),
                                BlocBuilder<AudioBloc, AudioState>(
                                  builder: (context, audioState) {
                                    if (audioState.currentTrack?['videoId'] == track['videoId']) {
                                      return Container(
                                        color: Colors.black54,
                                        child: const Center(child: Icon(Icons.equalizer, color: Colors.white, size: 28)),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                track['title'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track['artist'] ?? '',
                                style: const TextStyle(color: YTColors.secondary, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                          onPressed: () => showTrackOptions(context, track),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
