import 'dart:ui';
import 'package:flutter/material.dart';
import '../blocs/audio/audio_bloc.dart';
import '../theme.dart';

void showPlaybackSpeedSheet(BuildContext context, AudioBloc audioBloc) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PlaybackSpeedSheet(audioBloc: audioBloc),
  );
}

class _PlaybackSpeedSheet extends StatefulWidget {
  final AudioBloc audioBloc;
  const _PlaybackSpeedSheet({required this.audioBloc});

  @override
  State<_PlaybackSpeedSheet> createState() => _PlaybackSpeedSheetState();
}

class _PlaybackSpeedSheetState extends State<_PlaybackSpeedSheet> {
  static const List<double> _speeds = [0.75, 0.8, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final currentSpeed = widget.audioBloc.player.speed;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: YTColors.surface.withValues(alpha: 0.92),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.speed_rounded, color: YTColors.primary, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Playback Speed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 24),
              ..._speeds.map((speed) {
                final isSelected = (currentSpeed - speed).abs() < 0.05;
                final label = speed == 1.0 ? '1.0x (Normal)' : '${speed}x';
                return ListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? YTColors.primary : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: YTColors.primary, size: 20)
                      : null,
                  onTap: () {
                    widget.audioBloc.player.setSpeed(speed);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
