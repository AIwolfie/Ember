import 'package:ember_flutter/widgets/shared_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme.dart';
import 'bloc/home_bloc.dart';
import 'bloc/home_event.dart';
import 'bloc/home_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, EmberThemeOption>(builder: (context, themeOption) {
      return BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return _buildHomeSkeleton();
          }

          if (state is HomeAILoading) {
            return _buildAILoadingSkeleton(state.targetMood);
          }

          if (state is HomeError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.message,
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: YTColors.surfaceLight,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      context.read<HomeBloc>().add(
                            const HomeLoadRequested(forceRefresh: true),
                          );
                    },
                  ),
                ],
              ),
            );
          }

          if (state is HomeLoaded) {
            final sections = List<Map<String, dynamic>>.from(state.sections);
            sections.sort((a, b) {
              final tA = (a['title'] as String).toLowerCase();
              final tB = (b['title'] as String).toLowerCase();
              int score(String title) {
                if (title.contains('quick picks')) return 0;
                if (title.contains('artist') || title.contains('recommend')) return 1;
                if (title.contains('listen again')) return 2;
                return 3;
              }

              return score(tA).compareTo(score(tB));
            });

            if (sections.isEmpty || (sections.length == 1 && (sections.first['tracks'] as List).isEmpty)) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.music_off, size: 80, color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text(
                      "Cannot load home feed",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: YTColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => context.read<HomeBloc>().add(
                            const HomeLoadRequested(forceRefresh: true),
                          ),
                      child: const Text(
                        'Tap to Refresh',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SafeArea(
              bottom: false,
              top: false,
              child: RefreshIndicator(
                color: Colors.black,
                backgroundColor: Colors.white,
                onRefresh: () async {
                  context.read<HomeBloc>().add(
                        const HomeLoadRequested(forceRefresh: true),
                      );
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 120, top: 0),
                  children: [
                    _buildMoodChips(context, state.activeMood),
                    const SizedBox(height: 4),
                    if (state.isColdStart && state.activeMood == null) _buildWelcomeBanner(),
                    ...sections.map((section) {
                      final title = section['title'] as String;
                      final subtitle = section['subtitle'] as String?;
                      final rawTracks = section['tracks'] as List<dynamic>;
                      final items = rawTracks
                          .map(
                            (e) => (e as Map).map(
                              (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
                            ),
                          )
                          .toList();

                      final isVIP = title.toLowerCase().contains("dj ai");

                      Widget sectionContent = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SharedUI.buildSectionTitle(title),
                          if (subtitle != null && subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: YTColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: YTColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          // Only use premium grid for Quick Picks, everything else uses horizontal carousel
                          if (title.toLowerCase().contains('quick picks'))
                            SharedUI.buildQuickPicksGrid(context, items)
                          else if (title.toLowerCase().contains('hits') ||
                              title.toLowerCase().contains('mix') ||
                              title.toLowerCase().contains('picks'))
                            SharedUI.buildQuickPicksGrid(context, items)
                          else
                            SharedUI.buildHorizontalList(
                              items,
                              listId: 'home_$title',
                            ),
                          const SizedBox(height: 8),
                        ],
                      );
                      
                      if (isVIP) {
                         return Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                               gradient: LinearGradient(
                                  colors: [
                                     Colors.deepPurpleAccent.withValues(alpha: 0.15),
                                     YTColors.primary.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                               ),
                               border: Border.symmetric(
                                  horizontal: BorderSide(color: Colors.deepPurpleAccent.withValues(alpha: 0.2)),
                               )
                            ),
                            child: sectionContent,
                         );
                      }
                      
                      return sectionContent;
                    }),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );
    });
  }

  Widget _buildMoodChips(BuildContext context, String? activeMood) {
    final chips = ['Energize', 'Workout', 'Relax', 'Commute', 'Focus', 'Party'];
    return SizedBox(
      height: 36,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final isSelected = activeMood == chips[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (isSelected) {
                    context.read<HomeBloc>().add(const HomeLoadRequested());
                  } else {
                    context.read<HomeBloc>().add(
                          HomeLoadRequested(mood: chips[index]),
                        );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white10,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    chips[index],
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: YTColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: YTColors.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to Ember! \uD83D\uDD25',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Search and play a few songs you love to help us build a personalized feed just for you.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.04),
      highlightColor: Colors.white.withValues(alpha: 0.12),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 24, bottom: 120),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: 160,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: 4,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 100,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAILoadingSkeleton(String mood) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Shimmer.fromColors(
            baseColor: YTColors.primary.withValues(alpha: 0.8),
            highlightColor: Colors.deepPurpleAccent,
            child: const Icon(
              Icons.auto_awesome,
              size: 72,
            ),
          ),
          const SizedBox(height: 24),
          Shimmer.fromColors(
            baseColor: Colors.white60,
            highlightColor: Colors.white,
            child: Text(
              "DJ AI is carefully crafting your\n$mood mix...",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
