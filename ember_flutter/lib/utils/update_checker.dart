import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static const String _repoUrl = 'https://api.github.com/repos/KenilPatel0/Ember/releases/latest';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(_repoUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String latestVersion = data['tag_name'] as String;
        
        // Remove 'v' prefix if present
        if (latestVersion.startsWith('v')) {
          latestVersion = latestVersion.substring(1);
        }

        // Simple version comparison
        if (_isNewerVersion(currentVersion, latestVersion)) {
          final downloadUrl = data['html_url'] as String;
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, downloadUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  static bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final curr = i < currentParts.length ? currentParts[i] : 0;
        final lat = i < latestParts.length ? latestParts[i] : 0;
        
        if (lat > curr) return true;
        if (lat < curr) return false;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String newVersion, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Update Available 🚀', style: TextStyle(color: Colors.white)),
          content: Text(
            'A new version of Ember (v$newVersion) is available! Please update to get the latest features and bug fixes.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              child: const Text('Download Update', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }
}
