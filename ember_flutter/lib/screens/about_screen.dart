import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/settings_sheet.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YTColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Navigator.canPop(context)
                ? Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: const BackButton(color: Colors.white),
                    ),
                  )
                : null,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                    ),
                    tooltip: 'Settings',
                    onPressed: () => showSettingsSheet(context),
                  ),
                ),
              ),
            ],
            stretch: true,
            expandedHeight: 280,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroSection(),
              stretchModes: const [StretchMode.zoomBackground],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ember is a premium music streaming client designed to keep your listening simple, clean, and distraction-free.\n\nNo complicated setup. No unnecessary features. Just search for music, play what you want, and let Ember handle the rest.',
                    style: TextStyle(
                      color: YTColors.secondary,
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Features Grid
                  _buildSectionTitle('Features'),
                  const SizedBox(height: 20),
                  _buildFeaturesGrid(),
                  const SizedBox(height: 48),

                  // Built to stay lightweight
                  _buildLightweightCard(),
                  const SizedBox(height: 20),

                  // Open Source
                  _buildOpenSourceCard(),
                  const SizedBox(height: 48),

                  // Credits
                  _buildSectionTitle('Credits'),
                  const SizedBox(height: 20),
                  _buildCreditsSection(),

                  const SizedBox(height: 80),
                  _buildFooter(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Glow
        Positioned(
          top: -50,
          left: -100,
          right: -100,
          child: Container(
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orangeAccent.withValues(alpha: 0.10),
                  blurRadius: 100,
                  spreadRadius: 80,
                ),
              ],
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: YTColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.whatshot,
                color: Colors.orangeAccent,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ember',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid() {
    return Wrap(
      runSpacing: 12,
      spacing: 12,
      children: [
        _buildFeatureChip(Icons.search_rounded, 'Search & stream'),
        _buildFeatureChip(Icons.favorite_rounded, 'Save tracks'),
        _buildFeatureChip(Icons.history_rounded, 'Listening history'),
        _buildFeatureChip(Icons.lyrics_rounded, 'Synchronized lyrics'),
        _buildFeatureChip(Icons.bolt_rounded, 'Lightweight & fast'),
        _buildFeatureChip(Icons.no_accounts_rounded, 'No sign-in required'),
        _buildFeatureChip(Icons.block_rounded, 'Ad-free experience'),
      ],
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: YTColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.indigoAccent.shade100, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightweightCard() {
    return _buildCard(
      icon: Icons.eco_rounded,
      title: 'Minimal by Design',
      content: 'Ember avoids unnecessary background processes, bloated interfaces, and features that get in the way of listening.',
      color: Colors.greenAccent,
    );
  }

  Widget _buildOpenSourceCard() {
    return _buildCard(
      icon: Icons.code_rounded,
      title: 'Open Source',
      content: 'Built with the goal of keeping music playback simple, highly accessible, and totally transparent.',
      color: Colors.blueAccent,
      action: InkWell(
        onTap: () => _launchUrl('https://github.com/KenilPatel0/Ember'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Explore Github Repository',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.blueAccent,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: YTColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 24), action],
        ],
      ),
    );
  }

  Widget _buildCreditsSection() {
    return Column(
      children: [
        _buildDeveloperRow(
          role: 'Code Architect & Developer',
          name: 'Mayank Malaviya',
          website: 'aiwolfie.online',
          url: 'https://aiwolfie.online',
          icon: Icons.computer_rounded,
        ),
        const SizedBox(height: 16),
        _buildDeveloperRow(
          role: 'Mobile App Architect & Developer',
          name: 'Kenil Ribadiya',
          website: 'kenilribadiya.in',
          url: 'https://kenilribadiya.in',
          icon: Icons.smartphone_rounded,
        ),
      ],
    );
  }

  Widget _buildDeveloperRow({
    required String role,
    required String name,
    required String website,
    required String url,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: YTColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: YTColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.orangeAccent.shade100, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.language_rounded, color: Colors.white54),
            onPressed: () => _launchUrl(url),
            tooltip: website,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Icon(Icons.favorite_rounded, color: Colors.white12, size: 32),
        const SizedBox(height: 16),
        const Text(
          'Crafted for late nights, cold tea, and warm code.\nEnjoy the sound.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: YTColors.secondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '© 2026 Ember. An open-source project.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
