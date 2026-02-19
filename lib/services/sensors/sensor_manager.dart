import 'dart:async';
import '../location/foreground_location_service.dart';
import '../../models/sensor_models.dart';

/// Unified sensor data access layer.
///
/// Delegates to [ForegroundLocationService] which handles native Android
/// method channel communication. Provides typed, filtered streams for
/// each sensor type used by the app.
///
/// Usage:
/// ```dart
/// final sensors = SensorManager.instance;
/// await sensors.start();
/// sensors.accelerometer$.listen((data) => print(data.magnitude));
/// ```
class SensorManager {
  SensorManager._();
  static final SensorManager instance = SensorManager._();

  final ForegroundLocationService _foreground = ForegroundLocationService.instance;

  bool _running = false;
  bool get isRunning => _running;

  // Expose typed streams from the native foreground service
  Stream<AccelerometerData> get accelerometer$ => _foreground.accelerometerStream;
  Stream<GyroscopeData> get gyroscope$ => _foreground.gyroscopeStream;
  Stream<LightData> get light$ => _foreground.lightStream;
  Stream<PressureData> get pressure$ => _foreground.pressureStream;
  Stream<LocationData> get location$ => _foreground.locationStream;

  /// Start the native foreground service and begin collecting sensor data.
  Future<void> start() async {
    if (_running) return;
    await _foreground.start();
    _running = true;
  }

  /// Stop sensor collection and the foreground service.
  Future<void> stop() async {
    if (!_running) return;
    await _foreground.stop();
    _running = false;
  }

  /// Pause tracking without stopping the service.
  Future<void> pause() async {
    await _foreground.pauseTracking();
  }

  /// Resume tracking after a pause.
  Future<void> resume() async {
    await _foreground.resumeTracking();
  }

  /// Check if the native service is currently running.
  Future<bool> isServiceRunning() async {
    return await _foreground.isServiceRunning();
  }

  /// Flush native sensor buffers for fresh data.
  Future<void> flush() async {
    await _foreground.flushSensorBuffers();
  }
}
