import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../core/namkeen_theme.dart';

class AccessRestrictedScreen extends StatefulWidget {
  final Map<String, dynamic> config;

  const AccessRestrictedScreen({super.key, required this.config});

  @override
  State<AccessRestrictedScreen> createState() => _AccessRestrictedScreenState();
}

class _AccessRestrictedScreenState extends State<AccessRestrictedScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  void _showAdminPanel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter Developer PIN to manage access.'),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = widget.config['admin_pin'] ?? '8008';
              if (_pinController.text == pin) {
                Navigator.pop(ctx);
                _showControlPanel(); // Open the toggle panel
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid PIN'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showControlPanel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Developer Control Panel'),
        content: const Text('Current Status: LOCKED\n\nDo you want to UNLOCK the application?'),
        actions: [
           TextButton(
             onPressed: () => Navigator.pop(ctx),
             child: const Text('Close'),
           ),
           ElevatedButton.icon(
             icon: const Icon(Icons.lock_open),
             label: const Text('UNLOCK APP'),
             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
             onPressed: () async {
               Navigator.pop(ctx);
               setState(() => _isLoading = true);
               try {
                 await Provider.of<DatabaseService>(context, listen: false).updateAppLockStatus(false);
                 // The stream in main.dart will handle navigation
               } catch (e) {
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    setState(() => _isLoading = false);
                 }
               }
             },
           )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.config['lock_message'] ?? 'Trial Period Expired';
    final contact = widget.config['developer_contact'] ?? 'Contact Admin';

    return Scaffold(
      backgroundColor: Colors.red[900],
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'ACCESS RESTRICTED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'For Access Contact:',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      contact,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Hidden Admin Access (Long Press or Subtle Button)
              GestureDetector(
                onLongPress: _showAdminPanel, // Secret Long Press
                onDoubleTap: _showAdminPanel, // Or Double Tap
                child: TextButton.icon(
                  onPressed: _showAdminPanel, 
                  icon: Icon(Icons.admin_panel_settings, color: Colors.white.withOpacity(0.3)),
                  label: Text(
                    'Admin Access', 
                    style: TextStyle(color: Colors.white.withOpacity(0.3))
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
