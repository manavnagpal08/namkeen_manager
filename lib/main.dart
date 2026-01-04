import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/namkeen_theme.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'firebase_options.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
// Replace all prints
    debugPrint('🚀 APP STARTING...');
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase Initialized');
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // Avoid printing complex objects which might cause type errors on Web JS interop
      debugPrint('🔴 FLUTTER ERROR: ${details.exception.toString()}');
    };

    runApp(const NamkeenFactoryApp());
    debugPrint('🚀 runApp called');
  }, (error, stack) {
    // Avoid casting error to specific types
    debugPrint('🔴 CAUGHT ASYNC ERROR: ${error.toString()}');
  });
}

class NamkeenFactoryApp extends StatelessWidget {
  const NamkeenFactoryApp({super.key});

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
      ),
    );
  }
}
