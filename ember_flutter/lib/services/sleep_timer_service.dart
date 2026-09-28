import 'dart:async';
import 'package:flutter/foundation.dart';
import '../blocs/audio/audio_bloc.dart';

class SleepTimerService {
  SleepTimerService._();
  static final SleepTimerService instance = SleepTimerService._();

  Timer? _countdownTimer;
  Duration? _remaining;
  String? _activePreset;
  bool _isEndOfTrack = false;

  StreamSubscription? _trackSub;

  final ValueNotifier<Duration?> remainingNotifier = ValueNotifier(null);
  final ValueNotifier<String?> presetNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isActiveNotifier = ValueNotifier(false);

  bool get isActive => _remaining != null || _isEndOfTrack;
  String? get activePreset => _activePreset;

  void startTimer(Duration duration, AudioBloc audioBloc, String preset) {
    cancel();

    _remaining = duration;
    _activePreset = preset;
    _isEndOfTrack = false;
    _updateNotifiers();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remaining == null || _remaining!.inSeconds <= 0) {
        timer.cancel();
        await _triggerSleep(audioBloc);
        return;
      }

      _remaining = _remaining! - const Duration(seconds: 1);
      remainingNotifier.value = _remaining;

      // Smooth volume fade-out over final 15 seconds
      if (_remaining!.inSeconds <= 15) {
        final factor = (_remaining!.inSeconds / 15.0).clamp(0.0, 1.0);
        try {
          audioBloc.player.setVolume(factor);
        } catch (_) {}
      }
    });
  }

  void startEndOfTrack(AudioBloc audioBloc) {
    cancel();

    _isEndOfTrack = true;
    _activePreset = 'End of Track';
    _updateNotifiers();

    _trackSub = audioBloc.player.positionStream.listen((pos) async {
      final dur = audioBloc.player.duration ?? Duration.zero;
      if (dur.inSeconds > 0) {
        final remainingSeconds = dur.inSeconds - pos.inSeconds;
        if (remainingSeconds <= 15 && remainingSeconds >= 0) {
          final factor = (remainingSeconds / 15.0).clamp(0.0, 1.0);
          try {
            audioBloc.player.setVolume(factor);
          } catch (_) {}
        }
        if (remainingSeconds <= 1 || pos >= dur) {
          await _triggerSleep(audioBloc);
        }
      }
    });
  }

  Future<void> _triggerSleep(AudioBloc audioBloc) async {
    try {
      await audioBloc.player.pause();
      // Restore standard volume for the next session
      await audioBloc.player.setVolume(1.0);
    } catch (_) {}
    cancel();
  }

  void cancel() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _trackSub?.cancel();
    _trackSub = null;
    _remaining = null;
    _activePreset = null;
    _isEndOfTrack = false;
    _updateNotifiers();
  }

  void _updateNotifiers() {
    remainingNotifier.value = _remaining;
    presetNotifier.value = _activePreset;
    isActiveNotifier.value = isActive;
  }
}
