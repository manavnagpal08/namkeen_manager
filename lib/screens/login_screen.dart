import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/glass_container.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/department_account_model.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passController = TextEditingController();
  
  String? _selectedDept;
  bool _isLoading = false; 

  @override
  Widget build(BuildContext context) {
    // We use a StreamBuilder to get available departments for the dropdown
    final db = Provider.of<DatabaseService>(context);

    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55), // dark overlay
          ),
          child: Center(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 900),

              child: SizedBox(
                width: isDesktop ? 420 : 340,
                child: GlassContainer(
                  padding: const EdgeInsets.all(32),
                  borderRadius: 28,
                  blur: 18,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Heading
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.orange, Colors.deepOrangeAccent],
                        ).createShader(bounds),
                        child: const Text(
                          "FACTORY MANAGER",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Secure Department Login",
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 30),

                      // Department Dropdown
                      StreamBuilder<List<DepartmentAccountModel>>(
                        stream: db.getDepartmentAccounts(),
                        builder: (context, snapshot) {
                          List<String> deptNames = snapshot.hasData
                              ? snapshot.data!.map((a) => a.departmentName).toList()
                              : [];

                          if (!deptNames.contains('Admin')) deptNames.insert(0, 'Admin');
                          if (!deptNames.contains('admin2')) deptNames.insert(1, 'admin2');
                          return DropdownButtonFormField<String>(
                            value: _selectedDept,
                            hint: const Text("Select Department", style: TextStyle(fontSize: 14)),
                            isExpanded: true,
                            items: deptNames
                                .map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d, child: Text(d)))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedDept = val),
                            dropdownColor: Colors.black87,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.1),
                              prefixIcon: const Icon(Icons.apartment, color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // Password Field
                      TextField(
                        controller: _passController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white70),
                          hintText: "Enter Access Code",
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Login Button
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.orangeAccent)
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 6,
                                  backgroundColor: Colors.orange,
                                  shadowColor: Colors.deepOrangeAccent.withValues(alpha: 0.4),
                                ),
                                child: const Text(
                                  "LOGIN",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                      const SizedBox(height: 12),

                      // Footer
                      // Footer
                      const SizedBox(height: 20),
                      const Text(
                        "Support: Manav Nagpal",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                         onTap: () => launchUrl(Uri.parse("tel:+919896817707")),
                         child: const Text(
                           "+91 98968 17707",
                           style: TextStyle(color: Colors.orangeAccent, fontSize: 13, decoration: TextDecoration.underline),
                         ),
                      ),
                      const SizedBox(height: 4),
                       const Text(
                        "manav.nagpal2005@gmail.com",
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        ),
    );
  } 

  Future<void> _handleLogin() async {
    if (_selectedDept == null || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select department and enter password')));
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);

    setState(() => _isLoading = true);
    
    // Simulate network delay for "Connect Status" feel
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final success = await auth.login(_selectedDept!, _passController.text.trim());
      
      if (success) {
        if (mounted) {
           Navigator.pushReplacement(
             context, 
             MaterialPageRoute(builder: (_) => const DashboardScreen()),
           );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access Denied: Invalid Credentials'), backgroundColor: Colors.red));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
