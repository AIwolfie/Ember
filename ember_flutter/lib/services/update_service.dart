import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  bool get isAvailable => _updater.isAvailable;

  final _updateStreamController = StreamController<bool>.broadcast();
  Stream<bool> get onUpdateReady => _updateStreamController.stream;

  /// Silently checks for and downloads pending patches in the background.
  /// Designed to run during app startup without blocking UI or audio streaming.
  void initBackgroundUpdate() {
    if (!isAvailable) {
      debugPrint(
        '[Shorebird] Code Push is not available in current environment.',
      );
      return;
    }

    Future.microtask(() async {
      try {
        debugPrint('[Shorebird] Checking for OTA updates in background...');
        final status = await _updater.checkForUpdate();
        if (status == UpdateStatus.outdated) {
          debugPrint(
            '[Shorebird] New patch found. Downloading in background...',
          );
          await _updater.update();
          debugPrint(
            '[Shorebird] Patch downloaded successfully. It will activate on next launch.',
          );
          _updateStreamController.add(true);
        } else if (status == UpdateStatus.restartRequired) {
          debugPrint('[Shorebird] Patch is ready. Restart required to apply.');
          _updateStreamController.add(true);
        } else {
          debugPrint('[Shorebird] Ember is up to date.');
        }
      } catch (e) {
        debugPrint('[Shorebird] Background check error: $e');
      }
    });
  }

  /// Checks whether an OTA update is available.
  Future<UpdateStatus> checkForUpdate() async {
    if (!isAvailable) return UpdateStatus.unavailable;
    try {
      return await _updater.checkForUpdate();
    } catch (e) {
      debugPrint('[Shorebird] Error checking for update: $e');
      return UpdateStatus.unavailable;
    }
  }

  /// Downloads and prepares the update for the next app launch.
  Future<bool> downloadUpdate() async {
    if (!isAvailable) return false;
    try {
      await _updater.update();
      return true;
    } catch (e) {
      debugPrint('[Shorebird] Error downloading update: $e');
      return false;
    }
  }

  /// Reads the active patch number if running on a Shorebird build.
  Future<int?> getCurrentPatchNumber() async {
    if (!isAvailable) return null;
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      debugPrint('[Shorebird] Error reading current patch: $e');
      return null;
    }
  }
}
