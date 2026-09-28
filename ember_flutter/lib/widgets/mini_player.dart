import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../screens/full_player_screen.dart';
import '../blocs/audio/audio_bloc.dart';
import '../blocs/audio/audio_event.dart';
import '../blocs/audio/audio_state.dart';
import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_event.dart';
import '../blocs/storage/storage_state.dart';
import '../theme.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioBloc, AudioState>(
      builder: (context, state) {
        final track = state.currentTrack;

        if (track == null) {
          return const SizedBox.shrink();
        }

        final playerState = state.playerState;
        final playing = playerState?.playing ?? false;
        final processingState = playerState?.processingState;

        final audioBloc = context.read<AudioBloc>();

        return GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -300) {
                // Swipe up
                _openFullPlayer(context);
              } else if (details.primaryVelocity! > 300) {
                // Swipe down to dismiss
                audioBloc.add(AudioStop());
              }
            }
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -300) {
                audioBloc.add(AudioSeekToNext());
              } else if (details.primaryVelocity! > 300) {
                audioBloc.add(AudioSeekToPrevious());
              }
            }
          },
          onTap: () => _openFullPlayer(context),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                color:
                    state.dominantColor?.withValues(alpha: 0.75) ??
                    YTColors.surface.withValues(alpha: 0.85),
                height: 64,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: track['artworkUrl'] ?? '',
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(
                                width: 44,
                                height: 44,
                                color: YTColors.surfaceLight,
                              ),
                              errorWidget: (c, e, s) => Container(
                                width: 44,
                                height: 44,
                                color: YTColors.surfaceLight,
                                child: const Icon(
                                  Icons.music_note,
                                  color: YTColors.secondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  track['title'] ?? 'Unknown',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: YTColors.primary,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track['artist'] ?? 'Unknown Artist',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: YTColors.secondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          BlocBuilder<StorageBloc, StorageState>(
                            builder: (context, storage) {
                              final isFav = storage.isFavorite(
                                track['videoId']!,
                              );
                              return IconButton(
                                icon: Icon(
                                  isFav
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_outlined,
                                  color: YTColors.primary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  context.read<StorageBloc>().add(
                                    StorageToggleFavorite(track),
                                  );
                                },
                              );
                            },
                          ),
                          Builder(
                            builder: (context) {
                              Widget playPauseBtn;
                              if (processingState == ProcessingState.loading ||
                                  processingState ==
                                      ProcessingState.buffering) {
                                playPauseBtn = Padding(
                                  key: const ValueKey('loading'),
                                  padding: const EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: YTColors.primary,
                                    ),
                                  ),
                                );
                              } else if (playing) {
                                playPauseBtn = IconButton(
                                  key: const ValueKey('pause'),
                                  icon: Icon(
                                    Icons.pause,
                                    color: YTColors.primary,
                                    size: 28,
                                  ),
                                  onPressed: () => audioBloc.add(AudioPause()),
                                );
                              } else {
                                playPauseBtn = IconButton(
                                  key: const ValueKey('play'),
                                  icon: Icon(
                                    Icons.play_arrow,
                                    color: YTColors.primary,
                                    size: 28,
                                  ),
                                  onPressed: () => audioBloc.add(AudioResume()),
                                );
                              }
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: playPauseBtn,
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.skip_next,
                              color: YTColors.primary,
                              size: 28,
                            ),
                            onPressed: () => audioBloc.add(AudioSeekToNext()),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: StreamBuilder<Duration>(
                        stream: audioBloc.player.positionStream,
                        builder: (context, posSnap) {
                          return StreamBuilder<Duration?>(
                            stream: audioBloc.player.durationStream,
                            builder: (context, durSnap) {
                              final duration = durSnap.data ?? Duration.zero;
                              final position = posSnap.data ?? Duration.zero;
                              double progress = 0.0;
                              if (duration.inMilliseconds > 0) {
                                progress =
                                    position.inMilliseconds /
                                    duration.inMilliseconds;
                                progress = progress.clamp(0.0, 1.0);
                              }
                              return LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  YTColors.primary,
                                ),
                                minHeight: 1.5,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFullPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (context) => const FullPlayerScreen(),
    );
  }
}
