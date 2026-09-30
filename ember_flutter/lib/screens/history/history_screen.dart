import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ember_flutter/blocs/audio/audio_bloc.dart';
import 'package:ember_flutter/blocs/audio/audio_event.dart';
import 'package:ember_flutter/blocs/storage/storage_bloc.dart';
import 'package:ember_flutter/blocs/storage/storage_event.dart';
import 'package:ember_flutter/blocs/storage/storage_state.dart';
import 'package:ember_flutter/services/recommender_service.dart';
import 'package:ember_flutter/theme.dart';
import 'package:ember_flutter/widgets/ember_app_bar.dart';
import 'package:ember_flutter/widgets/mini_player.dart';
import 'package:ember_flutter/screens/player/full_player_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Map<String, double> _topArtists = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final recommender = RecommenderService.instance;
    await recommender.initializeAffinities();

    // Sort and get top 5
    var entries = recommender.artistAffinityCache.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _topArtists = Map.fromEntries(entries.take(5));
      _isLoadingStats = false;
    });
  }

  void _playSong(BuildContext context, Map<String, String> track) {
    context.read<AudioBloc>().add(AudioPlayQueue([track], startIndex: 0));

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

  Widget _buildListeningStats() {
    if (_isLoadingStats) {
      return Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator(color: YTColors.primary)),
      );
    }

    if (_topArtists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: YTColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: YTColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                "Your Top Artists",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._topArtists.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: YTColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${e.value.toStringAsFixed(1)} points",
                      style: TextStyle(color: YTColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YTColors.background,
      appBar: EmberAppBar(
        titleText: 'Listening History',
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: YTColors.secondary),
            onPressed: () {
              context.read<StorageBloc>().add(StorageClearPlayHistory());
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History cleared')));
              setState(() => _topArtists.clear());
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
                      Text("No recently played songs.", style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: history.length + 2, // 1 for stats, 1 for "Recent Plays" header
                itemBuilder: (context, index) {
                  if (index == 0) return _buildListeningStats();
                  if (index == 1) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(
                        "Recent Plays",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    );
                  }

                  final track = history[index - 2];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: track['artworkUrl'] ?? '',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(width: 56, height: 56, color: YTColors.surfaceLight),
                        errorWidget: (context, error, stackTrace) => Container(
                          width: 56,
                          height: 56,
                          color: YTColors.surface,
                          child: const Icon(Icons.music_note, color: YTColors.secondary),
                        ),
                      ),
                    ),
                    title: Text(
                      track['title'] ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: YTColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        track['artist'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: YTColors.secondary, fontSize: 14),
                      ),
                    ),
                    trailing: const Icon(Icons.play_arrow_rounded, color: YTColors.secondary),
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
