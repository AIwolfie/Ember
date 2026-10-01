import 'package:ember_flutter/blocs/storage/storage_bloc.dart';
import 'package:ember_flutter/blocs/storage/storage_event.dart';
import 'package:ember_flutter/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update_service.dart';
import '../about/about_screen.dart';

void showSettingsSheet(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, EmberThemeOption>(
      builder: (context, activeTheme) {
        return Scaffold(
          backgroundColor: YTColors.background,
          appBar: AppBar(
            backgroundColor: YTColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 32,
            ),
            children: [
              const SizedBox(height: 16),
              // Theme selector header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette_rounded, color: activeTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Theme Palette',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Customize the visual ambience across your player',
                      style: TextStyle(color: YTColors.secondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Horizontal Ribbon for Themes
              SizedBox(
                height: 120, // Enough height for card + padding
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: EmberThemes.all.length,
                  itemBuilder: (context, index) {
                    final theme = EmberThemes.all[index];
                    final isSelected = theme.id == activeTheme.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () => context.read<ThemeCubit>().setTheme(theme),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 140,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? theme.primary.withValues(alpha: 0.14) : YTColors.surfaceLight.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? theme.primary : Colors.white.withValues(alpha: 0.08),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [theme.primary, theme.accent, theme.background],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        if (isSelected)
                                          BoxShadow(color: theme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                  ),
                                  if (isSelected) Icon(Icons.check_circle_rounded, color: theme.primary, size: 20),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                theme.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                theme.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: YTColors.secondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              const Divider(color: Colors.white12, height: 32),

              // Storage and Data Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.storage_rounded, color: activeTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Data & History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: YTColors.surfaceLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
                          child: const Icon(Icons.clear_all_rounded, color: Colors.white70, size: 20),
                        ),
                        title: const Text('Clear Search History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                        subtitle: const Text('Remove all stored recent search queries', style: TextStyle(color: YTColors.secondary, fontSize: 12)),
                        onTap: () {
                          context.read<StorageBloc>().add(StorageClearSearch());
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Search history cleared'), backgroundColor: activeTheme.primary));
                        },
                      ),
                      Divider(color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 64),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
                          child: const Icon(Icons.history_toggle_off_rounded, color: Colors.white70, size: 20),
                        ),
                        title: const Text('Clear Playback History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                        subtitle: const Text('Remove recently played tracks', style: TextStyle(color: YTColors.secondary, fontSize: 12)),
                        onTap: () {
                          context.read<StorageBloc>().add(StorageClearPlayHistory());
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Playback history cleared'), backgroundColor: activeTheme.primary));
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(color: Colors.white12, height: 32),

              // Updates (Shorebird OTA)
              const SizedBox(height: 16),
              // Updates (Shorebird OTA)
              _UpdateSection(activePrimary: activeTheme.primary),

              // About Link
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: YTColors.surfaceLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: activeTheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(Icons.info_outline_rounded, color: activeTheme.primary, size: 20),
                    ),
                    title: const Text('About Ember', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('v1.0.0 • Mayank & Kenil', style: TextStyle(color: YTColors.secondary, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _UpdateSection extends StatefulWidget {
  final Color activePrimary;
  const _UpdateSection({required this.activePrimary});

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
    final apkUrl = UpdateService.instance.availableApkUrl;
    if (apkUrl != null) {
      final uri = Uri.parse(apkUrl);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Failed to launch URL: $e');
      }
      return;
    }

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
    final versionDisplay = _patchNumber != null ? 'Version 1.0.0 • Patch $_patchNumber' : 'Version 1.0.0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: YTColors.surfaceLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOutdated ? widget.activePrimary : Colors.white.withValues(alpha: 0.06),
            width: isOutdated ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOutdated ? Icons.system_update_rounded : Icons.cloud_done_rounded,
                  color: isOutdated ? widget.activePrimary : Colors.white70,
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
                    backgroundColor: widget.activePrimary,
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
