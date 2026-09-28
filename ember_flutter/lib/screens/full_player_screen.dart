import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../blocs/audio/audio_bloc.dart';
import '../blocs/audio/audio_event.dart';
import '../blocs/audio/audio_state.dart';
import '../blocs/download/download_bloc.dart';
import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_event.dart';
import '../blocs/storage/storage_state.dart';
import '../services/python_service.dart';
import '../services/sleep_timer_service.dart';
import '../theme.dart';
import '../utils/result.dart';
import '../widgets/playback_speed_sheet.dart';
import '../widgets/playlist_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  String _formatDuration(Duration? duration) {
    if (duration == null) return "0:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _showUpNextSheet(BuildContext context, AudioBloc audioBloc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, controller) {
                return Container(
                  color: YTColors.surface.withValues(alpha: 0.85),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const Text(
                        'Up Next',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: BlocBuilder<AudioBloc, AudioState>(
                          bloc: audioBloc,
                          builder: (context, audioState) {
                            return ReorderableListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: audioState.queue.length,
                              onReorderItem: (oldIndex, newIndex) {
                                if (oldIndex < newIndex) {
                                  newIndex -= 1;
                                }
                                final item = audioState.queue.removeAt(
                                  oldIndex,
                                );
                                audioState.queue.insert(newIndex, item);
                                context.read<AudioBloc>().add(
                                  AudioUpdateQueue(audioState.queue),
                                );
                              },
                              itemBuilder: (context, index) {
                                final queueTrack = audioState.queue[index];
                                final isCurrent =
                                    queueTrack['videoId'] ==
                                    audioState.currentTrack?['videoId'];
                                return ListTile(
                                  key: ValueKey(
                                    '${queueTrack['videoId']}_$index',
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 4,
                                  ),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: queueTrack['artworkUrl'] ?? '',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 48,
                                        height: 48,
                                        color: YTColors.surfaceLight,
                                      ),
                                      errorWidget:
                                          (context, error, stackTrace) =>
                                              Container(
                                                width: 48,
                                                height: 48,
                                                color: YTColors.surfaceLight,
                                              ),
                                    ),
                                  ),
                                  title: Text(
                                    queueTrack['title'] ?? 'Unknown',
                                    style: TextStyle(
                                      color: isCurrent
                                          ? YTColors.primary
                                          : YTColors.secondary,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${queueTrack['artist']} • ${queueTrack['duration'] ?? ''}',
                                    style: const TextStyle(
                                      color: YTColors.disabled,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: isCurrent
                                      ? Icon(
                                          Icons.volume_up,
                                          color: YTColors.primary,
                                        )
                                      : const Icon(
                                          Icons.drag_handle,
                                          color: YTColors.disabled,
                                        ),
                                  onTap: () {
                                    context.read<AudioBloc>().add(
                                      AudioJumpToQueueIndex(index),
                                    );
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioBloc, AudioState>(
      builder: (context, state) {
        final track = state.currentTrack;

        if (track == null) {
          return Scaffold(
            backgroundColor: YTColors.background,
            body: Center(
              child: Text(
                "No track playing",
                style: TextStyle(color: YTColors.primary),
              ),
            ),
          );
        }

        final audioBloc = context.read<AudioBloc>();
        final screenWidth = MediaQuery.of(context).size.width;
        final artSize = (screenWidth - 56).clamp(240.0, 360.0);

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Playback Speed
              IconButton(
                tooltip: 'Playback Speed',
                icon: const Icon(Icons.speed_rounded, color: Colors.white70),
                onPressed: () => showPlaybackSpeedSheet(context, audioBloc),
              ),
              // Sleep Timer
              ValueListenableBuilder<bool>(
                valueListenable: SleepTimerService.instance.isActiveNotifier,
                builder: (context, isActive, _) {
                  return IconButton(
                    tooltip: 'Sleep Timer',
                    icon: Icon(
                      isActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                      color: isActive ? YTColors.primary : Colors.white70,
                    ),
                    onPressed: () => showSleepTimerSheet(context, audioBloc),
                  );
                },
              ),
              // Queue / Up Next
              IconButton(
                tooltip: 'Up Next',
                icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
                onPressed: () => _showUpNextSheet(context, audioBloc),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: track['artworkUrl'] ?? '',
                  fit: BoxFit.cover,
                  errorWidget: (context, error, stackTrace) => const SizedBox(),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.black.withValues(alpha: 0.55)),
                ),
              ),
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(seconds: 1),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        state.dominantColor?.withValues(alpha: 0.6) ??
                            Colors.transparent,
                        YTColors.background,
                      ],
                      stops: const [0.2, 1.0],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      // Album Art
                      Center(
                        child: Container(
                          width: artSize,
                          height: artSize,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: track['artworkUrl'] ?? '',
                              fit: BoxFit.cover,
                              errorWidget: (context, error, stack) =>
                                  Container(
                                    color: YTColors.surface,
                                    child: const Icon(
                                      Icons.music_note,
                                      color: YTColors.secondary,
                                      size: 80,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title and Artist
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track['title'] ?? 'Unknown Title',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  track['artist'] ?? 'Unknown Artist',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Pill Action Row (Like, Save, Download)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            BlocBuilder<StorageBloc, StorageState>(
                              builder: (context, storageState) {
                                final isFav = storageState.isFavorite(
                                  track['videoId'] ?? '',
                                );
                                return _buildPillButton(
                                  icon: isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  label: 'Like',
                                  color: isFav ? Colors.redAccent : null,
                                  onTap: () => context.read<StorageBloc>().add(
                                    StorageToggleFavorite(track),
                                  ),
                                );
                              },
                            ),
                            _buildPillButton(
                              icon: Icons.playlist_add,
                              label: 'Save',
                              onTap: () =>
                                  showPlaylistSheet(context, track: track),
                            ),
                            BlocBuilder<DownloadBloc, DownloadState>(
                              builder: (context, downloadState) {
                                final videoId = track['videoId'] ?? '';
                                final isDownloaded = downloadState.isDownloaded(videoId);
                                final isDownloading = downloadState.isDownloading(videoId);

                                return _buildPillButton(
                                  icon: isDownloaded
                                      ? Icons.download_done_rounded
                                      : (isDownloading
                                          ? Icons.downloading_rounded
                                          : Icons.download_rounded),
                                  label: isDownloaded
                                      ? 'Downloaded'
                                      : (isDownloading ? 'Downloading...' : 'Download'),
                                  color: isDownloaded ? Colors.greenAccent : null,
                                  onTap: () {
                                    if (isDownloaded) {
                                      context.read<DownloadBloc>().add(
                                        DownloadRemoveEvent(videoId),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Removed offline download'),
                                        ),
                                      );
                                    } else if (!isDownloading) {
                                      context.read<DownloadBloc>().add(
                                        DownloadStartEvent(track),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Downloading for offline...'),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Progress Bar
                      StreamBuilder<Duration>(
                        stream: audioBloc.player.positionStream,
                        builder: (context, posSnap) {
                          return StreamBuilder<Duration?>(
                            stream: audioBloc.player.durationStream,
                            builder: (context, durSnap) {
                              final position = posSnap.data ?? Duration.zero;
                              final duration = durSnap.data ?? Duration.zero;

                              return Column(
                                children: [
                                  SliderTheme(
                                    data: YTTheme.darkTheme.sliderTheme
                                        .copyWith(
                                          trackHeight: 2,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 6,
                                              ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 14,
                                              ),
                                        ),
                                    child: Slider(
                                      min: 0.0,
                                      max:
                                          duration.inMilliseconds.toDouble() > 0
                                          ? duration.inMilliseconds.toDouble()
                                          : 1.0,
                                      value:
                                          (position.inMilliseconds.toDouble())
                                              .clamp(
                                                0.0,
                                                duration.inMilliseconds
                                                            .toDouble() >
                                                        0
                                                    ? duration.inMilliseconds
                                                          .toDouble()
                                                    : 1.0,
                                              ),
                                      onChanged: (value) {
                                        audioBloc.player.seek(
                                          Duration(milliseconds: value.round()),
                                        );
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(position),
                                          style: const TextStyle(
                                            color: YTColors.secondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: const TextStyle(
                                            color: YTColors.secondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 4),

                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.shuffle,
                              color: YTColors.secondary,
                            ),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.skip_previous,
                              color: YTColors.primary,
                              size: 40,
                            ),
                            onPressed: () =>
                                audioBloc.add(AudioSeekToPrevious()),
                          ),
                          Builder(
                            builder: (context) {
                              final playerState = state.playerState;
                              final processingState =
                                  playerState?.processingState;
                              final playing = playerState?.playing ?? false;

                              Widget playButton;
                              if (processingState == ProcessingState.loading ||
                                  processingState ==
                                      ProcessingState.buffering) {
                                playButton = Container(
                                  key: const ValueKey('loading'),
                                  margin: const EdgeInsets.all(8.0),
                                  width: 64.0,
                                  height: 64.0,
                                  child: CircularProgressIndicator(
                                    color: YTColors.primary,
                                  ),
                                );
                              } else if (playing) {
                                playButton = IconButton(
                                  key: const ValueKey('pause'),
                                  icon: Icon(
                                    Icons.pause_circle_filled,
                                    color: YTColors.primary,
                                  ),
                                  iconSize: 72.0,
                                  onPressed: () => audioBloc.add(AudioPause()),
                                );
                              } else {
                                playButton = IconButton(
                                  key: const ValueKey('play'),
                                  icon: Icon(
                                    Icons.play_circle_filled,
                                    color: YTColors.primary,
                                  ),
                                  iconSize: 72.0,
                                  onPressed: () => audioBloc.add(AudioResume()),
                                );
                              }

                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: playButton,
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.skip_next,
                              color: YTColors.primary,
                              size: 40,
                            ),
                            onPressed: () => audioBloc.add(AudioSeekToNext()),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.repeat,
                              color: YTColors.secondary,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Scroll Down For Lyrics Indicator
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Column(
                            children: const [
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white38,
                                size: 26,
                              ),
                              SizedBox(height: 2),
                              Text(
                                'SCROLL FOR LYRICS',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Dedicated Inline Lyrics Section (Scroll to reveal)
                      _InlineLyricsView(track: track, audioBloc: audioBloc),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: color ?? Colors.white, size: 20),
        label: Text(
          label,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onPressed: onTap,
      ),
    );
  }
}

class _InlineLyricsView extends StatelessWidget {
  final Map<String, String> track;
  final AudioBloc audioBloc;
  const _InlineLyricsView({required this.track, required this.audioBloc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: YTColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lyrics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                ),
              ),
              Icon(Icons.lyrics_rounded, color: YTColors.primary, size: 22),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<Result<String>>(
            future: PythonService.lyrics(
              track['videoId'] ?? '',
              title: track['title'] ?? '',
              artist: track['artist'] ?? '',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: YTColors.primary),
                  ),
                );
              }

              final result = snapshot.data;
              if (result is Success<String>) {
                final lrcRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
                final rawLines = result.data
                    .split('\n')
                    .where((l) => l.trim().isNotEmpty)
                    .toList();
                final List<Map<String, dynamic>> parsedLines = [];
                bool hasTimestamps = false;

                for (final line in rawLines) {
                  final match = lrcRegex.firstMatch(line);
                  if (match != null) {
                    hasTimestamps = true;
                    final min = int.parse(match.group(1)!);
                    final sec = int.parse(match.group(2)!);
                    final msData = match.group(3)!;
                    final ms = msData.length == 2
                        ? int.parse(msData) * 10
                        : int.parse(msData);
                    final duration = Duration(
                      minutes: min,
                      seconds: sec,
                      milliseconds: ms,
                    );
                    final text = match.group(4)!.trim();
                    parsedLines.add({'time': duration, 'text': text});
                  } else {
                    parsedLines.add({'time': null, 'text': line.trim()});
                  }
                }

                return StreamBuilder<Duration>(
                  stream: audioBloc.player.positionStream,
                  builder: (context, posSnap) {
                    return StreamBuilder<Duration?>(
                      stream: audioBloc.player.durationStream,
                      builder: (context, durSnap) {
                        final pos = posSnap.data ?? Duration.zero;
                        final dur = durSnap.data ?? Duration.zero;

                        int activeIndex = 0;
                        if (hasTimestamps) {
                          for (int i = 0; i < parsedLines.length; i++) {
                            if (parsedLines[i]['time'] != null &&
                                pos >= (parsedLines[i]['time'] as Duration)) {
                              activeIndex = i;
                            }
                          }
                        } else {
                          final progress = dur.inMilliseconds > 0
                              ? (pos.inMilliseconds / dur.inMilliseconds)
                                    .clamp(0.0, 1.0)
                              : 0.0;
                          activeIndex = (progress * parsedLines.length)
                              .floor()
                              .clamp(
                                0,
                                parsedLines.isNotEmpty
                                    ? parsedLines.length - 1
                                    : 0,
                              );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: parsedLines.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final isActive = idx == activeIndex;
                            final text = item['text'] as String;
                            if (text.isEmpty) {
                              return const SizedBox(height: 16);
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6.0,
                              ),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: isActive ? 22 : 17,
                                  height: 1.4,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                                child: Text(text),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                );
              } else {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No lyrics found for this song.',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
