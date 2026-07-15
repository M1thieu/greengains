import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PreferenceKeys {
  const PreferenceKeys._();
  static const onboardingComplete = 'onboarding_complete';
  static const themeMode = 'theme_mode';
  static const languageCode = 'language_code'; // 'en', 'fr', or null for system default
  static const useMobileUploads = 'use_mobile_data_uploads';
  static const deviceId = 'flutter.device_id';
  static const foregroundServiceEnabled = 'flutter.foreground_service_enabled';
  static const trackingPaused = 'flutter.tracking_paused';
  static const shareLocation = 'flutter.share_location';
  static const lastUploadAt = 'flutter.last_upload_at';
  static const dismissedTips = 'dismissed_tips';
  static const batteryOptimizationPromptDismissed = 'battery_optimization_prompt_dismissed';
  static const batteryOptimizationPromptLastShown = 'battery_optimization_prompt_last_shown';
  static const postOnboardingAuthPrompted = 'post_onboarding_auth_prompted';
  static const homeSheetSize = 'home_sheet_size';
  static const referralCode = 'referral_code';
  static const consentDate = 'consent_date';

  // Identity credentials shared with the native Kotlin uploader.
  // The shared_preferences plugin prepends 'flutter.' on write, so keys that
  // start with 'flutter.' land on disk as 'flutter.flutter.*' — matching
  // AppPrefs.DEVICE_SECRET / FIREBASE_AUTH_TOKEN in Kotlin.
  static const deviceSecret = 'flutter.device_secret';
  static const firebaseAuthToken = 'flutter.firebase_auth_token';

  // Legacy raw keys (single prefix) — kept only for one-time migration
  static const _legacyDeviceSecret = 'device_secret';
  static const _legacyFirebaseAuthToken = 'firebase_auth_token';

  // Last known sensor values for instant display on app restart
  static const lastLightLux = 'last_light_lux';
  static const lastLightTimestamp = 'last_light_timestamp';
  static const lastPressureHPa = 'last_pressure_hpa';
  static const lastPressureTimestamp = 'last_pressure_timestamp';
  static const lastMagneticMagnitude = 'last_magnetic_magnitude';
  static const lastMagneticTimestamp = 'last_magnetic_timestamp';

  // One-time UX flags — stored in AppPreferences for consistency
  static const trackingEverStarted = 'tracking_ever_started';
  static const lastKnownZoneCount = 'last_known_zone_count';
  static const lastMilestoneCelebrated = 'last_milestone_celebrated';
  static const totalUploadCount = 'total_upload_count';
  static const reviewRequested = 'review_requested';
  static const firstUploadCelebrated = 'first_upload_celebrated';
  static const firstUploadPending = 'first_upload_pending';
  static const lastUploadMilestoneCelebrated = 'last_upload_milestone_celebrated';

  static const currentStreak = 'current_streak';
  static const lastKnownStreak = 'last_known_streak';
  static const weeklyGoalCelebratedWeek = 'weekly_goal_celebrated_week';
  static const referralShared = 'referral_shared';
  static const lastSessionZonesGained = 'last_session_zones_gained';
  static const lastSessionEndAt = 'last_session_end_at';
  static const bestSessionZonesGained = 'best_session_zones_gained';
  static const dismissedReturnDeltaZones = 'dismissed_return_delta_zones';

  /// Primary neighborhood name computed from the user's most-mapped tile centroid.
  static const territoryLabel = 'territory_label';

  /// Last successful personal tile API response, JSON-encoded.
  /// Loaded instantly on app open before network response arrives.
  static const cachedPersonalTiles = 'cached_personal_tiles';

  /// Last successful global tile API response, JSON-encoded.
  static const cachedGlobalTiles = 'cached_global_tiles';

  static const _legacyDeviceId = 'device_id';
  static const _legacyForegroundServiceEnabled = 'foreground_service_enabled';
  static const _legacyTrackingPaused = 'tracking_paused';
  static const _legacyShareLocation = 'share_location';
  static const _legacyLastUploadAt = 'last_upload_at';
}

class AppPreferences {
  AppPreferences._();
  static final AppPreferences instance = AppPreferences._();

  SharedPreferences? _prefs;
  String? _deviceIdCache;
  static const _uuid = Uuid();

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _migrateLegacyKeys();
  }

  Future<void> ensureInitialized() => init();

  SharedPreferences get _sp {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('AppPreferences not initialized. Call init() first.');
    }
    return prefs;
  }

  Future<void> _migrateLegacyKeys() async {
    final prefs = _prefs;
    if (prefs == null) return;

    await _migrateStringKey(
      prefs,
      PreferenceKeys.deviceId,
      PreferenceKeys._legacyDeviceId,
    );
    await _migrateBoolKey(
      prefs,
      PreferenceKeys.foregroundServiceEnabled,
      PreferenceKeys._legacyForegroundServiceEnabled,
    );
    await _migrateBoolKey(
      prefs,
      PreferenceKeys.trackingPaused,
      PreferenceKeys._legacyTrackingPaused,
    );
    await _migrateBoolKey(
      prefs,
      PreferenceKeys.shareLocation,
      PreferenceKeys._legacyShareLocation,
    );
    await _migrateStringKey(
      prefs,
      PreferenceKeys.lastUploadAt,
      PreferenceKeys._legacyLastUploadAt,
    );
    await _migrateStringKey(
      prefs,
      PreferenceKeys.deviceSecret,
      PreferenceKeys._legacyDeviceSecret,
    );
    await _migrateStringKey(
      prefs,
      PreferenceKeys.firebaseAuthToken,
      PreferenceKeys._legacyFirebaseAuthToken,
    );

    // Clean up stale single-prefixed Android keys.
    // Flutter's shared_preferences plugin adds a "flutter." prefix, so
    // Flutter key 'tracking_paused' → Android: 'flutter.tracking_paused'.
    // Native Kotlin now reads the double-prefixed keys (flutter.flutter.*).
    // Removing legacy Flutter keys prevents Kotlin from reading stale values
    // if AppPrefs.kt is ever reverted.
    await prefs.remove(PreferenceKeys._legacyTrackingPaused);
    await prefs.remove(PreferenceKeys._legacyForegroundServiceEnabled);
    await prefs.remove(PreferenceKeys._legacyShareLocation);
    await prefs.remove(PreferenceKeys._legacyLastUploadAt);
    await prefs.remove(PreferenceKeys._legacyDeviceId);
  }

  Future<void> _migrateBoolKey(
    SharedPreferences prefs,
    String newKey,
    String legacyKey,
  ) async {
    if (prefs.containsKey(newKey)) return;
    final legacyValue = prefs.getBool(legacyKey);
    if (legacyValue == null) return;
    await prefs.setBool(newKey, legacyValue);
  }

  Future<void> _migrateStringKey(
    SharedPreferences prefs,
    String newKey,
    String legacyKey,
  ) async {
    if (prefs.containsKey(newKey)) return;
    final legacyValue = prefs.getString(legacyKey);
    if (legacyValue == null || legacyValue.isEmpty) return;
    await prefs.setString(newKey, legacyValue);
  }

  bool get onboardingComplete =>
      _sp.getBool(PreferenceKeys.onboardingComplete) ?? false;

  Future<void> setOnboardingComplete(bool value) async {
    await _sp.setBool(PreferenceKeys.onboardingComplete, value);
  }

  String? get themeModeRaw => _sp.getString(PreferenceKeys.themeMode);

  Future<void> setThemeModeRaw(String value) async {
    await _sp.setString(PreferenceKeys.themeMode, value);
  }

  /// Get selected language code ('en', 'fr', or null for system default)
  String? get languageCode => _sp.getString(PreferenceKeys.languageCode);

  Future<void> setLanguageCode(String? value) async {
    if (value == null) {
      await _sp.remove(PreferenceKeys.languageCode);
    } else {
      await _sp.setString(PreferenceKeys.languageCode, value);
    }
  }

  bool get useMobileUploads =>
      _sp.getBool(PreferenceKeys.useMobileUploads) ?? true;

  Future<void> setUseMobileUploads(bool value) async {
    await _sp.setBool(PreferenceKeys.useMobileUploads, value);
  }

  bool get foregroundServiceEnabled =>
      _sp.getBool(PreferenceKeys.foregroundServiceEnabled) ??
      _sp.getBool(PreferenceKeys._legacyForegroundServiceEnabled) ??
      false;

  Future<void> setForegroundServiceEnabled(bool value) async {
    await _sp.setBool(PreferenceKeys.foregroundServiceEnabled, value);
  }

  bool get trackingPaused =>
      _sp.getBool(PreferenceKeys.trackingPaused) ??
      _sp.getBool(PreferenceKeys._legacyTrackingPaused) ??
      false;

  Future<void> setTrackingPaused(bool value) async {
    await _sp.setBool(PreferenceKeys.trackingPaused, value);
  }

  /// Location sharing preference — defaults to TRUE.
  /// The app's core value proposition is environmental mapping; location is essential.
  /// Users have already granted system location permission during onboarding.
  bool get shareLocation =>
      _sp.getBool(PreferenceKeys.shareLocation) ??
      _sp.getBool(PreferenceKeys._legacyShareLocation) ??
      true;

  Future<void> setShareLocation(bool value) async {
    await _sp.setBool(PreferenceKeys.shareLocation, value);
  }

  bool get batteryOptimizationPromptDismissed =>
      _sp.getBool(PreferenceKeys.batteryOptimizationPromptDismissed) ?? false;

  Future<void> setBatteryOptimizationPromptDismissed(bool value) async {
    await _sp.setBool(PreferenceKeys.batteryOptimizationPromptDismissed, value);
  }

  DateTime? get batteryOptimizationPromptLastShown {
    final raw = _sp.getString(PreferenceKeys.batteryOptimizationPromptLastShown);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<void> setBatteryOptimizationPromptLastShown(DateTime timestamp) async {
    await _sp.setString(
      PreferenceKeys.batteryOptimizationPromptLastShown,
      timestamp.toIso8601String(),
    );
  }

  bool get postOnboardingAuthPrompted =>
      _sp.getBool(PreferenceKeys.postOnboardingAuthPrompted) ?? false;

  Future<void> setPostOnboardingAuthPrompted(bool value) async {
    await _sp.setBool(PreferenceKeys.postOnboardingAuthPrompted, value);
  }

  double? get homeSheetSize => _sp.getDouble(PreferenceKeys.homeSheetSize);

  Future<void> setHomeSheetSize(double value) async {
    await _sp.setDouble(PreferenceKeys.homeSheetSize, value);
  }

  /// Cached referral code — allocated once by the server, never changes.
  String? get referralCode => _sp.getString(PreferenceKeys.referralCode);

  Future<void> setReferralCode(String value) async {
    await _sp.setString(PreferenceKeys.referralCode, value);
  }

  /// Clears the cached referral code — called on sign-out so the next
  /// signed-in account starts fresh (code is re-fetched after login).
  Future<void> clearReferralCode() async {
    await _sp.remove(PreferenceKeys.referralCode);
  }

  /// Date the user explicitly consented to data collection (ISO string).
  DateTime? get consentDate {
    final raw = _sp.getString(PreferenceKeys.consentDate);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<void> setConsentDate(DateTime dt) async {
    await _sp.setString(PreferenceKeys.consentDate, dt.toIso8601String());
  }

  DateTime? get lastUploadAt {
    final raw = _sp.getString(PreferenceKeys.lastUploadAt) ??
        _sp.getString(PreferenceKeys._legacyLastUploadAt);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }

  Future<void> setLastUploadAt(DateTime timestamp) async {
    await _sp.setString(
      PreferenceKeys.lastUploadAt,
      timestamp.toUtc().toIso8601String(),
    );
  }

  Future<String> getOrCreateDeviceId() async {
    await ensureInitialized();
    if (_deviceIdCache != null) {
      return _deviceIdCache!;
    }
    final existing =
        _sp.getString(PreferenceKeys.deviceId) ??
        _sp.getString(PreferenceKeys._legacyDeviceId);
    if (existing != null && existing.isNotEmpty) {
      if (_sp.getString(PreferenceKeys.deviceId) == null) {
        await _sp.setString(PreferenceKeys.deviceId, existing);
      }
      _deviceIdCache = existing;
      return existing;
    }
    final generated = _uuid.v4();
    _deviceIdCache = generated; // set before await so concurrent calls short-circuit
    await _sp.setString(PreferenceKeys.deviceId, generated);
    return generated;
  }

  ThemeMode decodeThemeMode(String? raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  String encodeThemeMode(ThemeMode mode) {
    return mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.system
            ? 'system'
            : 'light';
  }

  /// Check if a contextual tip has been dismissed
  bool isTipDismissed(String tipId) {
    final dismissed = _sp.getStringList(PreferenceKeys.dismissedTips) ?? [];
    return dismissed.contains(tipId);
  }

  /// Dismiss a contextual tip permanently
  Future<void> dismissTip(String tipId) async {
    final dismissed = _sp.getStringList(PreferenceKeys.dismissedTips) ?? [];
    if (!dismissed.contains(tipId)) {
      dismissed.add(tipId);
      await _sp.setStringList(PreferenceKeys.dismissedTips, dismissed);
    }
  }

  // Sensor value persistence for instant display on app restart

  /// Save last known light sensor reading
  Future<void> saveLastLight(double lux, int timestampMs) async {
    await _sp.setDouble(PreferenceKeys.lastLightLux, lux);
    await _sp.setInt(PreferenceKeys.lastLightTimestamp, timestampMs);
  }

  /// Get last known light sensor reading
  Map<String, dynamic>? getLastLight() {
    final lux = _sp.getDouble(PreferenceKeys.lastLightLux);
    final timestamp = _sp.getInt(PreferenceKeys.lastLightTimestamp);
    if (lux == null || timestamp == null) return null;
    return {'lux': lux, 'timestamp': timestamp};
  }

  /// Save last known pressure sensor reading
  Future<void> saveLastPressure(double hPa, int timestampMs) async {
    await _sp.setDouble(PreferenceKeys.lastPressureHPa, hPa);
    await _sp.setInt(PreferenceKeys.lastPressureTimestamp, timestampMs);
  }

  /// Get last known pressure sensor reading
  Map<String, dynamic>? getLastPressure() {
    final hPa = _sp.getDouble(PreferenceKeys.lastPressureHPa);
    final timestamp = _sp.getInt(PreferenceKeys.lastPressureTimestamp);
    if (hPa == null || timestamp == null) return null;
    return {'hPa': hPa, 'timestamp': timestamp};
  }

  double? get lastLux => _sp.getDouble(PreferenceKeys.lastLightLux);
  double? get lastHpa => _sp.getDouble(PreferenceKeys.lastPressureHPa);

  /// Save last known magnetometer reading (magnitude only — orientation-independent)
  Future<void> saveLastMagnetic(double magnitude, int timestampMs) async {
    await _sp.setDouble(PreferenceKeys.lastMagneticMagnitude, magnitude);
    await _sp.setInt(PreferenceKeys.lastMagneticTimestamp, timestampMs);
  }

  /// Get last known magnetometer reading
  Map<String, dynamic>? getLastMagnetic() {
    final magnitude = _sp.getDouble(PreferenceKeys.lastMagneticMagnitude);
    final timestamp = _sp.getInt(PreferenceKeys.lastMagneticTimestamp);
    if (magnitude == null || timestamp == null) return null;
    return {'magnitude': magnitude, 'timestamp': timestamp};
  }

  // ── Identity credentials for native uploader ─────────────────────────────

  /// Long-lived per-device secret, shared with the native Kotlin uploader.
  /// Read on Android as AppPrefs.DEVICE_SECRET = "flutter.flutter.device_secret".
  String? get deviceSecret =>
      _sp.getString(PreferenceKeys.deviceSecret) ??
      _sp.getString(PreferenceKeys._legacyDeviceSecret);

  Future<void> setDeviceSecret(String value) async {
    await _sp.setString(PreferenceKeys.deviceSecret, value);
  }

  /// Firebase ID token, refreshed by Flutter and read by the native uploader.
  /// Read on Android as AppPrefs.FIREBASE_AUTH_TOKEN = "flutter.flutter.firebase_auth_token".
  String? get firebaseAuthToken =>
      _sp.getString(PreferenceKeys.firebaseAuthToken) ??
      _sp.getString(PreferenceKeys._legacyFirebaseAuthToken);

  Future<void> setFirebaseAuthToken(String value) async {
    await _sp.setString(PreferenceKeys.firebaseAuthToken, value);
  }

  // ── Streak (shared with native StreakAlertWorker) ─────────────────────────────

  /// Written after each profile fetch so the native WorkManager worker can read it
  /// without a network call. Key must match AppPrefs.CURRENT_STREAK in Kotlin
  /// (flutter.flutter.current_streak — double-prefixed because AppPreferences uses the plugin).
  int get currentStreak => _sp.getInt(PreferenceKeys.currentStreak) ?? 0;

  Future<void> setCurrentStreak(int streak) async {
    await _sp.setInt(PreferenceKeys.currentStreak, streak);
  }

  int get lastKnownStreak => _sp.getInt(PreferenceKeys.lastKnownStreak) ?? 0;

  Future<void> setLastKnownStreak(int streak) async {
    await _sp.setInt(PreferenceKeys.lastKnownStreak, streak);
  }

  /// ISO week string e.g. "2026-W20" — used to dedup weekly goal celebration.
  String get weeklyGoalCelebratedWeek =>
      _sp.getString(PreferenceKeys.weeklyGoalCelebratedWeek) ?? '';

  Future<void> setWeeklyGoalCelebratedWeek(String week) async {
    await _sp.setString(PreferenceKeys.weeklyGoalCelebratedWeek, week);
  }

  bool get referralShared => _sp.getBool(PreferenceKeys.referralShared) ?? false;

  Future<void> setReferralShared() async {
    await _sp.setBool(PreferenceKeys.referralShared, true);
  }

  // ── One-time UX flags ────────────────────────────────────────────────────────

  bool get trackingEverStarted =>
      _sp.getBool(PreferenceKeys.trackingEverStarted) ?? false;

  Future<void> setTrackingEverStarted() async {
    await _sp.setBool(PreferenceKeys.trackingEverStarted, true);
  }

  int get lastMilestoneCelebrated =>
      _sp.getInt(PreferenceKeys.lastMilestoneCelebrated) ?? 0;

  Future<void> setLastMilestoneCelebrated(int milestone) async {
    await _sp.setInt(PreferenceKeys.lastMilestoneCelebrated, milestone);
  }

  int get totalUploadCount =>
      _sp.getInt(PreferenceKeys.totalUploadCount) ?? 0;

  Future<void> setTotalUploadCount(int count) async {
    await _sp.setInt(PreferenceKeys.totalUploadCount, count);
  }

  /// Zone count stored at last app open — used to compute delta for re-engagement banner.
  int get lastKnownZoneCount =>
      _sp.getInt(PreferenceKeys.lastKnownZoneCount) ?? 0;

  Future<void> setLastKnownZoneCount(int count) async {
    await _sp.setInt(PreferenceKeys.lastKnownZoneCount, count);
  }

  // ── Last session data — for return hint on home screen ──────────────────────

  /// Zones gained in the last completed tracking session (0 if none yet).
  int get lastSessionZonesGained =>
      _sp.getInt(PreferenceKeys.lastSessionZonesGained) ?? 0;

  /// When the last tracking session ended (null = never).
  DateTime? get lastSessionEndAt {
    final ms = _sp.getInt(PreferenceKeys.lastSessionEndAt);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  int get bestSessionZonesGained =>
      _sp.getInt(PreferenceKeys.bestSessionZonesGained) ?? 0;

  Future<void> saveLastSession({required int zonesGained}) async {
    await _sp.setInt(PreferenceKeys.lastSessionZonesGained, zonesGained);
    await _sp.setInt(PreferenceKeys.lastSessionEndAt,
        DateTime.now().millisecondsSinceEpoch);
    if (zonesGained > bestSessionZonesGained) {
      await _sp.setInt(PreferenceKeys.bestSessionZonesGained, zonesGained);
    }
  }

  int get dismissedReturnDeltaZones =>
      _sp.getInt(PreferenceKeys.dismissedReturnDeltaZones) ?? -1;
  Future<void> setDismissedReturnDeltaZones(int zones) =>
      _sp.setInt(PreferenceKeys.dismissedReturnDeltaZones, zones);

  bool get firstUploadCelebrated =>
      _sp.getBool(PreferenceKeys.firstUploadCelebrated) ?? false;

  Future<void> setFirstUploadCelebrated() async {
    await _sp.setBool(PreferenceKeys.firstUploadCelebrated, true);
  }

  bool get firstUploadPending =>
      _sp.getBool(PreferenceKeys.firstUploadPending) ?? false;

  Future<void> setFirstUploadPending(bool value) async {
    await _sp.setBool(PreferenceKeys.firstUploadPending, value);
  }

  int get lastUploadMilestoneCelebrated =>
      _sp.getInt(PreferenceKeys.lastUploadMilestoneCelebrated) ?? 0;

  Future<void> setLastUploadMilestoneCelebrated(int count) async {
    await _sp.setInt(PreferenceKeys.lastUploadMilestoneCelebrated, count);
  }

  bool get reviewRequested =>
      _sp.getBool(PreferenceKeys.reviewRequested) ?? false;

  Future<void> setReviewRequested() async {
    await _sp.setBool(PreferenceKeys.reviewRequested, true);
  }

  /// Primary neighborhood name — computed once from the user's most-mapped tile centroid.
  /// Null until first successful geocode. Shown in home hero + referral card.
  String? get territoryLabel => _sp.getString(PreferenceKeys.territoryLabel);

  Future<void> setTerritoryLabel(String name) async {
    await _sp.setString(PreferenceKeys.territoryLabel, name);
  }

  /// Cached personal tile API response (raw JSON string). Null on first install.
  String? get cachedPersonalTiles => _sp.getString(PreferenceKeys.cachedPersonalTiles);

  Future<void> setCachedPersonalTiles(String json) async {
    await _sp.setString(PreferenceKeys.cachedPersonalTiles, json);
  }

  /// Cached global tile API response (raw JSON string). Null on first install.
  String? get cachedGlobalTiles => _sp.getString(PreferenceKeys.cachedGlobalTiles);

  Future<void> setCachedGlobalTiles(String json) async {
    await _sp.setString(PreferenceKeys.cachedGlobalTiles, json);
  }

  // ── Cached weekly stats (instant stats display on cold start) ────────────────

  List<int>? get cachedWeeklyData {
    final raw = _sp.getString('cached_weekly_data');
    if (raw == null) return null;
    try {
      return raw.split(',').map(int.parse).toList();
    } catch (_) { return null; }
  }

  Future<void> setCachedWeeklyData(List<int> data) async {
    await _sp.setString('cached_weekly_data', data.join(','));
  }

  // ── Last known GPS position (for instant map centering on cold start) ───────

  /// Save the last known user position so the map can center immediately on next open.
  Future<void> saveLastPosition(double lat, double lng) async {
    await Future.wait([
      _sp.setDouble('last_known_lat', lat),
      _sp.setDouble('last_known_lng', lng),
    ]);
  }

  /// Returns the last saved position, or null if never set.
  ({double lat, double lng})? get lastKnownPosition {
    final lat = _sp.getDouble('last_known_lat');
    final lng = _sp.getDouble('last_known_lng');
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }
}
