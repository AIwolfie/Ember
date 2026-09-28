import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../blocs/audio/audio_bloc.dart';
import '../blocs/audio/audio_event.dart';
import '../blocs/audio/audio_state.dart';
import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_event.dart';
import '../blocs/storage/storage_state.dart';
import '../services/python_service.dart';
import '../theme.dart';
import '../utils/result.dart';
import '../widgets/playlist_sheet.dart';

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
                  color: YTColors.surface.withValues(
                    alpha: 0.5,
                  ), // Glassmorphism base
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
                                    '${queueTrack['artist']} • ${queueTrack['duration']}',
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

  void _showLyricsSheet(
    BuildContext context,
    Map<String, String> track,
    AudioBloc audioBloc,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: _LyricsSheetContent(track: track, audioBloc: audioBloc),
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

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [],
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(flex: 1),
                      // Album Art
                      Expanded(
                        flex: 8,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
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
                        ),
                      ),
                      const Spacer(flex: 2),

                      // Title and Actions Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track['title'] ?? 'Unknown Title',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(
                                        fontSize: 26,
                                        color: Colors.white,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  track['artist'] ?? 'Unknown Artist',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontSize: 18,
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

                      const SizedBox(height: 12),

                      // Pill Action Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            BlocBuilder<StorageBloc, StorageState>(
                              builder: (context, storageState) {
                                final isFav = storageState.isFavorite(
                                  track['videoId']!,
                                );
                                return _buildPillButton(
                                  icon: isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  label: 'Like',
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
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

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

                      const Spacer(),

                      // Bottom Tabs
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _showUpNextSheet(context, audioBloc),
                                child: const Text(
                                  'UP NEXT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _showLyricsSheet(context, track, audioBloc),
                                child: const Text(
                                  'LYRICS',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
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

class _LyricsSheetContent extends StatefulWidget {
  final Map<String, String> track;
  final AudioBloc audioBloc;
  const _LyricsSheetContent({required this.track, required this.audioBloc});

  @override
  State<_LyricsSheetContent> createState() => _LyricsSheetContentState();
}

class _LyricsSheetContentState extends State<_LyricsSheetContent> {
  final ScrollController _localController = ScrollController();

  @override
  void dispose() {
    _localController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: YTColors.surface.withValues(alpha: 0.5), // Glassmorphism base
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
                'Lyrics',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<Result<String>>(
                  future: PythonService.lyrics(
                    widget.track['videoId'] ?? '',
                    title: widget.track['title'] ?? '',
                    artist: widget.track['artist'] ?? '',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: YTColors.primary,
                        ),
                      );
                    }
                    final result = snapshot.data;
                    if (result is Success<String>) {
                      // LRC Parse Regex: [mm:ss.xx]
                      final lrcRegex = RegExp(
                        r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)',
                      );

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
                          // Plain text line
                          parsedLines.add({'time': null, 'text': line.trim()});
                        }
                      }

                      return StreamBuilder<Duration>(
                        stream: widget.audioBloc.player.positionStream,
                        builder: (context, posSnap) {
                          return StreamBuilder<Duration?>(
                            stream: widget.audioBloc.player.durationStream,
                            builder: (context, durSnap) {
                              final pos = posSnap.data ?? Duration.zero;
                              final dur = durSnap.data ?? Duration.zero;

                              int activeIndex = 0;
                              if (hasTimestamps) {
                                // Pinpoint active line based exactly on current position vs parsed timestamp
                                for (int i = 0; i < parsedLines.length; i++) {
                                  if (parsedLines[i]['time'] != null &&
                                      pos >=
                                          (parsedLines[i]['time']
                                              as Duration)) {
                                    activeIndex = i;
                                  }
                                }
                              } else {
                                // Fallback linear sync if no timestamps exist
                                final progress = dur.inMilliseconds > 0
                                    ? (pos.inMilliseconds / dur.inMilliseconds)
                                          .clamp(0.0, 1.0)
                                    : 0.0;
                                activeIndex = (progress * parsedLines.length)
                                    .floor()
                                    .clamp(
                                      0,
                                      parsedLines.length > 0
                                          ? parsedLines.length - 1
                                          : 0,
                                    );
                              }

                              // Automatically try to center the active line
                              if (_localController.hasClients &&
                                  activeIndex > 0) {
                                final offset =
                                    (activeIndex * 40.0) -
                                    (MediaQuery.of(context).size.height * 0.2);
                                if (offset > 0) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted &&
                                        _localController.hasClients) {
                                      _localController.animateTo(
                                        offset,
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  });
                                }
                              }

                              return ListView.builder(
                                controller: _localController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 64,
                                ),
                                itemCount: parsedLines.length,
                                itemBuilder: (context, index) {
                                  final isActive = index == activeIndex;
                                  final text =
                                      parsedLines[index]['text'] as String;
                                  if (text.isEmpty)
                                    return const SizedBox(height: 24);

                                  return AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 400),
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white24,
                                      fontSize: isActive ? 28 : 22,
                                      height: 1.5,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Text(
                                        text,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    } else {
                      return Center(
                        child: Text(
                          result is Failure<String>
                              ? result.message
                              : 'No lyrics available.',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
