import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'dart:developer' as developer;
import '../../core/constants.dart';

const _logTag = 'LocationService';

/// Manages location collection for smart city environmental data
///
/// Uses the best accuracy available while remaining battery-friendly:
/// - Precise (GPS) when user granted high accuracy.
/// - Coarse (network / Wi-Fi) fallback when only reduced accuracy is allowed.
///
/// Battery impact: ~5-8% per day (comparable to competitors)
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Check if location services are enabled on device
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      developer.log('Error checking location service: $e',
          name: _logTag, error: e);
      return false;
    }
  }

  /// Check current location permission status
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      developer.log('Error checking permission: $e', name: _logTag, error: e);
      return LocationPermission.denied;
    }
  }

  /// Request location permission (FINE + COARSE)
  ///
  /// Shows Android permission dialog
  /// Requests FINE for GPS precision, falls back to COARSE if denied
  Future<bool> requestLocation() async {
    developer.log('Requesting location permission (coarse/fine)',
        name: _logTag);

    try {
      LocationPermission permission = await checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        developer.log('Permission request result: $permission', name: _logTag);
      }

      if (permission == LocationPermission.deniedForever) {
        developer.log('Location permission denied forever', name: _logTag);
        return false;
      }

      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      developer.log('Location permission granted: $granted', name: _logTag);
      return granted;
    } catch (e) {
      developer.log('Error requesting permission: $e', name: _logTag, error: e);
      return false;
    }
  }

  /// Get precise location using FINE permission (GPS)
  ///
  /// Returns:
  /// - latitude/longitude with ~10-50m accuracy (from GPS satellites)
  /// - altitude in meters above sea level
  /// - accuracy estimate in meters
  /// - null if location unavailable or permission denied
  ///
  /// Battery impact: Medium (~5-8%/day, comparable to Nodle/Silencio)
  Future<Map<String, double>?> getLocation() async {
    try {
      // Check permission first
      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        developer.log('Permission absent, requesting...', name: _logTag);
        permission = await Geolocator.requestPermission();
        developer.log('Permission request result: $permission', name: _logTag);
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        developer.log('Location permission not granted', name: _logTag);
        return null;
      }

      // Check if location services enabled
      final enabled = await isLocationServiceEnabled();
      if (!enabled) {
        developer.log('Location services disabled', name: _logTag);
        return null;
      }

      // Determine available accuracy (Android 12+ can return "reduced" when only coarse granted)
      LocationAccuracyStatus accuracyStatus = LocationAccuracyStatus.precise;
      try {
        accuracyStatus = await Geolocator.getLocationAccuracy();
      } catch (e) {
        developer.log('Failed to get location accuracy status: $e',
            name: _logTag, error: e);
      }

      final bool hasPrecise = accuracyStatus == LocationAccuracyStatus.precise;
      final desiredAccuracy =
          hasPrecise ? LocationAccuracy.high : LocationAccuracy.low;
      final Duration timeLimit =
          hasPrecise ? kPreciseGpsTimeout : kCoarseGpsTimeout;

      Position? position;

      try {
        developer.log(
          'Fetching location with ${hasPrecise ? 'precise' : 'coarse'} accuracy',
          name: _logTag,
        );
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: desiredAccuracy,
          forceAndroidLocationManager: false,
          timeLimit: timeLimit,
        );
      } catch (e) {
        developer.log('Primary location fetch failed: $e',
            name: _logTag, error: e);
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        developer.log('Location unavailable (null position)', name: _logTag);
        return null;
      }

      developer.log(
        'Location fetched (${hasPrecise ? 'precise' : 'coarse'}): ${position.latitude}, ${position.longitude}, '
        '${position.altitude}m (accuracy: ${position.accuracy}m)',
        name: _logTag,
      );

      // Return data (accuracy will indicate precision)
      return _buildLocationData(position);
    } catch (e) {
      developer.log('Error getting location: $e', name: _logTag, error: e);
      return null;
    }
  }

  /// Build location data structure (like Nodle Cash LocationItem)
  ///
  /// Includes:
  /// - Full precision lat/lon (for smart city analysis)
  /// - Altitude in meters (for elevation correlation)
  /// - Accuracy estimate from GPS
  ///
  /// No privacy rounding - smart cities need raw precision
  Map<String, double> _buildLocationData(Position position) {
    return {
      'lat': position.latitude, // Full precision (no rounding)
      'lon': position.longitude, // Full precision (no rounding)
      'altitude': position.altitude, // Meters above sea level
      'accuracy_m': position.accuracy, // GPS accuracy estimate
    };
  }

  /// Open device location settings
  ///
  /// Useful if user denied permission or disabled location services
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      developer.log('Error opening settings: $e', name: _logTag, error: e);
      return false;
    }
  }

  /// Open app settings (for "denied forever" case)
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      developer.log('Error opening app settings: $e', name: _logTag, error: e);
      return false;
    }
  }

  // Phase 2 note: precise GPS collection (LocationAccuracy.high) is tracked in
  // the roadmap and intentionally omitted from v1. Leaving the stub commented
  // keeps the intent documented without tripping analyzer warnings.
  // Future<bool> requestFineLocation() async {
  //   // Request ACCESS_FINE_LOCATION permission
  //   // Show user battery impact warning
  // }
}
