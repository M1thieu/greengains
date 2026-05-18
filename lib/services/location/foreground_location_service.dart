import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/app_preferences.dart';
import '../../core/events/app_events.dart';
import '../../models/sensor_models.dart';
import '../tracking/tracking_session_manager.dart';

/// Service for managing the native Android foreground service for sensor data collection
class ForegroundLocationService {
  static const _fgChannel = MethodChannel('greengains/foreground');
  static const _sensorTriggerChannel = MethodChannel('greengains/sensor_trigger');

  final _locationController = StreamController<LocationData>.broadcast();
  final _lightController = StreamController<LightData>.broadcast();
  final _accelerometerController = StreamController<AccelerometerData>.broadcast();
  final _gyroscopeController = StreamController<GyroscopeData>.broadcast();
  final _pressureController = StreamController<PressureData>.broadcast();
  final _magneticFieldController = StreamController<MagneticFieldData>.broadcast();
  final _isRunningNotifier = ValueNotifier<bool>(false);
  final _isPausedNotifier = ValueNotifier<bool>(false);
  final pendingReadings = ValueNotifier<int>(0);

  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<LightData> get lightStream => _lightController.stream;
  Stream<AccelerometerData> get accelerometerStream => _accelerometerController.stream;
  Stream<GyroscopeData> get gyroscopeStream => _gyroscopeController.stream;
  Stream<PressureData> get pressureStream => _pressureController.stream;
  Stream<MagneticFieldData> get magneticFieldStream => _magneticFieldController.stream;
  ValueListenable<bool> get isRunning => _isRunningNotifier;
  ValueListenable<bool> get isPaused => _isPausedNotifier;

  LocationData? _lastLocation;
  LocationData? get lastLocation => _lastLocation;

  LightData? _lastLight;
  LightData? get lastLight => _lastLight;

  AccelerometerData? _lastAccelerometer;
  AccelerometerData? get lastAccelerometer => _lastAccelerometer;

  GyroscopeData? _lastGyroscope;
  GyroscopeData? get lastGyroscope => _lastGyroscope;

  PressureData? _lastPressure;
  PressureData? get lastPressure => _lastPressure;

  MagneticFieldData? _lastMagneticField;
  MagneticFieldData? get lastMagneticField => _lastMagneticField;

  // Consolidated upload status exposed to the UI
  final ValueNotifier<UploadStatusSnapshot> uploadStatus =
      ValueNotifier(const UploadStatusSnapshot());

  /// Live sensor snapshot — fires on every light or pressure update.
  /// Null fields = sensor hasn't reported yet this session.
  final liveConditions = ValueNotifier<({int? lux, double? hpa, double? rms})>(
    (lux: null, hpa: null, rms: null),
  );

  final _sessionManager = TrackingSessionManager.instance;

  ForegroundLocationService._() {
    _setupMethodCallHandler();
    unawaited(_bootstrapUploadStatus());
    _loadPersistedSensorValues();
  }

  static final ForegroundLocationService instance = ForegroundLocationService._();

  /// Load last known sensor values from storage for instant display
  void _loadPersistedSensorValues() {
    final prefs = AppPreferences.instance;

    // Load last light reading
    final light = prefs.getLastLight();
    if (light != null) {
      _lastLight = LightData(
        lux: light['lux'] as double,
        timestamp: light['timestamp'] as int,
      );
    }

    // Load last pressure reading
    final pressure = prefs.getLastPressure();
    if (pressure != null) {
      _lastPressure = PressureData(
        hPa: pressure['hPa'] as double,
        timestamp: pressure['timestamp'] as int,
      );
    }

    // Load last magnetic reading (magnitude only — x/y/z are orientation-dependent)
    final magnetic = prefs.getLastMagnetic();
    if (magnetic != null) {
      _lastMagneticField = MagneticFieldData(
        x: 0, y: 0, z: 0,
        magnitude: magnetic['magnitude'] as double,
        timestamp: magnetic['timestamp'] as int,
      );
    }
  }

  void _setupMethodCallHandler() {
    _sensorTriggerChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onLocationUpdate':
          final location = LocationData.fromMap(call.arguments as Map);
          _lastLocation = location;
          _locationController.add(location);
          break;
        case 'onLightUpdate':
          final light = LightData.fromMap(call.arguments as Map);
          _lastLight = light;
          _lightController.add(light);
          unawaited(AppPreferences.instance.saveLastLight(light.lux, light.timestamp));
          liveConditions.value = (lux: light.lux.round(), hpa: liveConditions.value.hpa, rms: liveConditions.value.rms);
          break;
        case 'onAccelerometerUpdate':
          final accel = AccelerometerData.fromMap(call.arguments as Map);
          _lastAccelerometer = accel;
          _accelerometerController.add(accel);
          liveConditions.value = (lux: liveConditions.value.lux, hpa: liveConditions.value.hpa, rms: accel.magnitude);
          break;
        case 'onGyroscopeUpdate':
          final gyro = GyroscopeData.fromMap(call.arguments as Map);
          _lastGyroscope = gyro;
          _gyroscopeController.add(gyro);
          break;
        case 'onPressureUpdate':
          final pressure = PressureData.fromMap(call.arguments as Map);
          _lastPressure = pressure;
          _pressureController.add(pressure);
          unawaited(AppPreferences.instance.saveLastPressure(pressure.hPa, pressure.timestamp));
          liveConditions.value = (lux: liveConditions.value.lux, hpa: pressure.hPa, rms: liveConditions.value.rms);
          break;
        case 'onMagneticFieldUpdate':
          final magnetic = MagneticFieldData.fromMap(call.arguments as Map);
          _lastMagneticField = magnetic;
          _magneticFieldController.add(magnetic);
          unawaited(AppPreferences.instance.saveLastMagnetic(magnetic.magnitude, magnetic.timestamp));
          break;
        case 'collectSensors':
          // This is called periodically by the native service
          // We don't need to do anything here for now
          break;
        case 'onNativeUploadStatus':
          _handleNativeUploadStatus(call.arguments as Map);
          break;
        case 'onBufferUpdate':
          pendingReadings.value = (call.arguments as num?)?.toInt() ?? 0;
          break;
        case 'onTrackingPaused':
          final paused = (call.arguments as bool?) ?? false;
          _isPausedNotifier.value = paused;
          break;
        case 'onServiceStopped':
          _isRunningNotifier.value = false;
          _isPausedNotifier.value = false;
          pendingReadings.value = 0;
          uploadStatus.value = const UploadStatusSnapshot();
          liveConditions.value = (lux: null, hpa: null, rms: null);
          // Stop tracking session (service was killed)
          await _sessionManager.stopSession(reason: 'service_stopped');
          debugPrint('Foreground service reported stopped');
          break;
      }
    });
  }

  bool _isChangingState = false;

  /// Prevents overlapping start/stop/pause/resume calls.
  Future<bool> _guardStateChange(Future<bool> Function() action) async {
    if (_isChangingState) return false;
    _isChangingState = true;
    try {
      return await action();
    } finally {
      _isChangingState = false;
    }
  }

  /// Start the foreground service
  Future<bool> start() => _guardStateChange(() async {
    try {
      final result = await _fgChannel.invokeMethod<bool>('startForegroundService');
      if (result == true) {
        _isRunningNotifier.value = true;
        _isPausedNotifier.value = false;
        unawaited(AppPreferences.instance.setForegroundServiceEnabled(true));
        unawaited(AppPreferences.instance.setTrackingPaused(false));
        await _sessionManager.startSession();
        debugPrint('Foreground location service started');
      }
      return result ?? false;
    } catch (e) {
      debugPrint('Error starting foreground service: $e');
      return false;
    }
  });

  Future<void> requestLocationPermission() async {
    try {
      await _fgChannel.invokeMethod('requestLocationPermission');
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
    }
  }

  /// Flush sensor FIFO buffers to get immediate data delivery
  /// Useful when user opens the app to show fresh sensor readings
  Future<bool> flushSensorBuffers() async {
    try {
      final result = await _fgChannel.invokeMethod<bool>('flushSensorBuffers');
      debugPrint('Sensor FIFO buffers flushed: ${result == true ? 'success' : 'failed'}');
      return result ?? false;
    } catch (e) {
      debugPrint('Error flushing sensor buffers: $e');
      return false;
    }
  }

  /// Stop the foreground service
  Future<bool> stop() => _guardStateChange(() async {
    try {
      final result = await _fgChannel.invokeMethod<bool>('stopForegroundService');
      if (result == true) {
        _isRunningNotifier.value = false;
        _isPausedNotifier.value = false;
        _lastLocation = null;
        uploadStatus.value = const UploadStatusSnapshot();
        unawaited(AppPreferences.instance.setForegroundServiceEnabled(false));
        unawaited(AppPreferences.instance.setTrackingPaused(false));
        await _sessionManager.stopSession(reason: 'user_stopped');
        debugPrint('Foreground location service stopped');
      }
      return result ?? false;
    } catch (e) {
      debugPrint('Error stopping foreground service: $e');
      return false;
    }
  });

  /// Check if the foreground service is currently running
  Future<bool> isServiceRunning() async {
    // A state change is in progress (start/stop/pause/resume): treat as running and
    // skip the isTrackingPaused query — racing it would overwrite the in-flight change.
    if (_isChangingState) {
      return true;
    }

    try {
      final result = await _fgChannel.invokeMethod<bool>('isForegroundServiceRunning');
      _isRunningNotifier.value = result ?? false;
      // Only query paused state if the service is actually running — avoids a stale
      // false overwriting an in-flight pauseTracking/resumeTracking result.
      if (result == true) {
        final paused = await _fgChannel.invokeMethod<bool>('isTrackingPaused');
        _isPausedNotifier.value = paused ?? false;
      } else {
        _isPausedNotifier.value = false;
      }
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking service status: $e');
      return false;
    }
  }

  /// Android 13+: true when previous app process exit was user-requested
  /// (e.g. Task Manager stop). Returns false on unsupported versions/errors.
  Future<bool> wasAppUserStopped() async {
    try {
      final result = await _fgChannel.invokeMethod<bool>('wasAppUserStopped');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking app user-stop state: $e');
      return false;
    }
  }

  Future<void> _bootstrapUploadStatus() async {
    await AppPreferences.instance.ensureInitialized();
    uploadStatus.value = uploadStatus.value.copyWith(
      lastUpload: AppPreferences.instance.lastUploadAt,
    );
    // Note: isRunning and isPaused are NOT preloaded from prefs here.
    // TrackingSessionManager.initialize() already resets prefs for paused sessions.
    // HomeScreen._checkServiceStatus() calls isServiceRunning() to get authoritative state.
  }

  Future<bool> pauseTracking() => _guardStateChange(() async {
    try {
      final result = await _fgChannel.invokeMethod<bool>('pauseForegroundService');
      if (result == true) {
        _isPausedNotifier.value = true;
        unawaited(AppPreferences.instance.setTrackingPaused(true));
      }
      return result ?? false;
    } catch (e) {
      debugPrint('Error pausing foreground service: $e');
      return false;
    }
  });

  Future<bool> resumeTracking() => _guardStateChange(() async {
    try {
      final result = await _fgChannel.invokeMethod<bool>('resumeForegroundService');
      if (result == true) {
        _isPausedNotifier.value = false;
        unawaited(AppPreferences.instance.setTrackingPaused(false));
      }
      return result ?? false;
    } catch (e) {
      debugPrint('Error resuming foreground service: $e');
      return false;
    }
  });

  void _handleNativeUploadStatus(Map<dynamic, dynamic> data) {
    final status = data['status'] as String? ?? 'unknown';
    final timestampMs = (data['timestamp'] as num?)?.toInt();

    switch (status) {
      case 'started':
        uploadStatus.value = uploadStatus.value.copyWith(
          isUploading: true,
          lastError: null,
          lastErrorTime: null,
        );
        break;
      case 'success':
        uploadStatus.value = uploadStatus.value.copyWith(
          isUploading: false,
        );
        final timestamp = timestampMs != null
            ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
            : DateTime.now();

        if (timestampMs != null) {
          uploadStatus.value = uploadStatus.value.copyWith(
            lastUpload: timestamp,
          );
          // Note: Native code already saved timestamp to SharedPreferences
        }
        // Keep shared prefs aligned with the latest upload timestamp.
        unawaited(AppPreferences.instance.setLastUploadAt(timestamp));
        // Clear any previous errors on successful upload.
        uploadStatus.value = uploadStatus.value.copyWith(
          lastError: null,
          lastErrorTime: null,
        );

        // Emit event for reactive UI updates (replaces _statsRefreshTrigger)
        final samplesCount = (data['batchSize'] as num?)?.toInt() ?? 0;
        AppEventBus.instance.emit(UploadSuccessEvent(
          samplesCount: samplesCount,
          timestamp: timestamp,
          geohash: null, // Can be added later if needed
        ));

        // Note: Native code already saved contribution to SQLite database
        // Record upload in tracking session (non-blocking)
        _sessionManager.recordUploadCompleted().catchError((e) {
          debugPrint('Session upload record failed (non-critical): $e');
        });
        break;
      case 'failure':
        uploadStatus.value = uploadStatus.value.copyWith(isUploading: false);
        final error = data['error'] as String? ?? 'Unknown error';
        final failTimestamp = DateTime.now();
        uploadStatus.value = uploadStatus.value.copyWith(
          lastError: error,
          lastErrorTime: failTimestamp,
        );

        // Emit event for UI to react to failures
        AppEventBus.instance.emit(UploadFailedEvent(
          reason: error,
          timestamp: failTimestamp,
        ));

        debugPrint('Native upload failed: $error');
        break;
      default:
        debugPrint('Received unknown native upload status: $status');
    }
  }

  void dispose() {
    _locationController.close();
    _lightController.close();
    _accelerometerController.close();
    _gyroscopeController.close();
    _pressureController.close();
    _isRunningNotifier.dispose();
    uploadStatus.dispose();
    _isPausedNotifier.dispose();
  }
}

class UploadStatusSnapshot {
  final bool isUploading;
  final DateTime? lastUpload;
  final String? lastError;
  final DateTime? lastErrorTime;

  const UploadStatusSnapshot({
    this.isUploading = false,
    this.lastUpload,
    this.lastError,
    this.lastErrorTime,
  });

  UploadStatusSnapshot copyWith({
    bool? isUploading,
    DateTime? lastUpload,
    String? lastError,
    DateTime? lastErrorTime,
  }) {
    return UploadStatusSnapshot(
      isUploading: isUploading ?? this.isUploading,
      lastUpload: lastUpload ?? this.lastUpload,
      lastError: lastError ?? this.lastError,
      lastErrorTime: lastErrorTime ?? this.lastErrorTime,
    );
  }
}
