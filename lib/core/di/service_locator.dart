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
/// Access via: `getIt<ServiceType>()`
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
  getIt.registerSingleton<DatabaseHelper>(DatabaseHelper.instance);
  getIt.registerSingleton<AppEventBus>(AppEventBus.instance);

  await AppPreferences.instance.init();
  getIt.registerSingleton<AppPreferences>(AppPreferences.instance);

  getIt.registerSingleton<ForegroundLocationService>(ForegroundLocationService.instance);
  getIt.registerSingleton<SensorManager>(SensorManager.instance);
  getIt.registerSingleton<UploadQueueManager>(UploadQueueManager.instance);
  getIt.registerSingleton<TrackingSessionManager>(TrackingSessionManager.instance);

  getIt.registerFactory<ContributionRepository>(() => ContributionRepository());
}

/// Extension for easier service access
/// Usage: `context.getService<MyService>()` or `this.getService<MyService>()`
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
