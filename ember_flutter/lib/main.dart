import 'dart:ui';

import 'package:ember_flutter/blocs/audio/audio_bloc.dart';
import 'package:ember_flutter/blocs/audio/audio_state.dart';
import 'package:ember_flutter/blocs/storage/storage_bloc.dart';
import 'package:ember_flutter/screens/about/about_screen.dart';
import 'package:ember_flutter/screens/download/bloc/download_bloc.dart';
import 'package:ember_flutter/screens/home/bloc/home_bloc.dart';
import 'package:ember_flutter/screens/home/bloc/home_event.dart';
import 'package:ember_flutter/screens/home/home_screen.dart';
import 'package:ember_flutter/screens/library/library_screen.dart';
import 'package:ember_flutter/screens/onboarding/onboarding_screen.dart';
import 'package:ember_flutter/screens/search/search_screen.dart';
import 'package:ember_flutter/screens/settings/settings_screen.dart';
import 'package:ember_flutter/services/database_service.dart';
import 'package:ember_flutter/services/update_service.dart';
import 'package:ember_flutter/theme.dart';
import 'package:ember_flutter/utils/update_checker.dart';
import 'package:ember_flutter/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.ember.channel.audio',
    androidNotificationChannelName: 'Ember Music',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    androidShowNotificationBadge: true,
    androidNotificationIcon: 'drawable/ic_music_notification',
  );

  final storageBloc = StorageBloc();
  await storageBloc.init();

  // Non-blocking silent background OTA check via Shorebird
  UpdateService.instance.initBackgroundUpdate();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<StorageBloc>.value(value: storageBloc),
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
        BlocProvider<AudioBloc>(create: (_) => AudioBloc()),
        BlocProvider<DownloadBloc>(create: (_) => DownloadBloc()),
        BlocProvider<HomeBloc>(
          create: (_) => HomeBloc()..add(const HomeLoadRequested()),
        ),
      ],
      child: const EmberApp(),
    ),
  );
}

class EmberApp extends StatefulWidget {
  const EmberApp({super.key});

  @override
  State<EmberApp> createState() => _EmberAppState();
}

class _EmberAppState extends State<EmberApp> {
  bool _isLoading = true;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final db = DatabaseService.instance;
    final onboardingDone = await db.getCache('onboarding_done');
    if (onboardingDone == null) {
      _needsOnboarding = true;
      await db.setCache('onboarding_done', 'true');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, EmberThemeOption>(
      builder: (context, currentTheme) {
        return MaterialApp(
          title: 'Ember',
          debugShowCheckedModeBanner: false,
          theme: YTTheme.getTheme(currentTheme),
          home: _isLoading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : (_needsOnboarding ? const OnboardingScreen() : const MainLayout()),
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdate(context);
    });

    UpdateService.instance.onUpdateReady.listen((ready) {
      if (ready && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'A background update has been installed! Please restart the app.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(hours: 24),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.orangeAccent,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, EmberThemeOption>(builder: (context, themeOption) {
      return Scaffold(
        backgroundColor: YTColors.background,
        extendBody: true,
        body: BlocBuilder<AudioBloc, AudioState>(
          builder: (context, audioState) {
            final topColor = audioState.dominantColor ?? const Color(0xFF6B1B1B);
            return Stack(
              children: [
                if (_currentIndex == 0) // Only on home screen
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 400,
                    child: AnimatedContainer(
                      duration: const Duration(seconds: 1),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            topColor.withValues(alpha: 0.3),
                            YTColors.background,
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                NestedScrollView(
                  physics: const ClampingScrollPhysics(),
                  headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                    return [
                      if (_currentIndex == 0) // Only show top bar on home screen
                        SliverAppBar(
                          floating: true,
                          snap: true,
                          backgroundColor: Colors.transparent, // transparent for gradient
                          surfaceTintColor: Colors.transparent,
                          title: Row(
                            children: [
                              const Icon(
                                Icons.whatshot,
                                color: Colors.orangeAccent,
                                size: 32,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ember',
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ],
                          ),
                          actions: [
                            IconButton(
                              icon: const Icon(
                                Icons.settings_outlined,
                                color: Colors.white70,
                              ),
                              tooltip: 'Settings',
                              onPressed: () => showSettingsSheet(context),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                    ];
                  },
                  body: IndexedStack(
                    index: _currentIndex,
                    children: const [
                      HomeScreen(),
                      SearchScreen(),
                      LibraryScreen(),
                      AboutScreen(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: BottomNavigationBar(
                  backgroundColor: YTColors.surface.withValues(alpha: 0.85),
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.search_outlined),
                      activeIcon: Icon(Icons.search_rounded),
                      label: 'Search',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.library_music_outlined),
                      activeIcon: Icon(Icons.library_music_rounded),
                      label: 'Library',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.info_outline_rounded),
                      activeIcon: Icon(Icons.info_rounded),
                      label: 'About',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
