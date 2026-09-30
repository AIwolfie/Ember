import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ember_flutter/blocs/audio/audio_bloc.dart';
import 'package:ember_flutter/blocs/audio/audio_event.dart';
import 'package:ember_flutter/blocs/audio/audio_state.dart';
import 'package:ember_flutter/widgets/playlist_sheet.dart';

import 'package:ember_flutter/theme.dart';
import 'package:ember_flutter/blocs/storage/storage_bloc.dart';
import 'package:ember_flutter/blocs/storage/storage_event.dart';
import 'package:ember_flutter/screens/download/bloc/download_bloc.dart';
import 'package:ember_flutter/screens/artist/artist_screen.dart';
import 'package:ember_flutter/screens/playlist/playlist_screen.dart';
import 'package:ember_flutter/screens/player/full_player_screen.dart';

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
            style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          if (onMoreTap != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMoreTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    'More',
                    style: TextStyle(color: YTColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
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
                    leading: const Icon(Icons.playlist_play_rounded, color: Colors.white),
                    title: const Text(
                      'Play Next',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      context.read<AudioBloc>().add(AudioPlayNext(track));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Playing next in queue'), duration: Duration(seconds: 2)));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.queue_music_rounded, color: Colors.white),
                    title: const Text(
                      'Add to Queue',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      context.read<AudioBloc>().add(AudioAddToQueue(track));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to queue'), duration: Duration(seconds: 2)));
                    },
                  ),
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
                  BlocBuilder<DownloadBloc, DownloadState>(
                    builder: (context, downloadState) {
                      final videoId = track['videoId'] ?? '';
                      final isDownloaded = downloadState.isDownloaded(videoId);
                      final isDownloading = downloadState.isDownloading(videoId);

                      if (isDownloading) {
                        return ListTile(
                          leading: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: YTColors.primary)),
                          title: const Text(
                            'Downloading...',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        );
                      }

                      return ListTile(
                        leading: Icon(
                          isDownloaded ? Icons.delete_outline_rounded : Icons.download_rounded,
                          color: isDownloaded ? Colors.redAccent : Colors.white,
                        ),
                        title: Text(
                          isDownloaded ? 'Remove Download' : 'Download for Offline',
                          style: TextStyle(color: isDownloaded ? Colors.redAccent : Colors.white, fontWeight: FontWeight.w500),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (isDownloaded) {
                            context.read<DownloadBloc>().add(DownloadRemoveEvent(videoId));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed offline download')));
                          } else {
                            context.read<DownloadBloc>().add(DownloadStartEvent(track));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading for offline...')));
                          }
                        },
                      );
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

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const FullPlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.fastOutSlowIn));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  static Widget buildHorizontalList(List<Map<String, String>> items, {String listId = 'default'}) {
    if (items.isEmpty) return const SizedBox.shrink();
    final bool isArtistList = items.first['type'] == 'artist';
    final double itemWidth = isArtistList ? 116 : 140;

    return SizedBox(
      height: isArtistList ? 176 : 220,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final track = items[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            width: itemWidth,
            child: Material(
              color: Colors.transparent,
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
                          borderRadius: BorderRadius.circular(track['type'] == 'artist' ? itemWidth / 2 : 12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: track['artworkUrl'] ?? track['image'] ?? '',
                                width: itemWidth,
                                fit: BoxFit.cover,
                                placeholder: (c, u) => Container(width: itemWidth, color: YTColors.surfaceLight),
                                errorWidget: (context, error, stackTrace) => Container(
                                  width: itemWidth,
                                  color: YTColors.surfaceLight,
                                  child: Icon(track['type'] == 'artist' ? Icons.person : Icons.music_note, color: YTColors.secondary, size: isArtistList ? 36 : 48),
                                ),
                              ),
                              BlocBuilder<AudioBloc, AudioState>(
                                builder: (context, audioState) {
                                  if (audioState.currentTrack?['videoId'] == track['videoId']) {
                                    return Container(
                                      color: Colors.black54,
                                      child: Center(child: Icon(Icons.equalizer, color: YTColors.primary, size: 48)),
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
                      textAlign: isArtistList ? TextAlign.center : TextAlign.start,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isArtistList) const SizedBox(height: 4),
                    if (!isArtistList)
                      Text(
                        track['artist'] ?? '',
                        style: const TextStyle(color: YTColors.secondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget buildQuickPicksGrid(BuildContext context, List<Map<String, String>> items, {int numRows = 4}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SwipeableQuickPicksGrid(items: items, numRows: numRows);
  }
}

class SwipeableQuickPicksGrid extends StatefulWidget {
  final List<Map<String, String>> items;
  final int numRows;
  const SwipeableQuickPicksGrid({super.key, required this.items, this.numRows = 4});

  @override
  State<SwipeableQuickPicksGrid> createState() => _SwipeableQuickPicksGridState();
}

class _SwipeableQuickPicksGridState extends State<SwipeableQuickPicksGrid> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int numRows = widget.numRows;
    final List<List<Map<String, String>>> chunks = [];
    for (var i = 0; i < widget.items.length; i += numRows) {
      chunks.add(widget.items.sublist(i, i + numRows > widget.items.length ? widget.items.length : i + numRows));
      if (chunks.length == 4) break;
    }

    // Determine safe height based on row count
    final double gridHeight = (numRows == 2) ? 144 : 265;

    return Column(
      children: [
        SizedBox(
          height: gridHeight,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: chunks.length,
            itemBuilder: (context, chunkIndex) {
              final chunk = chunks[chunkIndex];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: chunk.asMap().entries.map((entry) {
                    final track = entry.value;
                    final internalIndex = (chunkIndex * numRows) + entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => SharedUI.handleItemTap(context, track, widget.items, internalIndex),
                          onLongPress: () => SharedUI.showTrackOptions(context, track),
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
                                              child: Center(child: Icon(Icons.equalizer, color: YTColors.primary, size: 28)),
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
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
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
                                onPressed: () => SharedUI.showTrackOptions(context, track),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        if (chunks.length > 1) const SizedBox(height: 8),
        if (chunks.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(chunks.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                height: 6.0,
                width: isActive ? 18.0 : 6.0,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.white24,
                  borderRadius: BorderRadius.circular(3.0),
                ),
              );
            }),
          ),
      ],
    );
  }
}
