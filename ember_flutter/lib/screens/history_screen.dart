import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../blocs/audio/audio_bloc.dart';
import '../blocs/audio/audio_event.dart';
import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_state.dart';
import '../blocs/storage/storage_event.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/ember_app_bar.dart';
import 'full_player_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  void _playSong(BuildContext context, Map<String, String> track) {
    context.read<AudioBloc>().add(AudioPlayQueue([track], startIndex: 0));

    // Also push the player screen
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
      appBar: EmberAppBar(
        titleText: 'Recent History',
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: YTColors.secondary),
            onPressed: () {
              context.read<StorageBloc>().add(StorageClearPlayHistory());
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('History cleared')));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          BlocBuilder<StorageBloc, StorageState>(
            builder: (context, storageState) {
              final history = storageState.playHistory;

              if (history.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        "No recently played songs.",
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100, top: 16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final track = history[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: track['artworkUrl'] ?? '',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 56,
                          height: 56,
                          color: YTColors.surfaceLight,
                        ),
                        errorWidget: (context, error, stackTrace) => Container(
                          width: 56,
                          height: 56,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: YTColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        track['artist'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: YTColors.secondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.play_arrow_rounded,
                      color: YTColors.secondary,
                    ),
                    onTap: () => _playSong(context, track),
                  );
                },
              );
            },
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: MiniPlayer()),
          ),
        ],
      ),
    );
  }
}
