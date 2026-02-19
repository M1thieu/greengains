import 'package:get_it/get_it.dart';
import '../../data/local/database_helper.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../services/location/foreground_location_service.dart';
import '../../services/sensors/sensor_manager.dart';
import '../../services/network/upload_queue_manager.dart';
import '../../services/tracking/tracking_session_manager.dart';
import '../../core/events/app_events.dart';
import '../../core/app_preferences.dart';

/// Global service locator instance
/// Access via: getIt<ServiceType>()
final getIt = GetIt.instance;

/// Initialize all dependencies
/// MUST be called ONCE in main() before runApp()
///
/// Usage in main.dart:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await setupServiceLocator();
///   runApp(MyApp());
/// }
/// ```
Future<void> setupServiceLocator() async {
  print('[ServiceLocator] Initializing...');

  // ===== CORE SERVICES (Singletons) =====

  /// SQLite database instance
  getIt.registerSingleton<DatabaseHelper>(DatabaseHelper.instance);
  print('[ServiceLocator] ✅ DatabaseHelper registered');

  /// Event bus for reactive updates
  getIt.registerSingleton<AppEventBus>(AppEventBus.instance);
  print('[ServiceLocator] ✅ AppEventBus registered');

  /// SharedPreferences wrapper
  await AppPreferences.instance.init(); // Ensure initialized
  getIt.registerSingleton<AppPreferences>(AppPreferences.instance);
  print('[ServiceLocator] ✅ AppPreferences registered');

  // ===== BUSINESS LOGIC SERVICES (Singletons) =====

  /// Foreground location/sensor service
  getIt.registerSingleton<ForegroundLocationService>(
    ForegroundLocationService.instance,
  );
  print('[ServiceLocator] ✅ ForegroundLocationService registered');

  /// Unified sensor manager (wraps ForegroundLocationService)
  getIt.registerSingleton<SensorManager>(SensorManager.instance);
  print('[ServiceLocator] ✅ SensorManager registered');

  /// Upload queue manager (retry failed uploads)
  getIt.registerSingleton<UploadQueueManager>(UploadQueueManager.instance);
  print('[ServiceLocator] ✅ UploadQueueManager registered');

  // DailyPotService requires Firebase - initialized later in main.dart after Firebase.initializeApp()

  /// Tracking session manager
  getIt.registerSingleton<TrackingSessionManager>(
    TrackingSessionManager.instance,
  );
  print('[ServiceLocator] ✅ TrackingSessionManager registered');

  // ===== REPOSITORIES (Factories) =====
  // Lightweight objects, can create new instances as needed

  /// Contribution data repository
  getIt.registerFactory<ContributionRepository>(
    () => ContributionRepository(),
  );
  print('[ServiceLocator] ✅ ContributionRepository registered');

  // ===== CONTROLLERS (Factories) =====
  // Will be registered here as we create them
  // Example:
  // getIt.registerFactory<HomeController>(
  //   () => HomeController(
  //     contributionRepo: getIt<ContributionRepository>(),
  //     locationService: getIt<ForegroundLocationService>(),
  //   ),
  // );

  print('[ServiceLocator] ✅ All services registered successfully');
}

/// Reset service locator (useful for testing)
/// DO NOT call in production code
Future<void> resetServiceLocator() async {
  await getIt.reset();
  print('[ServiceLocator] ⚠️ Reset complete');
}

/// Extension for easier service access
/// Usage: context.getService<MyService>() or this.getService<MyService>()
extension ServiceLocatorExtension on Object {
  T getService<T extends Object>() => getIt<T>();
}

/// Check if service is registered
bool isServiceRegistered<T extends Object>() {
  return getIt.isRegistered<T>();
}

/// Get service if registered, otherwise null
T? tryGetService<T extends Object>() {
  try {
    return getIt<T>();
  } catch (e) {
    return null;
  }
}
