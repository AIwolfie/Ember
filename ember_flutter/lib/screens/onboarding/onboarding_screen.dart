import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:ember_flutter/services/python_service.dart';
import 'package:ember_flutter/services/recommender_service.dart';
import 'package:ember_flutter/theme.dart';
import 'package:ember_flutter/utils/result.dart';
import 'package:ember_flutter/main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  List<Map<String, String>> _artists = [];
  final Set<String> _selectedArtistIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTopArtists();
  }

  Future<void> _loadTopArtists() async {
    final result = await PythonService.topArtists();
    if (result is Success<List<Map<String, String>>>) {
      setState(() {
        _artists = result.data.where((a) => a['title'] != null && (a['title']!.isNotEmpty)).take(30).toList();
        _isLoading = false;
      });
    } else {
      // Failed to load, just skip onboarding for now.
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isSaving = true);
    final selectedArtists = _artists.where((a) => _selectedArtistIds.contains(a['videoId'] ?? a['browseId'])).toList();
    if (selectedArtists.isNotEmpty) {
      await RecommenderService.instance.saveColdStartArtists(selectedArtists);
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    }
  }

  void _toggleArtist(String id) {
    setState(() {
      if (_selectedArtistIds.contains(id)) {
        _selectedArtistIds.remove(id);
      } else {
        _selectedArtistIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YTColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 48, 24, 16),
              child: Column(
                children: [
                  Text(
                    "Pick some artists you like",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "We'll use these to jump-start your personalized radio and recommendations.",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: YTColors.primary))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 24,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _artists.length,
                      itemBuilder: (context, index) {
                        final artist = _artists[index];
                        final id = artist['videoId'] ?? artist['browseId'] ?? '';
                        final isSelected = _selectedArtistIds.contains(id);
                        final name = artist['title'] ?? 'Unknown';
                        final imageUrl = artist['artworkUrl'] ?? '';

                        return GestureDetector(
                          onTap: () => _toggleArtist(id),
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? YTColors.primary : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: YTColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check, color: Colors.black, size: 16),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _finishOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedArtistIds.length >= 3 ? Colors.white : YTColors.surfaceLight,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        _selectedArtistIds.length >= 3 ? "Let's Go!" : "Skip for now",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: _selectedArtistIds.length >= 3 ? FontWeight.bold : FontWeight.normal,
                            color: _selectedArtistIds.length >= 3 ? Colors.black : Colors.white54),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
