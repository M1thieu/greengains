import 'package:flutter/services.dart';

/// Sensors present on this phone, read once from the platform, so the UI only
/// lists sensors the user actually has. Community data from sensors this
/// phone lacks is still shown on the map.
class SensorCapabilities {
  SensorCapabilities._();

  static const _channel = MethodChannel('greengains/foreground');
  static Future<Set<String>>? _cache;

  /// Keys: light, pressure, motion, magnetic, temperature, humidity, wifi.
  /// Empty when the platform could not answer (treat as unknown).
  static Future<Set<String>> load() => _cache ??= _fetch();

  static Future<Set<String>> _fetch() async {
    try {
      final map = await _channel.invokeMapMethod<String, bool>('getSensorCapabilities');
      return {for (final e in (map ?? const <String, bool>{}).entries) if (e.value) e.key};
    } on PlatformException {
      return const {};
    } on MissingPluginException {
      return const {};
    }
  }
}
