import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../blocs/home/home_bloc.dart';
import '../blocs/home/home_event.dart';
import '../blocs/home/home_state.dart';
import '../theme.dart';
import '../widgets/shared_ui.dart';

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
                  padding: const EdgeInsets.only(bottom: 120, top: 4),
                  children: [
                    _buildMoodChips(context, state.activeMood),
                    const SizedBox(height: 12),
                    ...sections.map((section) {
                      final title = section['title'] as String;
                      final rawTracks = section['tracks'] as List<dynamic>;
                      final items = rawTracks
                          .map(
                            (e) => (e as Map).map(
                              (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
                            ),
                          )
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SharedUI.buildSectionTitle(title),
                          // If there are many items, use our new premium grid, else horizontal list
                          if (items.length >= 8)
                            SharedUI.buildQuickPicksGrid(context, items)
                          else
                            SharedUI.buildHorizontalList(
                              items,
                              listId: 'home_$title',
                            ),
                          const SizedBox(height: 8),
                        ],
                      );
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
      height: 48,
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
                  if (isSelected) {
                    context.read<HomeBloc>().add(const HomeLoadRequested());
                  } else {
                    context.read<HomeBloc>().add(
                          HomeLoadRequested(mood: chips[index]),
                        );
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
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
                      fontSize: 14,
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
}
