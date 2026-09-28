import 'dart:ui';
import 'package:flutter/material.dart';
import '../blocs/audio/audio_bloc.dart';
import '../services/sleep_timer_service.dart';
import '../theme.dart';

void showSleepTimerSheet(BuildContext context, AudioBloc audioBloc) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SleepTimerSheet(audioBloc: audioBloc),
  );
}

class _SleepTimerSheet extends StatelessWidget {
  final AudioBloc audioBloc;
  const _SleepTimerSheet({required this.audioBloc});

  String _formatRemaining(Duration dur) {
    final m = dur.inMinutes;
    final s = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final sleepService = SleepTimerService.instance;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: YTColors.surface.withValues(alpha: 0.92),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: ValueListenableBuilder<bool>(
            valueListenable: sleepService.isActiveNotifier,
            builder: (context, isActive, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.bedtime_rounded, color: YTColors.primary, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Sleep Timer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (isActive)
                          ValueListenableBuilder<Duration?>(
                            valueListenable: sleepService.remainingNotifier,
                            builder: (context, remaining, _) {
                              if (remaining != null) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: YTColors.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatRemaining(remaining),
                                    style: TextStyle(
                                      color: YTColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 24),

                  _buildOption(
                    context,
                    label: '15 Minutes',
                    isSelected: sleepService.activePreset == '15 min',
                    onTap: () {
                      sleepService.startTimer(const Duration(minutes: 15), audioBloc, '15 min');
                      Navigator.pop(context);
                      _showSnackBar(context, 'Sleep timer set for 15 minutes');
                    },
                  ),
                  _buildOption(
                    context,
                    label: '30 Minutes',
                    isSelected: sleepService.activePreset == '30 min',
                    onTap: () {
                      sleepService.startTimer(const Duration(minutes: 30), audioBloc, '30 min');
                      Navigator.pop(context);
                      _showSnackBar(context, 'Sleep timer set for 30 minutes');
                    },
                  ),
                  _buildOption(
                    context,
                    label: '45 Minutes',
                    isSelected: sleepService.activePreset == '45 min',
                    onTap: () {
                      sleepService.startTimer(const Duration(minutes: 45), audioBloc, '45 min');
                      Navigator.pop(context);
                      _showSnackBar(context, 'Sleep timer set for 45 minutes');
                    },
                  ),
                  _buildOption(
                    context,
                    label: '60 Minutes',
                    isSelected: sleepService.activePreset == '60 min',
                    onTap: () {
                      sleepService.startTimer(const Duration(minutes: 60), audioBloc, '60 min');
                      Navigator.pop(context);
                      _showSnackBar(context, 'Sleep timer set for 1 hour');
                    },
                  ),
                  _buildOption(
                    context,
                    label: 'End of Track',
                    isSelected: sleepService.activePreset == 'End of Track',
                    onTap: () {
                      sleepService.startEndOfTrack(audioBloc);
                      Navigator.pop(context);
                      _showSnackBar(context, 'Music will stop at the end of this track');
                    },
                  ),

                  if (isActive) ...[
                    const Divider(color: Colors.white12, height: 16),
                    ListTile(
                      leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                      title: const Text(
                        'Turn Off Timer',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        sleepService.cancel();
                        Navigator.pop(context);
                        _showSnackBar(context, 'Sleep timer cancelled');
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
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
      onTap: onTap,
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
