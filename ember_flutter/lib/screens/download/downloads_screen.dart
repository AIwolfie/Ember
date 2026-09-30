import 'package:cached_network_image/cached_network_image.dart';
import 'package:ember_flutter/blocs/audio/audio_bloc.dart';
import 'package:ember_flutter/blocs/audio/audio_event.dart';
import 'package:ember_flutter/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../theme.dart';
import '../../widgets/shared_ui.dart';
import 'bloc/download_bloc.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, EmberThemeOption>(builder: (context, themeOption) {
      return Scaffold(
        backgroundColor: YTColors.background,
        appBar: _buildAppBar(context),
        body: BlocBuilder<DownloadBloc, DownloadState>(
          builder: (context, downloadState) {
            final downloads = downloadState.downloadedTracks.map((e) => e['trackData'] as Map<String, String>).toList();

            if (downloads.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 140, top: 8),
              itemCount: downloads.length,
              itemBuilder: (context, index) {
                final track = downloads[index];
                return _buildTrackTile(context, track, downloads, index);
              },
            );
          },
        ),
        bottomSheet: const MiniPlayer(),
      );
    });
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: YTColors.background,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Downloaded Songs',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_done_rounded,
              size: 64,
              color: YTColors.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Downloads Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tracks you download for offline listening will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: YTColors.secondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackTile(
    BuildContext context,
    Map<String, String> track,
    List<Map<String, String>> allDownloads,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.read<AudioBloc>().add(
                  AudioPlayQueue(allDownloads, startIndex: index),
                );
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: track['artworkUrl'] ?? '',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.download_done_rounded,
                          color: YTColors.secondary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            track['artist'] ?? 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: YTColors.secondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white54,
                  size: 22,
                ),
                onPressed: () => SharedUI.showTrackOptions(context, track),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
