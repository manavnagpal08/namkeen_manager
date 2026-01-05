import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/namkeen_theme.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  // Helper to open URLs
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Replace with your actual GitHub Repo URL
    const String repoUrl = "https://github.com/manavnagpal08/namkeen_manager";
    const String latestReleaseUrl = "$repoUrl/releases/latest";
    
    // Direct download links (GitHub automatically redirects 'latest' to the version tag)
    // Note: This relies on the consistent naming convention in release.yml
    const String apkDownloadUrl = "$repoUrl/releases/latest/download/app-release.apk";
    const String exeDownloadUrl = "$repoUrl/releases/latest/download/app-release-windows.zip"; // Or .exe if raw

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support & Updates'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Branding
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
              ),
              child: const Icon(Icons.verified, size: 60, color: AppTheme.primary), // Placeholder for Logo
            ),
            const SizedBox(height: 16),
            const Text(
              'Powered by FLIP CLIP',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Premium Factory Management Solutions',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            
            const SizedBox(height: 40),

            // Contact Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('Need Help?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.person, color: AppTheme.primary),
                      title: const Text('Contact: Manav Nagpal'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone, color: AppTheme.primary),
                      title: const Text('+91 98765 43210'), // Replace with actual if known, or general support
                      onTap: () => _launchUrl("tel:+919876543210"),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email, color: AppTheme.primary),
                      title: const Text('support@flipclip.com'), // Replace
                      onTap: () => _launchUrl("mailto:support@flipclip.com"),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 30),

            // Download Section
            const Text(
              'Get Latest Version',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Download and install the latest updates directly.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _DownloadButton(
                  icon: Icons.android,
                  label: 'Download APK (Android)',
                  color: Colors.green,
                  onPressed: () => _launchUrl(apkDownloadUrl),
                ),
                _DownloadButton(
                  icon: Icons.desktop_windows,
                  label: 'Download EXE (Windows)',
                  color: Colors.blueAccent,
                  onPressed: () => _launchUrl(exeDownloadUrl),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => _launchUrl(latestReleaseUrl),
              child: const Text('View Release Notes on GitHub'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _DownloadButton({required this.icon, required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      label: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }
}
