import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../blocs/storage/storage_bloc.dart';
import '../blocs/storage/storage_event.dart';
import '../screens/about_screen.dart';
import '../services/update_service.dart';
import '../theme.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, EmberThemeOption>(
      builder: (context, activeTheme) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: YTColors.surface.withValues(alpha: 0.92),
              padding: EdgeInsets.only(
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag pill
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.settings_rounded,
                                color: YTColors.primary,
                                size: 26,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Settings',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white12, height: 24),

                    // Theme selector header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.palette_rounded,
                                color: YTColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Theme Palette',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Customize the visual ambience across your player',
                            style: TextStyle(
                              color: YTColors.secondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 5 Handcrafted Theme Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: EmberThemes.all.map((theme) {
                          final isSelected = theme.id == activeTheme.id;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  context.read<ThemeCubit>().setTheme(theme);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.primary.withValues(alpha: 0.14)
                                        : YTColors.surfaceLight.withValues(
                                            alpha: 0.4,
                                          ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.primary
                                          : Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                      width: isSelected ? 1.8 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Theme Swatch circle
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              theme.primary,
                                              theme.accent,
                                              theme.background,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.primary.withValues(
                                                alpha: 0.35,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              theme.name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              theme.description,
                                              style: const TextStyle(
                                                color: YTColors.secondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: theme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            color: Colors.black,
                                            size: 16,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const Divider(color: Colors.white12, height: 32),

                    // Storage and Data Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storage_rounded,
                            color: YTColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Data & History',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    ListTile(
                      leading: const Icon(
                        Icons.clear_all_rounded,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Clear Search History',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Remove all stored recent search queries',
                        style: TextStyle(
                          color: YTColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        context.read<StorageBloc>().add(StorageClearSearch());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Search history cleared'),
                          ),
                        );
                      },
                    ),

                    ListTile(
                      leading: const Icon(
                        Icons.history_toggle_off_rounded,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Clear Playback History',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Remove recently played tracks',
                        style: TextStyle(
                          color: YTColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        context.read<StorageBloc>().add(
                          StorageClearPlayHistory(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Playback history cleared'),
                          ),
                        );
                      },
                    ),

                    const Divider(color: Colors.white12, height: 32),

                    // Updates (Shorebird OTA)
                    const _UpdateSection(),

                    const Divider(color: Colors.white12, height: 32),

                    // About Link
                    ListTile(
                      leading: const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'About Ember',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'v1.0.0 • Mayank Malaviya & Kenil Ribadiya',
                        style: TextStyle(
                          color: YTColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white38,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UpdateSection extends StatefulWidget {
  const _UpdateSection();

  @override
  State<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<_UpdateSection> {
  bool _checking = false;
  bool _downloading = false;
  int? _patchNumber;
  UpdateStatus? _status;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _loadPatchNumber();
  }

  Future<void> _loadPatchNumber() async {
    final patch = await UpdateService.instance.getCurrentPatchNumber();
    if (mounted) {
      setState(() {
        _patchNumber = patch;
      });
    }
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _checking = true;
      _feedback = null;
    });

    final status = await UpdateService.instance.checkForUpdate();
    if (mounted) {
      setState(() {
        _checking = false;
        _status = status;
        if (status == UpdateStatus.upToDate) {
          _feedback = 'Ember is up to date';
        } else if (status == UpdateStatus.outdated) {
          _feedback = 'A new Ember update is ready.';
        } else if (status == UpdateStatus.restartRequired) {
          _feedback = 'Update downloaded. Restart Ember to apply.';
        } else {
          _feedback = 'Ember is up to date';
        }
      });
    }
  }

  Future<void> _applyUpdate() async {
    setState(() {
      _downloading = true;
    });
    final success = await UpdateService.instance.downloadUpdate();
    if (mounted) {
      setState(() {
        _downloading = false;
        if (success) {
          _status = UpdateStatus.restartRequired;
          _feedback = 'Update installed! Restart Ember to apply.';
        } else {
          _feedback = 'Failed to download update. Please retry.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutdated = _status == UpdateStatus.outdated;
    final isRestartRequired = _status == UpdateStatus.restartRequired;
    final versionDisplay = _patchNumber != null
        ? 'Version 1.0.0 • Patch $_patchNumber'
        : 'Version 1.0.0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: YTColors.surfaceLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOutdated
                ? YTColors.primary
                : Colors.white.withValues(alpha: 0.06),
            width: isOutdated ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOutdated
                      ? Icons.system_update_rounded
                      : Icons.cloud_done_rounded,
                  color: isOutdated ? YTColors.primary : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isOutdated ? 'Update available' : 'Updates',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  versionDisplay,
                  style: const TextStyle(
                    color: YTColors.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _feedback ?? 'Ember is up to date',
              style: TextStyle(
                color: isOutdated ? Colors.white : YTColors.secondary,
                fontSize: 13,
                fontWeight: isOutdated ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 12),
            if (isOutdated)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _downloading ? null : _applyUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: YTColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: _downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    _downloading ? 'Downloading patch...' : 'Update now',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else if (!isRestartRequired)
              OutlinedButton.icon(
                onPressed: _checking ? null : _checkUpdate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                icon: _checking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  _checking ? 'Checking...' : 'Check for updates',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
