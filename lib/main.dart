import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/namkeen_theme.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'firebase_options.dart';
import 'screens/access_restricted_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'screens/update_app_screen.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize PackageInfo with fallback and timeout
    String currentVersion = "1.0.0+1";
    try {
      if (kIsWeb) {
        // Short timeout for web to avoid white screen hanging
        final packageInfo = await PackageInfo.fromPlatform().timeout(
          const Duration(seconds: 3),
        );
        currentVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
      } else {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
      }
    } catch (e) {
      debugPrint("⚠️ PackageInfo failed to load: $e Using fallback version.");
    }
    
    debugPrint('🚀 APP STARTING... Version: $currentVersion');
    
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10)); // Timeout for Firebase Init
      debugPrint('✅ Firebase Initialized');
    } catch (e) {
      debugPrint("🔴 Firebase Initialization Failed: $e");
      // App might still work offline or show error, but we proceed to runApp
    }
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('🔴 FLUTTER ERROR: ${details.exception.toString()}');
    };

    runApp(NamkeenFactoryApp(currentVersion: currentVersion));
    debugPrint('🚀 runApp called');
  }, (error, stack) {
    debugPrint('🔴 CAUGHT ASYNC ERROR: ${error.toString()}');
  });
}

class NamkeenFactoryApp extends StatelessWidget {
  final String currentVersion;
  const NamkeenFactoryApp({super.key, required this.currentVersion});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
      ],
      child: MaterialApp(
        title: 'Factory Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        builder: (context, child) {
          // Global Gatekeeper (Lock & Version)
          return StreamBuilder<Map<String, dynamic>>(
            stream: DatabaseService().getAppConfig(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final config = snapshot.data!;
                
                // 1. Lock Gatekeeper
                if (config['is_locked'] == true) {
                   return AccessRestrictedScreen(config: config);
                }

                // 2. Version Gatekeeper (Only for Android/iOS)
                final latestVersion = config['latest_version'];
                if (!kIsWeb && latestVersion != null && _isVersionOlder(currentVersion, latestVersion)) {
                  // If it's a force update, we return the Update Screen directly.
                  // Otherwise, the child (app) continues and might show a dialog.
                  // For simplicity: If new version exists, show update screen.
                  return UpdateAppScreen(config: config, currentVersion: currentVersion);
                }
              }
              return child!;
            },
          );
        },
      ),
    );
  }

  bool _isVersionOlder(String current, String latest) {
    try {
      // Version format: 1.0.21+21 -> compare only the build number (the part after +)
      // or compare the semver.
      // Build number is usually safer for internal updates.
      final currentBuild = int.parse(current.split('+').last);
      final latestBuild = int.parse(latest.split('+').last);
      return currentBuild < latestBuild;
    } catch (e) {
      // Fallback: simple string comparison if split fails
      return current != latest;
    }
  }
}
