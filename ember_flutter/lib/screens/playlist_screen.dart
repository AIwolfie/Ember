import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../blocs/audio/audio_bloc.dart';
import '../blocs/audio/audio_event.dart';
import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_event.dart';
import '../blocs/storage/storage_state.dart';
import '../services/python_service.dart';
import '../theme.dart';
import '../utils/result.dart';
import '../widgets/mini_player.dart';
import 'full_player_screen.dart';

class PlaylistScreen extends StatefulWidget {
  final String playlistName;
  final String? remoteIdentifier;

  const PlaylistScreen({
    super.key,
    required this.playlistName,
    this.remoteIdentifier,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  bool _isLoading = false;
  List<Map<String, String>> _remoteTracks = [];
  String? _remoteArt;

  @override
  void initState() {
    super.initState();
    if (widget.remoteIdentifier != null) {
      _fetchRemotePlaylist();
    }
  }

  Future<void> _fetchRemotePlaylist() async {
    setState(() => _isLoading = true);
    final res = await PythonService.importPlaylist(widget.remoteIdentifier!);
    if (mounted) {
      setState(() => _isLoading = false);
      if (res is Success<Map<String, dynamic>>) {
        final data = res.data;
        final rawTracks = data['tracks'] as List<dynamic>;
        _remoteTracks = rawTracks
            .map(
              (e) => (e as Map).map(
                (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
              ),
            )
            .toList();
        if (_remoteTracks.isNotEmpty)
          _remoteArt = _remoteTracks.first['artworkUrl'];
      } else if (res is Failure) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text((res as Failure).message)));
      }
    }
  }

  void _playAll(
    BuildContext context,
    List<Map<String, String>> tracks, {
    bool shuffle = false,
  }) {
    if (tracks.isEmpty) return;

    final queue = shuffle ? (tracks.toList()..shuffle()) : tracks;

    context.read<AudioBloc>().add(AudioPlayQueue(queue, startIndex: 0));
    context.read<StorageBloc>().add(StorageAddPlayHistory(queue.first));

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const FullPlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: Curves.fastOutSlowIn));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YTColors.background,
      body: BlocBuilder<StorageBloc, StorageState>(
        builder: (context, storageState) {
          final isRemote = widget.remoteIdentifier != null;
          final isFavs = widget.playlistName == 'Favorites';

          final tracks = isRemote
              ? _remoteTracks
              : (isFavs
                    ? storageState.favorites
                    : (storageState.playlists[widget.playlistName] ?? []));
          final firstArt = isRemote
              ? (_remoteArt ?? '')
              : (tracks.isNotEmpty ? (tracks.first['artworkUrl'] ?? '') : '');

          return Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 340,
                    pinned: true,
                    backgroundColor: YTColors.background,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      centerTitle: true,
                      title: Text(
                        widget.playlistName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (firstArt.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: firstArt,
                              fit: BoxFit.cover,
                              errorWidget: (c, e, s) => const SizedBox(),
                            ),
                          if (firstArt.isEmpty)
                            Container(color: YTColors.surfaceLight),
                          // Cinematic Blur Overlay
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black12, YTColors.background],
                                  stops: const [0.1, 1.0],
                                ),
                              ),
                            ),
                          ),
                          // Premium Centered Artwork
                          if (firstArt.isNotEmpty)
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 40),
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 40,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: firstArt,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    placeholder: (c, u) =>
                                        Container(color: YTColors.surfaceLight),
                                    errorWidget: (c, e, s) =>
                                        Container(color: YTColors.surfaceLight),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    actions: [
                      if (!isFavs && !isRemote)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            context.read<StorageBloc>().add(
                              StorageDeletePlaylist(widget.playlistName),
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Playlist deleted')),
                            );
                          },
                        ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 20.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: tracks.isEmpty
                                  ? null
                                  : () => _playAll(
                                      context,
                                      tracks,
                                      shuffle: false,
                                    ),
                              icon: Icon(
                                Icons.play_arrow,
                                color: YTColors.background,
                                size: 28,
                              ),
                              label: Text(
                                'Play',
                                style: TextStyle(
                                  color: YTColors.background,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: tracks.isEmpty
                                  ? null
                                  : () => _playAll(
                                      context,
                                      tracks,
                                      shuffle: true,
                                    ),
                              icon: const Icon(
                                Icons.shuffle,
                                color: Colors.white,
                                size: 28,
                              ),
                              label: const Text(
                                'Shuffle',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white24,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: YTColors.primary,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverReorderableList(
                      itemCount: tracks.length,
                      // ignore: deprecated_member_use
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        if (!isRemote && !isFavs) {
                          context.read<StorageBloc>().add(
                            StorageReorderPlaylist(
                              name: widget.playlistName,
                              oldIndex: oldIndex,
                              newIndex: newIndex,
                            ),
                          );
                        }
                      },
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        final isAddedFav = storageState.isFavorite(
                          track['videoId']!,
                        );
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey('${track['videoId']}_$index'),
                          index: index,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: track['artworkUrl'] ?? '',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                placeholder: (c, u) => Container(
                                  width: 48,
                                  height: 48,
                                  color: YTColors.surfaceLight,
                                ),
                                errorWidget: (c, e, s) => Container(
                                  width: 48,
                                  height: 48,
                                  color: YTColors.surface,
                                  child: const Icon(
                                    Icons.music_note,
                                    color: YTColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              track['title'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${track['artist']} • ${track['duration']}',
                              style: const TextStyle(color: YTColors.secondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isAddedFav)
                                  Icon(
                                    Icons.favorite,
                                    color: YTColors.primary,
                                    size: 20,
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: YTColors.secondary,
                                  ),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: YTColors.surface,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                      ),
                                      builder: (ctx) => Wrap(
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.playlist_play_rounded,
                                              color: Colors.white,
                                            ),
                                            title: const Text(
                                              'Play Next',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            onTap: () {
                                              context.read<AudioBloc>().add(
                                                AudioPlayNext(track),
                                              );
                                              Navigator.pop(ctx);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Playing next in queue',
                                                      ),
                                                      duration: Duration(
                                                        seconds: 2,
                                                      ),
                                                    ),
                                                  );
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.queue_music_rounded,
                                              color: Colors.white,
                                            ),
                                            title: const Text(
                                              'Add to Queue',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            onTap: () {
                                              context.read<AudioBloc>().add(
                                                AudioAddToQueue(track),
                                              );
                                              Navigator.pop(ctx);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Added to queue',
                                                      ),
                                                      duration: Duration(
                                                        seconds: 2,
                                                      ),
                                                    ),
                                                  );
                                            },
                                          ),
                                          if (!isAddedFav)
                                            ListTile(
                                              leading: const Icon(
                                                Icons.favorite_border,
                                                color: Colors.white,
                                              ),
                                              title: const Text(
                                                'Add to Favorites',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              onTap: () {
                                                Navigator.pop(ctx);
                                                context.read<StorageBloc>().add(
                                                  StorageToggleFavorite(track),
                                                );
                                              },
                                            )
                                          else
                                            ListTile(
                                              leading: const Icon(
                                                Icons.favorite,
                                                color: Colors.redAccent,
                                              ),
                                              title: const Text(
                                                'Remove from Favorites',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              onTap: () {
                                                Navigator.pop(ctx);
                                                context.read<StorageBloc>().add(
                                                  StorageToggleFavorite(track),
                                                );
                                              },
                                            ),
                                          if (!isFavs && !isRemote)
                                            ListTile(
                                              leading: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                              ),
                                              title: const Text(
                                                'Remove from playlist',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              onTap: () {
                                                Navigator.pop(ctx);
                                                context.read<StorageBloc>().add(
                                                  StorageRemoveFromPlaylist(
                                                    name: widget.playlistName,
                                                    videoId: track['videoId']!,
                                                  ),
                                                );
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Removed track',
                                                        ),
                                                      ),
                                                    );
                                              },
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                if (!isRemote && !isFavs)
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(
                                      Icons.drag_handle,
                                      color: YTColors.disabled,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              context.read<AudioBloc>().add(
                                AudioPlayQueue(tracks, startIndex: index),
                              );
                              context.read<StorageBloc>().add(
                                StorageAddPlayHistory(track),
                              );

                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                  ) => const FullPlayerScreen(),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        var tween =
                                            Tween(
                                              begin: const Offset(0.0, 1.0),
                                              end: Offset.zero,
                                            ).chain(
                                              CurveTween(
                                                curve: Curves.fastOutSlowIn,
                                              ),
                                            );
                                        return SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(top: false, child: MiniPlayer()),
              ),
            ],
          );
        },
      ),
    );
  }
}
