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
      extendBodyBehindAppBar: true, // Allow gradient to show behind app bar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Fallback Unlock Button in AppBar (Always works)
          IconButton(
            icon: const Icon(Icons.lock_open, color: Colors.white24),
            onPressed: _showAdminPanel,
            tooltip: 'Admin Unlock',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B0000), Color(0xFF2B0000)], // Deep Red Gradient
          ),
        ),
        child: SelectionArea( // Allows text copying
          child: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // SECRET TRIGGER 1: Long Press the Lock Icon
                      GestureDetector(
                      onLongPress: _showAdminPanel,
                      onDoubleTap: _showAdminPanel,
                      behavior: HitTestBehavior.opaque, // CRITICAL: Captures touches on transparent pixels
                      child: Container(
                        // Invisible touch target padding to make it easier to hit
                        padding: const EdgeInsets.all(32), 
                        child: const Icon(Icons.lock_rounded, size: 80, color: Colors.white24),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Alert Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                           BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        children: [
                          // SECRET TRIGGER 2: Long Press the Title
                          GestureDetector(
                            onLongPress: _showAdminPanel,
                            child: const Text(
                              'ACCESS RESTRICTED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            message,
                            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Contact Details
                    const Text(
                      'Contact Administrator',
                      style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildContactCard(
                      name: 'Manav Nagpal',
                      email: 'manav.nagpal2005@gmail.com',
                      phone: '+91 98968 17707',
                    ),

                    const Spacer(),
                    // No visible button
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    ), // Close Container and SelectionArea
    );
  }

  Widget _buildContactCard({required String name, required String email, required String phone}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white10, thickness: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Text(phone, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email, color: Colors.orangeAccent, size: 18),
              const SizedBox(width: 8),
              Text(email, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

