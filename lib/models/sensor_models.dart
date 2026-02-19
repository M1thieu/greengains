import 'dart:math';

/// Location source type for tiered fallback system
enum LocationSource {
  gps,       // GPS on, accurate (5-20m)
  network,   // WiFi/cell, coarse (50-500m)
  lastKnown, // Cached, stale but battery-free
  none;      // Nothing available

  /// H3 resolution based on location source accuracy
  int get recommendedH3Resolution {
    switch (this) {
      case LocationSource.gps:
        return 10; // ~15m hexagons
      case LocationSource.network:
        return 8;  // ~461m hexagons
      case LocationSource.lastKnown:
        return 7;  // ~1.2km hexagons
      case LocationSource.none:
        return 6;  // ~5km hexagons (fallback)
    }
  }

  /// Parse from provider string
  static LocationSource fromProvider(String? provider) {
    if (provider == null) return LocationSource.none;
    final lower = provider.toLowerCase();
    if (lower.contains('gps') || lower.contains('fused')) {
      return LocationSource.gps;
    } else if (lower.contains('network') || lower.contains('wifi')) {
      return LocationSource.network;
    } else if (lower.contains('passive') || lower.contains('cached')) {
      return LocationSource.lastKnown;
    }
    return LocationSource.none;
  }
}

/// Location data received from the native foreground service
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? speed;
  final double? bearing;
  final int timestamp;
  final String? provider;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.speed,
    this.bearing,
    required this.timestamp,
    this.provider,
  });

  factory LocationData.fromMap(Map<dynamic, dynamic> map) {
    return LocationData(
      latitude:  (map['latitude']  as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy:  (map['accuracy']  as num).toDouble(),
      altitude:  map['altitude']  != null ? (map['altitude']  as num).toDouble() : null,
      speed:     map['speed']     != null ? (map['speed']     as num).toDouble() : null,
      bearing:   map['bearing']   != null ? (map['bearing']   as num).toDouble() : null,
      timestamp: map['timestamp'] as int,
      provider:  map['provider']  as String?,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  LocationSource get source => LocationSource.fromProvider(provider);

  /// H3 resolution based on measured accuracy (more precise than source-based)
  int get recommendedH3Resolution {
    if (accuracy <= 20)  return 10;
    if (accuracy <= 50)  return 9;
    if (accuracy <= 200) return 8;
    if (accuracy <= 500) return 7;
    return 6;
  }

  @override
  String toString() =>
      'LocationData(lat: $latitude, lon: $longitude, accuracy: ${accuracy.toStringAsFixed(1)}m, provider: $provider)';
}

/// Ambient light sensor data (lux)
class LightData {
  final double lux;
  final int timestamp;

  LightData({required this.lux, required this.timestamp});

  factory LightData.fromMap(Map<dynamic, dynamic> map) {
    return LightData(
      lux:       (map['lux'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  @override
  String toString() => 'LightData(${lux.toStringAsFixed(0)} lux)';
}

/// Accelerometer data (m/s²)
class AccelerometerData {
  final double x;
  final double y;
  final double z;
  final int timestamp;

  AccelerometerData({required this.x, required this.y, required this.z, required this.timestamp});

  factory AccelerometerData.fromMap(Map<dynamic, dynamic> map) {
    return AccelerometerData(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  double get magnitude => sqrt(x * x + y * y + z * z);

  @override
  String toString() => 'AccelerometerData(${magnitude.toStringAsFixed(1)} m/s²)';
}

/// Gyroscope data (rad/s)
class GyroscopeData {
  final double x;
  final double y;
  final double z;
  final int timestamp;

  GyroscopeData({required this.x, required this.y, required this.z, required this.timestamp});

  factory GyroscopeData.fromMap(Map<dynamic, dynamic> map) {
    return GyroscopeData(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  double get magnitude => sqrt(x * x + y * y + z * z);

  @override
  String toString() => 'GyroscopeData(${magnitude.toStringAsFixed(2)} rad/s)';
}

/// Magnetometer data (µT — microtesla)
class MagneticFieldData {
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final int timestamp;

  MagneticFieldData({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.timestamp,
  });

  factory MagneticFieldData.fromMap(Map<dynamic, dynamic> map) {
    return MagneticFieldData(
      x:         (map['x']         as num).toDouble(),
      y:         (map['y']         as num).toDouble(),
      z:         (map['z']         as num).toDouble(),
      magnitude: (map['magnitude'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  @override
  String toString() => 'MagneticFieldData(${magnitude.toStringAsFixed(1)} µT)';
}

/// Barometric pressure data (hPa)
class PressureData {
  final double hPa;
  final int timestamp;

  PressureData({required this.hPa, required this.timestamp});

  factory PressureData.fromMap(Map<dynamic, dynamic> map) {
    return PressureData(
      hPa:       (map['hPa'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  @override
  String toString() => 'PressureData(${hPa.toStringAsFixed(2)} hPa)';
}
