import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/python_service.dart';
import '../utils/result.dart';
import '../theme.dart';
import '../widgets/shared_ui.dart';
import '../blocs/audio/audio_bloc.dart';
import '../blocs/audio/audio_event.dart';
import 'playlist_screen.dart';

class ArtistScreen extends StatefulWidget {
  final Map<String, String> artistInfo;

  const ArtistScreen({super.key, required this.artistInfo});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  bool _loading = true;
  Map<String, dynamic>? _artistData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final browseId = widget.artistInfo['videoId'] ?? widget.artistInfo['browseId'];
    if (browseId == null || browseId.isEmpty) {
      if (mounted) setState(() { _loading = false; _error = "Invalid artist link."; });
      return;
    }

    final res = await PythonService.getArtistDetails(browseId);
    if (mounted) {
      setState(() {
        _loading = false;
        if (res is Success<Map<String, dynamic>>) {
          _artistData = res.data;
        } else if (res is Failure<Map<String, dynamic>>) {
          _error = res.message;
        }
      });
    }
  }

  void _routeToPlaylist(Map<String, dynamic> pt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistScreen(
          playlistName: pt['title']?.toString() ?? 'Album',
          remoteIdentifier: pt['videoId']?.toString() ?? pt['browseId']?.toString() ?? '',
        ),
      ),
    );
  }

  void _playAllSongs(List<Map<String, String>> songs) {
    if (songs.isEmpty) return;
    SharedUI.playFromList(context, songs, 0);
  }

  Widget _buildCarousel(String title, List<Map<String, String>> items) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SharedUI.buildSectionTitle(title),
          SizedBox(
            height: 220,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  width: 140,
                  child: InkWell(
                    onTap: () => _routeToPlaylist(item),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: item['artworkUrl'] ?? '',
                              width: 140,
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(width: 140, color: YTColors.surfaceLight),
                              errorWidget: (context, error, stackTrace) => Container(
                                width: 140,
                                color: YTColors.surfaceLight,
                                child: const Icon(Icons.album, color: YTColors.secondary, size: 48),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item['title'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['artist'] ?? '',
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
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: YTColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: YTColors.primary)),
      );
    }

    if (_error != null || _artistData == null) {
      return Scaffold(
        backgroundColor: YTColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: Text(_error ?? "Failed to load artist.", style: const TextStyle(color: Colors.white54))),
      );
    }

    final image = _artistData!['image'] as String? ?? '';
    final name = _artistData!['name'] as String? ?? widget.artistInfo['title'] ?? 'Unknown Artist';
    
    final rawSongs = _artistData!['songs'] as List<dynamic>? ?? [];
    final songs = rawSongs.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))).toList();
    
    final rawAlbums = _artistData!['albums'] as List<dynamic>? ?? [];
    final albums = rawAlbums.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))).toList();
    
    final rawSingles = _artistData!['singles'] as List<dynamic>? ?? [];
    final singles = rawSingles.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))).toList();

    return Scaffold(
      backgroundColor: YTColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: YTColors.background,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16, right: 24),
              title: Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32, letterSpacing: -1.0, shadows: [Shadow(color: Colors.black, blurRadius: 20)]),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (image.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorWidget: (c, u, e) => Container(color: YTColors.surface),
                    )
                  else
                    Container(color: YTColors.surface),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black45, YTColors.background],
                        stops: [0.2, 0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (songs.isNotEmpty) ...[
             SliverToBoxAdapter(
               child: Padding(
                 padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     const Text('Top Songs', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                     TextButton.icon(
                       icon: const Icon(Icons.play_arrow, color: YTColors.primary, size: 20),
                       label: const Text('Play all', style: TextStyle(color: YTColors.primary, fontWeight: FontWeight.bold)),
                       onPressed: () => _playAllSongs(songs),
                     )
                   ],
                 )
               ),
             ),
             SliverList(
               delegate: SliverChildBuilderDelegate(
                 (context, index) {
                   final track = songs[index];
                   return InkWell(
                     onTap: () => SharedUI.playFromList(context, songs, index),
                     onLongPress: () => SharedUI.showTrackOptions(context, track),
                     child: Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       child: Row(
                         children: [
                           SizedBox(
                             width: 24,
                             child: Text('${index + 1}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                           ),
                           const SizedBox(width: 8),
                           ClipRRect(
                             borderRadius: BorderRadius.circular(4),
                             child: CachedNetworkImage(
                               imageUrl: track['artworkUrl'] ?? '', width: 56, height: 56, fit: BoxFit.cover,
                               placeholder: (c, u) => Container(width: 56, height: 56, color: YTColors.surfaceLight),
                               errorWidget: (c, e, s) => Container(width: 56, height: 56, color: YTColors.surface, child: const Icon(Icons.music_note, color: Colors.white54)),
                             ),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(track['title'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                 const SizedBox(height: 4),
                                 Text('${track['artist']} • ${track['duration']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                               ],
                             ),
                           ),
                           IconButton(
                             icon: const Icon(Icons.more_vert, color: Colors.white54),
                             onPressed: () => SharedUI.showTrackOptions(context, track),
                           ),
                         ],
                       ),
                     ),
                   );
                 },
                 childCount: songs.length,
               ),
             ),
             const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],

          _buildCarousel('Albums', albums),
          _buildCarousel('Singles', singles),

          const SliverPadding(padding: EdgeInsets.only(bottom: 150)),
        ],
      ),
    );
  }
}
