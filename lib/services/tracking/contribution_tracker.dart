import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

/// Tracks user's tile contributions locally for gamification
class ContributionTracker {
  static const String _keyTilesData = 'tiles_data_v1';
  static const String _keyLastReset = 'last_reset_date';

  static ContributionTracker? _instance;
  static ContributionTracker get instance {
    _instance ??= ContributionTracker._();
    return _instance!;
  }

  ContributionTracker._();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // Today's tiles
  final Set<String> _tilesToday = {};
  final Set<String> _dayTiles = {};
  final Set<String> _nightTiles = {};

  // Lifetime tiles
  int _totalTilesLifetime = 0;

  Future<void> initialize() async {
    if (_initialized) return; // Already initialized

    try {
      _prefs = await SharedPreferences.getInstance();
      await _checkDailyReset();
      _loadTodayData();
      _initialized = true;
    } catch (e) {
      // If initialization fails, just continue with empty data
      _initialized = true;
    }
  }

  /// Check if we need to reset today's counters (new day)
  Future<void> _checkDailyReset() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastResetStr = _prefs?.getString(_keyLastReset);

    if (lastResetStr != null) {
      final lastReset = DateTime.parse(lastResetStr);
      final lastResetDay = DateTime(lastReset.year, lastReset.month, lastReset.day);

      if (today.isAfter(lastResetDay)) {
        // New day! Reset today's tiles
        await _resetDailyTiles();
      }
    } else {
      // First time - save today's date
      await _prefs?.setString(_keyLastReset, today.toIso8601String());
    }
  }

  void _loadTodayData() {
    final dataStr = _prefs?.getString(_keyTilesData);
    if (dataStr != null) {
      try {
        final data = jsonDecode(dataStr) as Map<String, dynamic>;
        _tilesToday.addAll((data['today'] as List<dynamic>).cast<String>());
        _dayTiles.addAll((data['day'] as List<dynamic>).cast<String>());
        _nightTiles.addAll((data['night'] as List<dynamic>).cast<String>());
        _totalTilesLifetime = data['lifetime'] as int? ?? 0;
      } catch (e) {
        // Corrupted data - start fresh
        _resetDailyTiles();
      }
    }
  }

  Future<void> _resetDailyTiles() async {
    _tilesToday.clear();
    _dayTiles.clear();
    _nightTiles.clear();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await _prefs?.setString(_keyLastReset, today.toIso8601String());
    await _saveTilesData();
  }

  Future<void> _saveTilesData() async {
    final data = {
      'today': _tilesToday.toList(),
      'day': _dayTiles.toList(),
      'night': _nightTiles.toList(),
      'lifetime': _totalTilesLifetime,
    };
    await _prefs?.setString(_keyTilesData, jsonEncode(data));
  }

  /// Record a new tile (geohash) with timestamp
  Future<void> recordTile(String geohash, DateTime timestamp) async {
    await _checkDailyReset();

    if (!_tilesToday.contains(geohash)) {
      _tilesToday.add(geohash);
      _totalTilesLifetime++;

      // Determine if day or night tile
      final hour = timestamp.hour;
      if (hour >= kDayStartHour && hour < kDayEndHour) {
        _dayTiles.add(geohash);
      } else {
        _nightTiles.add(geohash);
      }

      await _saveTilesData();
    }
  }

  /// Get today's tile count
  int get tilesToday => _tilesToday.length;

  /// Get day tiles count
  int get dayTiles => _dayTiles.length;

  /// Get night tiles count
  int get nightTiles => _nightTiles.length;

  /// Get lifetime tiles count
  int get lifetimeTiles => _totalTilesLifetime;

  /// Reset everything (for testing)
  Future<void> resetAll() async {
    _tilesToday.clear();
    _dayTiles.clear();
    _nightTiles.clear();
    _totalTilesLifetime = 0;
    await _prefs?.remove(_keyTilesData);
    await _prefs?.remove(_keyLastReset);
  }
}
