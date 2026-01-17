import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../core/namkeen_theme.dart';
import '../../services/database_service.dart';

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
    const String apkDownloadUrl = "$repoUrl/releases/latest/download/namkeen_manager.apk";
    const String exeDownloadUrl = "$repoUrl/releases/latest/download/namkeen_manager_windows.zip";
    const String iosDownloadUrl = "$repoUrl/releases/latest/download/namkeen_manager_ios.zip";

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
            GestureDetector(
              onDoubleTap: () => _showAdminBlockPanel(context),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(blurRadius: 15, color: Colors.blue.withOpacity(0.1))],
                  border: Border.all(color: AppTheme.primary.withOpacity(0.1), width: 2),
                ),
                child: const Icon(Icons.rocket_launch, size: 64, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Powered by FLIP CLIP',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'Premium Factory Management Solutions',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            
            const SizedBox(height: 48),

            // Contact Card
            Card(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text('Need Help?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                        child: const Icon(Icons.person, color: AppTheme.primary),
                      ),
                      title: const Text('Contact', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: const Text('Manav Nagpal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                        child: const Icon(Icons.phone, color: Colors.green),
                      ),
                      title: const Text('Phone', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: const Text('+91 98968 17707', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      onTap: () => _launchUrl("tel:+919896817707"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.orange[50], shape: BoxShape.circle),
                        child: const Icon(Icons.email, color: Colors.orange),
                      ),
                      title: const Text('Email', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: const Text('manav.nagpal2005@gmail.com', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                      onTap: () => _launchUrl("mailto:manav.nagpal2005@gmail.com"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Download Section
            const Text(
              'Get Latest Version',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'For Android, Windows & iOS',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _DownloadButton(
                  icon: Icons.android,
                  label: 'Download APK',
                  color: const Color(0xFF3DDC84), // Android Green
                  onPressed: () => _launchUrl(apkDownloadUrl),
                ),
                _DownloadButton(
                  icon: Icons.desktop_windows,
                  label: 'Download EXE',
                  color: const Color(0xFF0078D7), // Windows Blue
                  onPressed: () => _launchUrl(exeDownloadUrl),
                ),
                _DownloadButton(
                  icon: Icons.apple,
                  label: 'Download iOS',
                  color: Colors.black,
                  onPressed: () => _launchUrl(iosDownloadUrl),
                ),
                _DownloadButton(
                  icon: Icons.language,
                  label: 'Open Web App (iOS)',
                  color: Colors.deepPurple,
                  onPressed: () => _launchUrl("https://sangambyfc.web.app"),
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

  void _showAdminBlockPanel(BuildContext context) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Developer Controls'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter Developer PIN to manage site access.'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN', border: OutlineInputBorder()),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              // Fetch proper PIN if possible, or use default
              if (pinController.text == '8008') {
                Navigator.pop(ctx);
                _showBlockConfirmDialog(context);
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN'), backgroundColor: Colors.red));
              }
            }, 
            child: const Text('Access')
          )
        ],
      )
    );
  }

  void _showBlockConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ REMOTE LOCK'),
        content: const Text(
          'Are you sure you want to LOCK this application?\n\n'
          '- The user will be immediately blocked.\n'
          '- They will see a "Trial Expired" screen.\n'
          '- You can unlock it using the PIN on that screen OR via Firestore.',
        ),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
           ElevatedButton.icon(
             icon: const Icon(Icons.block, color: Colors.white),
             label: const Text('LOCK APP NOW'),
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
             onPressed: () async {
                Navigator.pop(ctx);
                try {
                   await Provider.of<DatabaseService>(context, listen: false).updateAppLockStatus(true);
                   if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App Locked Successfully')));
                   }
                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
             },
           )
        ],
      )
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
