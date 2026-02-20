import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/app_preferences.dart';
import 'core/theme_controller.dart';
import 'core/language_controller.dart';
import 'core/themes.dart';
import 'core/di/service_locator.dart';
import 'app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'l10n/app_localizations.dart';
import 'services/network/backend_client.dart';
import 'services/network/upload_queue_manager.dart';
import 'services/auth/auth_service.dart';
import 'services/daily_pot_service.dart';
import 'services/tracking/tracking_session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw behind status bar and navigation bar (edge-to-edge)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Initialize dependency injection
  await setupServiceLocator();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // Background initialization - doesn't block UI
  Future<void> _initializeApp() async {
    try {
      // Firebase is required for auth + crashlytics
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Crashlytics: capture Flutter framework errors
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Crashlytics: capture async errors not caught by Flutter
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // Setup auth listener (non-blocking background work)
      _setupAuthTokenSync();

      // No anonymous sign-in - all users must authenticate with Google
      // If not signed in, they'll see the login screen

      // Load preferences
      await AppPreferences.instance.init();

      // Save backend config
      await _persistBackendConfig();

      // Load theme
      await ThemeController.instance.load();

      // Load language preference
      await LanguageController.instance.load();

      // Initialize tracking session manager (restore state from database)
      await TrackingSessionManager.instance.initialize();

      // Initialize upload queue (process pending retries)
      UploadQueueManager.instance.initialize();

      // Initialize daily pot service (non-blocking)
      DailyPotService.instance.initialize().catchError((e) {
        print('Daily pot init failed (non-critical): $e');
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ Initialization error: $e');
      // Still mark as initialized to show UI (with potential error state)
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  void _setupAuthTokenSync() {
    FirebaseAuth.instance.idTokenChanges().listen((User? user) async {
      if (user == null) {
        print('User is currently signed out!');
      } else {
        print('User is signed in: ${user.uid}');
        try {
          final token = await user.getIdToken();
          if (token != null) {
            // Store under the correct double-prefixed key so the native
            // Kotlin uploader reads it via AppPrefs.FIREBASE_AUTH_TOKEN.
            await AppPreferences.instance.setFirebaseAuthToken(token);
            print('Synced Firebase Token to SharedPreferences');

            // Device registration - FIRE AND FORGET (non-blocking)
            AuthService.registerDevice(user).catchError((e) {
              print('Device registration failed (non-critical): $e');
            });
          }
        } catch (e) {
          print('Error syncing token: $e');
        }
      }
    });
  }

  Future<void> _persistBackendConfig() async {
    if (kBackendApiKey.isEmpty) {
      throw Exception(
        'Backend API key not provided!\n\n'
        'Run with: flutter run --dart-define-from-file=dart_defines.json',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_api_key', kBackendApiKey);
    await prefs.setString('backend_url', kBackendBaseUrl);
  }

  @override
  Widget build(BuildContext context) {
    // Show app immediately, even if not fully initialized
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        return MaterialApp(
          title: 'GreenGains',
          debugShowCheckedModeBanner: false,
          // Internationalization support
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('fr'), // French
          ],
          // Use selected language or fall back to system default
          locale: LanguageController.instance.locale,
          theme: AppTheme.theme(),
          darkTheme: AppTheme.themeDark(),
          themeMode: ThemeController.instance.mode,
          themeAnimationDuration: Duration.zero,
          // Show loading indicator if not ready, otherwise show onboarding
          home: _isInitialized
              ? const OnboardingWrapper()
              : const _InitializingScreen(),
        );
      },
    );
  }
}

/// Simple loading screen shown during initialization
class _InitializingScreen extends StatelessWidget {
  const _InitializingScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.surface(isDark),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
    );
  }
}

/// Wrapper that shows onboarding for first-time users
class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  bool _showOnboarding = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = AppPreferences.instance.onboardingComplete;
    if (mounted) {
      setState(() {
        _showOnboarding = !completed;
      });
    }
  }

  Future<void> _handleOnboardingComplete() async {
    await AppPreferences.instance.setOnboardingComplete(true);
    if (!mounted) return;
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _handleOnboardingComplete);
    }

    return const AppShell();
  }
}

