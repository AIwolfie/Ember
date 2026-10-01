import 'package:flutter/material.dart';
import 'package:ember_flutter/screens/playlist/playlist_screen.dart';

/// The FavoritesScreen provides a dedicated entry point for Liked Songs.
/// Currently it wraps the existing PlaylistScreen configured for 'Favorites',
/// but provides a semantic boundary for future custom UI.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaylistScreen(
      playlistName: 'Favorites',
    );
  }
}
