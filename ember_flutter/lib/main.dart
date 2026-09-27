import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'utils/update_checker.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'blocs/audio/audio_bloc.dart';
import 'blocs/audio/audio_state.dart';
import 'blocs/home/home_bloc.dart';
import 'blocs/home/home_event.dart';
import 'blocs/storage/storage_bloc.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'theme.dart';
import 'widgets/mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.ember.channel.audio',
    androidNotificationChannelName: 'Ember Music',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: false,
    androidShowNotificationBadge: true,
    androidNotificationIcon: 'drawable/ic_music_notification',
  );

  final storageBloc = StorageBloc();
  await storageBloc.init();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<StorageBloc>.value(value: storageBloc),
        BlocProvider<AudioBloc>(create: (_) => AudioBloc()),
        BlocProvider<HomeBloc>(create: (_) => HomeBloc()..add(const HomeLoadRequested())),
      ],
      child: const EmberApp(),
    ),
  );
}

class EmberApp extends StatelessWidget {
  const EmberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Ember', debugShowCheckedModeBanner: false, theme: YTTheme.darkTheme, home: const MainLayout());
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
  }

  @override
  Widget build(BuildContext context) {
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
                        colors: [topColor.withValues(alpha: 0.3), YTColors.background],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              NestedScrollView(
                physics: const BouncingScrollPhysics(),
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
                            const Icon(Icons.whatshot, color: Colors.orangeAccent, size: 32),
                            const SizedBox(width: 8),
                            Text('Ember', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ],
                        ),
                        actions: const [
                          SizedBox(width: 8),
                        ],
                      ),
                  ];
                },
                body: IndexedStack(index: _currentIndex, children: const [HomeScreen(), SearchScreen(), ProfileScreen()]),
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
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                  BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
                  BottomNavigationBarItem(icon: Icon(Icons.person), label: 'You'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
