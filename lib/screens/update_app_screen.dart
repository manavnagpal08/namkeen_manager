import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/namkeen_theme.dart';

class UpdateAppScreen extends StatelessWidget {
  final Map<String, dynamic> config;
  final String currentVersion;

  const UpdateAppScreen({
    super.key, 
    required this.config,
    required this.currentVersion,
  });

  @override
  Widget build(BuildContext context) {
    final latestVersion = config['latest_version'] ?? 'Unknown';
    final downloadUrl = config['download_url'] ?? '';
    final updateLog = config['update_log'] ?? 'Bug fixes and performance improvements.';

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.system_update, size: 80, color: Colors.white),
            const SizedBox(height: 32),
            const Text(
              'New Update Available!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Current: $currentVersion  ➔  Latest: $latestVersion',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 32),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(updateLog, style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () async {
                if (downloadUrl.isNotEmpty) {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              child: const Text('Download & Update Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            if (config['force_update'] != true)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Maybe Later', style: TextStyle(color: Colors.white70)),
              ),
          ],
        ),
      ),
    );
  }
}
