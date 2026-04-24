import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/app_preferences.dart';
import 'core/theme_controller.dart';
import 'core/language_controller.dart';
import 'core/themes.dart';
import 'core/branding.dart';
import 'core/di/service_locator.dart';
import 'app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'l10n/app_localizations.dart';
import 'services/network/backend_client.dart';
import 'services/auth/auth_service.dart';
import 'services/tracking/tracking_session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting();
  // Register timeago locale messages for all supported languages
  timeago.setLocaleMessages('fr', timeago.FrMessages());

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

      // Crashlytics: disable in debug to avoid polluting production reports
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

      // Crashlytics: capture Flutter framework errors
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Crashlytics: capture async errors not caught by Flutter
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // Setup auth listener (non-blocking background work — also sets Crashlytics user ID)
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

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
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
        debugPrint('User is currently signed out!');
        FirebaseCrashlytics.instance.setUserIdentifier('');
      } else {
        debugPrint('User is signed in: ${user.uid}');
        // Tag crash reports with the user's UID for faster triage
        FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
        try {
          final token = await user.getIdToken();
          if (token != null) {
            // Store under the correct double-prefixed key so the native
            // Kotlin uploader reads it via AppPrefs.FIREBASE_AUTH_TOKEN.
            await AppPreferences.instance.setFirebaseAuthToken(token);
            debugPrint('Synced Firebase Token to SharedPreferences');

            // Device registration - FIRE AND FORGET (non-blocking)
            AuthService.registerDevice(user).catchError((e) {
              debugPrint('Device registration failed (non-critical): $e');
            });
          }
        } catch (e) {
          debugPrint('Error syncing token: $e');
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
          title: Branding.appDisplayName,
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

/// Wrapper that reacts to Firebase auth state.
/// - Signed in + onboarding done  → AppShell
/// - Signed in + onboarding not done → OnboardingScreen (page 0)
/// - Signed out + onboarding done  → OnboardingScreen (page 1 — sign-in only)
/// - Signed out + onboarding not done → OnboardingScreen (page 0)
class OnboardingWrapper extends StatelessWidget {
  const OnboardingWrapper({super.key});

  Future<void> _handleOnboardingComplete() async {
    await AppPreferences.instance.setOnboardingComplete(true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _InitializingScreen();
        }

        final user = snapshot.data;
        final onboardingDone = AppPreferences.instance.onboardingComplete;

        if (user != null && onboardingDone) {
          return const AppShell();
        }

        // Skip welcome page if user already completed onboarding but signed out
        final startPage = (onboardingDone && user == null) ? 1 : 0;
        return OnboardingScreen(
          onComplete: _handleOnboardingComplete,
          initialPage: startPage,
        );
      },
    );
  }
}

