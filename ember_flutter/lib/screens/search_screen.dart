import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_event.dart';
import '../blocs/storage/storage_state.dart';
import '../services/python_service.dart';
import '../theme.dart';
import '../utils/result.dart';
import '../utils/search_algorithm.dart';
import '../widgets/shared_ui.dart';
import 'artist_screen.dart';
import 'playlist_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _currentFilter = 'All';

  final List<String> _filters = [
    'All',
    'Songs',
    'Albums',
    'Artists',
    'Playlists',
  ];

  @override
  void dispose() {
    EasyDebounce.cancel('search-debounce');
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    context.read<StorageBloc>().add(StorageAddSearch(query));

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _results = [];
    });

    // Remove plural for the api if needed, e.g., 'albums' -> 'albums' is usually fine for ytmusicapi
    String? filterKey;
    if (_currentFilter != 'All') {
      filterKey = _currentFilter.toLowerCase();
    }

    final result = await PythonService.search(
      query.trim(),
      filterType: filterKey,
    );

    if (mounted) {
      if (result is Success<List<Map<String, String>>>) {
        setState(() {
          final items = result.data.map((e) => Map<String, String>.from(e)).toList();
          _results = SearchAlgorithm.optimizeResults(items, query);
          _isLoading = false;
        });
      } else if (result is Failure<List<Map<String, String>>>) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _hasSearched = false;
        _results = [];
      });
      return;
    }
    EasyDebounce.debounce(
      'search-debounce',
      const Duration(milliseconds: 700),
      () => _performSearch(query),
    );
  }

  void _handleResultTap(Map<String, String> track, String type) {
    if (type == 'artist') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArtistScreen(artistInfo: track)),
      );
      return;
    } else if (type == 'playlist' || type == 'album') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistScreen(
            playlistName: track['title'] ?? 'Playlist',
            remoteIdentifier: track['browseId'] ?? track['videoId'],
          ),
        ),
      );
      return;
    }

    SharedUI.playFromList(context, [track], 0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, EmberThemeOption>(
      builder: (context, themeOption) {
        return Scaffold(
          backgroundColor: YTColors.background,
          appBar: _buildModernAppBar(),
          body: _buildMainContent(),
        );
      },
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      titleSpacing: 16,
      toolbarHeight: 64,
      backgroundColor: YTColors.background,
      elevation: 0,
      automaticallyImplyLeading: false, // No leading back button needed in main search tab
      title: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Hero(
          tag: 'search_bar',
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Songs, albums, artists...',
                        hintStyle: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(left: 20, bottom: 4),
                      ),
                      onSubmitted: _performSearch,
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      if (value.text.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(
                            Icons.search,
                            color: Colors.white54,
                            size: 20,
                          ),
                        );
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white70,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _currentFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () {
                        if (_currentFilter != filter) {
                          setState(() => _currentFilter = filter);
                          EasyDebounce.debounce(
                            'search-filter-debounce',
                            const Duration(milliseconds: 300),
                            () => _performSearch(_searchController.text),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white24,
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (!_hasSearched) {
      return _HistorySliver(
        searchController: _searchController,
        onSearch: _performSearch,
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No results found.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final track = _results[index];
        final type = track['type'] ?? 'song';

        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Text(
                  'Top result',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _TopResultCard(
                track: track,
                type: type,
                onTap: (t, type) => _handleResultTap(t, type),
              ),
              if (_results.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                  child: Text(
                    type == 'artist' ? 'Top Songs' : 'More results',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
            ],
          );
        }
        return _StandardListItem(
          track: track,
          type: type,
          onTap: (t, type) => _handleResultTap(t, type),
        );
      },
    );
  }
}

class _TopResultCard extends StatelessWidget {
  final Map<String, String> track;
  final String type;
  final void Function(Map<String, String>, String) onTap;

  const _TopResultCard({
    required this.track,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isArtist = type == 'artist';
    bool showPlayOverlay = type == 'song' || type == 'video' || type == 'album' || type == 'playlist';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(track, type),
          borderRadius: BorderRadius.circular(20),
          highlightColor: Colors.white10,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: YTColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(isArtist ? 44 : 12),
                      child: CachedNetworkImage(
                        imageUrl: track['artworkUrl'] ?? '',
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(
                          width: 88,
                          height: 88,
                          color: Colors.black26,
                        ),
                        errorWidget: (c, e, s) => Container(
                          width: 88,
                          height: 88,
                          color: Colors.black26,
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white54,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    if (showPlayOverlay)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track['title'] ?? 'Unknown',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        SearchAlgorithm.getSubtitle(
                          track,
                          type,
                          isTopCard: true,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (type == 'song' || type == 'video')
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    onPressed: () => SharedUI.showTrackOptions(context, track),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StandardListItem extends StatelessWidget {
  final Map<String, String> track;
  final String type;
  final void Function(Map<String, String>, String) onTap;

  const _StandardListItem({
    required this.track,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isArtist = type == 'artist';
    return InkWell(
      onTap: () => onTap(track, type),
      onLongPress: (type == 'song' || type == 'video') ? () => SharedUI.showTrackOptions(context, track) : null,
      splashColor: Colors.white12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(isArtist ? 28 : 8),
              child: CachedNetworkImage(
                imageUrl: track['artworkUrl'] ?? '',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(
                  width: 56,
                  height: 56,
                  color: YTColors.surfaceLight,
                ),
                errorWidget: (c, e, s) => Container(
                  width: 56,
                  height: 56,
                  color: YTColors.surface,
                  child: const Icon(Icons.music_note, color: Colors.white54),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (type == 'song' || type == 'video')
                        const Icon(
                          Icons.music_note,
                          size: 14,
                          color: YTColors.secondary,
                        ),
                      if (type == 'song' || type == 'video') const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          SearchAlgorithm.getSubtitle(
                            track,
                            type,
                            isTopCard: false,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: YTColors.secondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (type == 'song' || type == 'video')
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                onPressed: () => SharedUI.showTrackOptions(context, track),
              ),
            if (isArtist)
              const Padding(
                padding: EdgeInsets.only(right: 8.0, left: 8.0),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white24,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistorySliver extends StatelessWidget {
  final TextEditingController searchController;
  final void Function(String) onSearch;

  const _HistorySliver({
    required this.searchController,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StorageBloc, StorageState>(
      builder: (context, storageState) {
        final history = storageState.searchHistory;

        if (history.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.youtube_searched_for,
                  size: 72,
                  color: Colors.white10,
                ),
                SizedBox(height: 16),
                Text(
                  'Search for your favorites',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Songs, albums, artists and more.',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent searches',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.read<StorageBloc>().add(StorageClearSearch()),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: YTColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 12.0,
                children: history.take(15).map((q) {
                  return InkWell(
                    onTap: () {
                      searchController.text = q;
                      onSearch(q);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history,
                            color: Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            q,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
