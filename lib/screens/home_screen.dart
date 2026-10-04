import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:h3_flutter/h3_flutter.dart' as h3f;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/extensions/context_extensions.dart';
import '../core/sensor_insights.dart';
import '../l10n/app_localizations.dart';
import '../core/themes.dart';
import '../services/location/foreground_location_service.dart';
import '../services/network/backend_client.dart';
import '../core/events/app_events.dart';
import '../core/utils/composite_subscription.dart';
import '../utils/app_snackbars.dart';
import '../core/app_preferences.dart';
import '../services/widget/home_widget_service.dart';
import '../widgets/coverage_map_widget.dart';
import '../widgets/press_scale_detector.dart';
import '../widgets/sensor_section.dart';
import '../widgets/time_ago_text.dart';
import '../data/repositories/contribution_repository.dart';
import '../widgets/detail_page.dart';

// My Location button: 48×48 standard touch target.
const _kLocationBtnSize = AppTheme.minTouchTarget; // 48


// H3 resolution for live cell highlight (res 9 ≈ 174m edge length - city block scale)
const _kLiveCellResolution = 9;

/// Home screen - full-screen map layout.
///
/// Layer order (bottom → top):
///   0. CoverageMapWidget (edge-to-edge background)
///   1. Status chip (top overlay)
///   2. Map legend (top-right overlay)
///   3. Bottom action bar + MyLocationButton
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onGoToStats, this.onOpenProfile});
  final VoidCallback? onGoToStats;
  final VoidCallback? onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _locationService = ForegroundLocationService.instance;
  final _prefs = AppPreferences.instance;
  final _contributionRepo = ContributionRepository();
  final _h3 = const h3f.H3Factory().load();
  late final _userLocationNotifier = ValueNotifier<LatLng?>(_cachedLocation());
  final _userAccuracyNotifier = ValueNotifier<double?>(null);
  /// Incrementing recenter triggers CoverageMapWidget to move camera to user.
  final _recenterTrigger = ValueNotifier<int>(0);

  bool _batteryRestricted = false;
  bool _permissionLost = false;
  final _subs = <StreamSubscription>[];
  StreamSubscription? _locationStreamSub; // kept separate — reassigned on reconnect
  /// Zone count at the moment tracking started (this foreground session).
  /// 0 = tracking was already running when app opened - no delta shown.
  int _sessionStartZoneCount = 0;
  /// True when map is actively following the user's GPS position.
  final _followModeNotifier = ValueNotifier<bool>(false);
  List<H3Tile> _h3Tiles = [];
  List<H3Tile> _globalTiles = [];
  bool _h3TilesLoading = true;
  /// Aggregated condition summary of all personal tiles - null if normal or no data.
  String? _areaConditionLine;
  DateTime? _lastTilesFetch;
  static const _kTilesCooldown = Duration(minutes: 2);
  /// Retry counters - reset on success, capped at kMaxTileRetries.
  int _h3RetryCount = 0;
  int _globalRetryCount = 0;
  /// Flips true after 8s of loading with no response - shows "Starting up…" hint.
  bool _showSlowLoadHint = false;
  Timer? _slowLoadTimer;
  /// Largest contiguous H3 hex cluster - computed off-thread after tiles load.

  /// Boundary of the H3 cell the user is currently inside - shown as live amber
  /// highlight on the map while tracking is active.
  List<LatLng>? _currentH3Boundary;
  /// Last committed H3 cell index - the one currently rendered on the map.
  BigInt? _currentH3Index;
  /// Cells visited this session - shown as optimistic pending tiles before backend confirms.
  final Set<BigInt> _sessionVisitedCells = {};
  List<List<LatLng>> _pendingCellBoundaries = [];
  /// Candidate cell waiting for stability confirmation.
  BigInt? _pendingH3Index;
  /// How many consecutive GPS readings have landed in [_pendingH3Index].
  int _pendingH3Count = 0;
  /// Minimum consecutive hits before committing a new live cell.
  /// At 10s GPS interval: 3 hits = ~30s - prevents H3 cell drift from low-accuracy
  /// fixes leaking into the live map. Accuracy filter in ForegroundService now rejects
  /// >50m reads, so stable 3-hit confirmation eliminates the last ~5% drift cases.
  static const _kLiveCellStabilityThreshold = 3;
  /// Cached tile count - avoids recomputing on every build frame.
  int get _claimedTileCount => _h3Tiles.where((t) => t.boundary != null).length;
  /// Current streak - pushed to the home-screen widget.
  int _currentStreak = 0;
  /// Whether community tiles are visible on the map.
  bool _showCommunity = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService.isRunning.addListener(_handleServiceRunningChange);
    _checkServiceStatus();
    _setupUploadSuccessListener();
    _checkBatteryOptimization();
    unawaited(_checkPermissionHealth());
    // Load cached tiles off the main thread - map shows last known state before network.
    unawaited(_loadCachedTiles());
    // Prefetch Firebase token before tile requests fire - avoids token latency
    // adding to the first network call. Fire-and-forget; Dio interceptor handles
    // the actual injection. This just warms the Firebase SDK's token cache.
    unawaited(FirebaseAuth.instance.currentUser?.getIdToken());
    _loadH3Tiles();
    _loadGlobalTiles();
    _loadUserLocation();
    _subscribeToLocationUpdates();
    unawaited(_loadStreak());
  }

  Future<void> _loadStreak() async {
    try {
      final stats = await _contributionRepo.getStats();
      if (!mounted) return;
      final next = stats.currentStreak;
      await _prefs.setLastKnownStreak(next);
      setState(() { _currentStreak = next; });
      unawaited(_updateHomeWidget());
    } catch (_) {}
  }

  Future<void> _updateHomeWidget() async {
    await HomeWidgetService.update(
      zoneCount: _claimedTileCount,
      streak: _currentStreak,
      isActive: _locationService.isRunning.value,
    );
  }

  void _handleServiceRunningChange() {
    unawaited(_updateHomeWidget());
    if (_locationService.isRunning.value) {
      _sessionStartZoneCount = _claimedTileCount;
      _sessionVisitedCells.clear();
      _pendingCellBoundaries = [];
      _checkBatteryOptimization();
    } else {
      // Tracking stopped - persist session data for return hint.
      final gained = _claimedTileCount - _sessionStartZoneCount;
      final clampedGained = gained.clamp(0, 9999);
      unawaited(_prefs.saveLastSession(zonesGained: clampedGained));
      _sessionStartZoneCount = 0;
    }
  }

  Future<void> _checkPermissionHealth() async {
    // Only relevant when tracking is supposed to be running.
    if (!_prefs.foregroundServiceEnabled) {
      if (_permissionLost && mounted) setState(() => _permissionLost = false);
      return;
    }
    final permission = await Geolocator.checkPermission();
    final lost = permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever;
    if (mounted && lost != _permissionLost) setState(() => _permissionLost = lost);
  }

  // Bottom action bar controls

  bool _actionBusy = false;
  DateTime? _lastPosSave;

  // ODE 2: 1D Kalman filter for GPS display smoothing.
  // State equations: x_pred = x_prev; P_pred = P_prev + Q
  //   Kalman gain K = P_pred / (P_pred + R)
  //   x = x_pred + K·(z − x_pred);  P = (1−K)·P_pred
  // Q: process noise (how far device can move between GPS ticks, ~10s × walking ~1.5m/s = 15m → ~0.000135°)
  // R: measurement noise = (accuracy_m / 111000)²
  static const double _kKalmanQ = 1.35e-8; // (15m / 111000)²
  double? _kalmanLat, _kalmanLon;
  double _kalmanPLat = 1e-4, _kalmanPLon = 1e-4; // initial covariance (high uncertainty)

  Future<bool> _requestAndCheckPermission() async {
    final current = await Geolocator.checkPermission();
    if (current == LocationPermission.deniedForever) {
      // Android won't ask again: open the app's settings page directly.
      await Geolocator.openAppSettings();
      return false;
    }
    final granted = await Geolocator.requestPermission();
    if (granted == LocationPermission.denied || granted == LocationPermission.deniedForever) {
      if (mounted) AppSnackbars.showInfo(context, context.l10n.permissionLocationMessage);
      return false;
    }
    return true;
  }

  Future<void> _actionStart() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final granted = await _requestAndCheckPermission();
      if (!granted || !mounted) return;
      HapticFeedback.mediumImpact();
      await _prefs.setShareLocation(true);
      await _locationService.start();
    } catch (_) {
      if (mounted) AppSnackbars.showError(context, context.l10n.trackingErrorUpdateFailed);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _actionStop() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      HapticFeedback.heavyImpact();
      await _locationService.stop();
      await _prefs.setShareLocation(false);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  /// Resumes a session paused from the notification. Pausing has no in-app
  /// trigger (only the notification's Pause action), so this is the only
  /// place a resume can start from other than reopening that notification.
  Future<void> _actionResume() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      HapticFeedback.mediumImpact();
      await _locationService.resumeTracking();
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  /// Sets [_batteryRestricted] for the inline hint. Never opens anything by
  /// itself: the dialog only shows if the user taps the hint.
  Future<void> _checkBatteryOptimization() async {
    try {
      await _prefs.ensureInitialized();
      if (_prefs.batteryOptimizationPromptDismissed || !_locationService.isRunning.value) {
        if (_batteryRestricted && mounted) setState(() => _batteryRestricted = false);
        return;
      }
      final restricted = await _locationService.isBatteryRestricted();
      if (mounted && _batteryRestricted != restricted) {
        setState(() => _batteryRestricted = restricted);
      }
    } catch (e) {
      debugPrint('Failed to check battery optimization: $e');
    }
  }

  /// Straight to Android's own "allow in background" prompt: no in-app dialog
  /// in between. The hint re-checks on resume and disappears once allowed.
  Future<void> _openBatteryDialog() => _locationService.requestBatteryExemption();

  void _setupUploadSuccessListener() {
    _subs.add(AppEventBus.instance.on<UploadSuccessEvent>().listen(_onUploadSuccess));
    _subs.add(AppEventBus.instance.on<TabReselectedEvent>().listen((e) {
      if (e.index == 0) _recenterTrigger.value++;
    }));
  }

  void _onUploadSuccess(UploadSuccessEvent event) {
    if (!mounted) return;
    final prevCount = _claimedTileCount;
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _loadH3Tiles(force: true).then((_) {
        if (!mounted) return;
        // Remove newly confirmed cells from the pending set.
        final confirmedIndices = _h3Tiles
            .where((t) => t.h3Index.isNotEmpty)
            .map((t) => BigInt.tryParse(t.h3Index, radix: 16))
            .whereType<BigInt>()
            .toSet();
        _sessionVisitedCells.removeAll(confirmedIndices);
        setState(() {
          _pendingCellBoundaries = _sessionVisitedCells.map((idx) {
            try {
              return _h3.cellToBoundary(idx).map((c) => LatLng(c.lat, c.lon)).toList();
            } catch (_) { return <LatLng>[]; }
          }).where((b) => b.isNotEmpty).toList();
        });
        final newCount = _claimedTileCount;
        final gained = newCount - prevCount;
        if (gained > 0) HapticFeedback.mediumImpact();
        // No sheet, no text toast: the new hexagon appearing on the map plus the haptic
        // above is the feedback.
      });
    });
  }



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationStreamSub?.cancel();
    _subs.cancelAll();
    _slowLoadTimer?.cancel();
    _locationService.isRunning.removeListener(_handleServiceRunningChange);
    _recenterTrigger.dispose();
    _userLocationNotifier.dispose();
    _userAccuracyNotifier.dispose();
    _followModeNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reset retry counters + slow-load state so a fresh resume gets a full budget.
      _h3RetryCount = 0;
      _globalRetryCount = 0;
      _slowLoadTimer?.cancel();
      _showSlowLoadHint = false;
      // Fire async work without awaiting - lifecycle callbacks must return synchronously.
      if (_locationService.isRunning.value) {
        unawaited(_locationService.flushSensorBuffers());
      }
      _checkServiceStatus();
      unawaited(_checkBatteryOptimization());
      _reloadUploadStatus();
      _loadH3Tiles();
      unawaited(_checkPermissionHealth());
      unawaited(_loadStreak());
    }
  }

  Future<void> _reloadUploadStatus() async {
    await _prefs.ensureInitialized();
    final lastUpload = _prefs.lastUploadAt;
    if (lastUpload != null) {
      _locationService.uploadStatus.value =
          _locationService.uploadStatus.value.copyWith(lastUpload: lastUpload);
    }
  }

  Future<void> _checkServiceStatus() async {
    // The shared_preferences plugin caches the whole file in memory and only
    // re-reads it on an explicit reload() - it has no way to know the native
    // side wrote to the same file directly (ForegroundService.stopForegroundService()
    // does, while the app was backgrounded). Without this, foregroundServiceEnabled
    // below could still read the stale "true" from before a Stop tapped from the
    // notification, and auto-restart a session the user explicitly stopped.
    await _prefs.reload();
    final isRunning = await _locationService.isServiceRunning();
    if (!isRunning && _prefs.foregroundServiceEnabled) {
      final wasUserStopped = await _locationService.wasAppUserStopped();
      if (wasUserStopped) {
        debugPrint('App was user-stopped by system. Not auto-restarting tracking.');
        await _prefs.setForegroundServiceEnabled(false);
        await _prefs.setTrackingPaused(false);
        return;
      }
      if (_prefs.trackingPaused) {
        debugPrint('Service was paused when killed - not auto-restarting');
        await _prefs.setForegroundServiceEnabled(false);
        await _prefs.setTrackingPaused(false);
      } else {
        debugPrint('Service was running before but is now stopped. Auto-restarting...');
        await _locationService.start();
      }
    }
  }

  /// Loads the last cached tile response from SharedPreferences.
  /// JSON decoding happens on a background isolate to avoid blocking the first frame.
  Future<void> _loadCachedTiles() async {
    final personalJson = _prefs.cachedPersonalTiles;
    final globalJson = _prefs.cachedGlobalTiles;

    // Decode both on background isolates in parallel - don't block UI thread.
    final results = await Future.wait([
      if (personalJson != null)
        compute((String j) => jsonDecode(j) as Map<String, dynamic>, personalJson)
      else
        Future<Map<String, dynamic>>.value({}),
      if (globalJson != null)
        compute((String j) => jsonDecode(j) as Map<String, dynamic>, globalJson)
      else
        Future<Map<String, dynamic>>.value({}),
    ]);

    if (!mounted) return;

    final personalData = results[0];
    if (personalData.isNotEmpty) {
      try {
        final tiles = UserTilesResponse.fromJson(personalData).tiles;
        if (tiles.isNotEmpty && mounted) {
          setState(() {
            _h3Tiles = tiles;
            _h3TilesLoading = false; // suppress spinner — show stale map instead
          });
        }
      } catch (_) {}
    }

    final globalData = results[1];
    if (globalData.isNotEmpty) {
      try {
        final tiles = GlobalTilesResponse.fromJson(globalData).tiles;
        if (tiles.isNotEmpty && mounted) {
          setState(() => _globalTiles = tiles);
        }
      } catch (_) {}
    }
  }

  Future<void> _loadH3Tiles({bool force = false}) async {
    // Skip if recently fetched - prevents hammering backend on every resume.
    if (!force && _lastTilesFetch != null &&
        DateTime.now().difference(_lastTilesFetch!) < _kTilesCooldown) { return; }
    // Stale-while-revalidate: if we have cached tiles, keep showing them while
    // fetching fresh data in background - no spinner, no blank map on resume.
    // Only show spinner on true cold open (never had tiles yet).
    if (_h3Tiles.isEmpty) {
      setState(() => _h3TilesLoading = true);
      // After 8s with no response, show "Starting up…" hint so user knows
      // it's not frozen (Render free cold start can take 30-60s).
      _slowLoadTimer?.cancel();
      _slowLoadTimer = Timer(kSlowLoadThreshold, () {
        if (mounted && _h3TilesLoading) {
          setState(() => _showSlowLoadHint = true);
        }
      });
    }
    try {
      final data = await BackendClient.get(kApiUserTiles);
      final response = UserTilesResponse.fromJson(data);
      if (kDebugMode) debugPrint('Tiles: ${response.tiles.length} personal tiles');
      if (mounted) {
        final newCount = response.tiles.where((t) => t.boundary != null).length;
        await _prefs.setLastKnownZoneCount(newCount);
        _h3RetryCount = 0;
        _slowLoadTimer?.cancel();
        setState(() {
          _h3Tiles = response.tiles;
          _h3TilesLoading = false;
          _showSlowLoadHint = false;
          _lastTilesFetch = DateTime.now();
        });
        unawaited(_updateHomeWidget());
        // Persist for instant display on next open.
        unawaited(_prefs.setCachedPersonalTiles(jsonEncode(data)));
        // Geocode neighborhood from the most-sampled tile centroid - fire-and-forget.
        // Only runs once (or when name is missing). Sends H3 cell centroid (~461m),
        // not the user's actual GPS position.
        if (_prefs.territoryLabel == null && response.tiles.isNotEmpty) {
          unawaited(_refreshNeighborhoodName(response.tiles));
        }
        if (response.tiles.isNotEmpty) _updateAreaConditionLine(response.tiles);
      }
    } on ApiException catch (e) {
      debugPrint('Tiles: ApiException ${e.statusCode}');
      _slowLoadTimer?.cancel();
      if (mounted) setState(() { _h3TilesLoading = false; _showSlowLoadHint = false; });
      if (e.isUnauthorized && _h3RetryCount < kMaxTileRetries) {
        _h3RetryCount++;
        await Future.delayed(kRetryDelay401);
        if (mounted) _loadH3Tiles();
        return;
      }
      if (_h3RetryCount < kMaxTileRetries) {
        _h3RetryCount++;
        await Future.delayed(kRetryDelayNetError);
        if (mounted && _h3Tiles.isEmpty) _loadH3Tiles();
      }
    } catch (e) {
      debugPrint('Failed to load H3 tiles: $e');
      _slowLoadTimer?.cancel();
      if (mounted) setState(() { _h3TilesLoading = false; _showSlowLoadHint = false; });
      if (_h3RetryCount < kMaxTileRetries) {
        _h3RetryCount++;
        await Future.delayed(kRetryDelayNetError);
        if (mounted && _h3Tiles.isEmpty) _loadH3Tiles();
      }
    }
  }


  /// Reverse-geocode the neighborhood name from the most-sampled personal tile.
  /// Result is cached in SharedPreferences so Nominatim is called at most once.
  Future<void> _refreshNeighborhoodName(List<H3Tile> tiles) async {
    final best = tiles
        .where((t) => t.centroid != null)
        .fold<H3Tile?>(null, (best, t) =>
            best == null || t.sampleCount > best.sampleCount ? t : best);
    if (best?.centroid == null) return;
    final name = await reverseGeocodeNeighborhood(
        best!.centroid!.latitude, best.centroid!.longitude);
    if (name != null && name.isNotEmpty && mounted) {
      await _prefs.setTerritoryLabel(name);
    }
  }

  /// Aggregate sensor data across personal tiles and derive a condition line.
  /// Only surfaces non-normal conditions (anomalous light, surface, or activity).
  void _updateAreaConditionLine(List<H3Tile> tiles) {
    final goodTiles = tiles.where((t) => (t.qualityRatio ?? 0) > 0.3).toList();
    if (goodTiles.isEmpty) return;
    double? avgLux, avgMovement, avgVibration;
    final luxVals = goodTiles.map((t) => t.avgLux).whereType<double>().toList();
    final movVals = goodTiles.map((t) => t.avgMovement).whereType<double>().toList();
    final vibVals = goodTiles.map((t) => t.avgVibration).whereType<double>().toList();
    if (luxVals.isNotEmpty) avgLux = luxVals.reduce((a, b) => a + b) / luxVals.length;
    if (movVals.isNotEmpty) avgMovement = movVals.reduce((a, b) => a + b) / movVals.length;
    if (vibVals.isNotEmpty) avgVibration = vibVals.reduce((a, b) => a + b) / vibVals.length;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    final isNight = DateTime.now().hour < 6 || DateTime.now().hour >= 20;
    final line = SensorInsights.tileConditionLine(
      l10n,
      isNight: isNight,
      avgLux: avgLux,
      avgMovement: avgMovement,
      avgVibration: avgVibration,
    );
    // Only show if not generic "normal" - surface surprises, not averages.
    final normal = l10n.insightNormal;
    setState(() => _areaConditionLine = line == normal ? null : line);
  }

  /// Load community coverage tiles (all users, cached 5 min on server).
  /// Loads silently in background - never blocks the loading spinner.
  Future<void> _loadGlobalTiles() async {
    try {
      final data = await BackendClient.get(kApiTilesGlobal);
      final response = GlobalTilesResponse.fromJson(data);
      debugPrint('Global tiles: ${response.tiles.length} community tiles');
      _globalRetryCount = 0;
      if (mounted) setState(() => _globalTiles = response.tiles);
      unawaited(_prefs.setCachedGlobalTiles(jsonEncode(data)));
    } on ApiException catch (e) {
      debugPrint('Global tiles: ApiException ${e.statusCode}');
      if (_globalRetryCount >= kMaxTileRetries) return;
      _globalRetryCount++;
      final delay = e.isUnauthorized ? kRetryDelay401 : kGlobalTileRetryDelay;
      await Future.delayed(delay);
      if (mounted && _globalTiles.isEmpty) _loadGlobalTiles();
    } catch (e) {
      debugPrint('Failed to load global tiles: $e');
      if (_globalRetryCount >= kMaxTileRetries) return;
      _globalRetryCount++;
      await Future.delayed(kGlobalTileRetryDelay);
      if (mounted && _globalTiles.isEmpty) _loadGlobalTiles();
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: kCoarseGpsTimeout,
      );
      if (mounted) {
        final pos = LatLng(position.latitude, position.longitude);
        _userLocationNotifier.value = pos;
        _prefs.saveLastPosition(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Failed to get user location: $e');
    }
  }

  /// Return last saved position from prefs - used as initial map center
  /// so the map opens where the user was, not Colmar.
  LatLng? _cachedLocation() {
    final saved = _prefs.lastKnownPosition;
    if (saved == null) return null;
    return LatLng(saved.lat, saved.lng);
  }

  void _subscribeToLocationUpdates() {
    _locationStreamSub =
        _locationService.locationStream.listen((locationData) {
      if (!mounted) return;

      // Kalman filter: smooth display position. Raw coords preserved for upload/prefs.
      final acc = locationData.accuracy.clamp(1.0, 100.0);
      final R = (acc / 111000) * (acc / 111000);
      // Predict
      _kalmanPLat += _kKalmanQ;
      _kalmanPLon += _kKalmanQ;
      // Update
      final kLat = _kalmanPLat / (_kalmanPLat + R);
      final kLon = _kalmanPLon / (_kalmanPLon + R);
      _kalmanLat = (_kalmanLat == null)
          ? locationData.latitude
          : _kalmanLat! + kLat * (locationData.latitude - _kalmanLat!);
      _kalmanLon = (_kalmanLon == null)
          ? locationData.longitude
          : _kalmanLon! + kLon * (locationData.longitude - _kalmanLon!);
      _kalmanPLat = (1 - kLat) * _kalmanPLat;
      _kalmanPLon = (1 - kLon) * _kalmanPLon;

      final smoothPos = LatLng(_kalmanLat!, _kalmanLon!);
      _userLocationNotifier.value = smoothPos;
      _userAccuracyNotifier.value = locationData.accuracy;
      _updateCurrentH3Cell(smoothPos);
      // Debounce persistence - raw GPS coords, not filtered
      final now = DateTime.now();
      if (_lastPosSave == null || now.difference(_lastPosSave!) >= const Duration(seconds: 60)) {
        _lastPosSave = now;
        _prefs.saveLastPosition(locationData.latitude, locationData.longitude);
      }
    });
  }

  void _updateCurrentH3Cell(LatLng pos) {
    try {
      final cellIndex = _h3.geoToCell(
        h3f.GeoCoord(lat: pos.latitude, lon: pos.longitude),
        _kLiveCellResolution,
      );
      // Already showing this cell - nothing to do.
      if (cellIndex == _currentH3Index) {
        _pendingH3Index = null;
        _pendingH3Count = 0;
        return;
      }
      // Stability gate: require N consecutive readings in the new cell before
      // committing. Prevents bus-speed bouncing where cells change every 5-15s
      // due to GPS multipath - the hex stays locked until you've genuinely
      // settled in the new cell.
      if (cellIndex == _pendingH3Index) {
        _pendingH3Count++;
      } else {
        _pendingH3Index = cellIndex;
        _pendingH3Count = 1;
      }
      if (_pendingH3Count < _kLiveCellStabilityThreshold) return;

      // Stable - commit the new cell.
      _currentH3Index = cellIndex;
      _pendingH3Index = null;
      _pendingH3Count = 0;
      final boundary = _h3
          .cellToBoundary(cellIndex)
          .map((c) => LatLng(c.lat, c.lon))
          .toList();
      // Add to session visited cells if not already confirmed by backend.
      final alreadyConfirmed = _h3Tiles.any((t) =>
          t.h3Index.isNotEmpty && BigInt.tryParse(t.h3Index, radix: 16) == cellIndex);
      if (!alreadyConfirmed && _locationService.isRunning.value) {
        _sessionVisitedCells.add(cellIndex);
        _pendingCellBoundaries = _sessionVisitedCells.map((idx) {
          try {
            return _h3.cellToBoundary(idx).map((c) => LatLng(c.lat, c.lon)).toList();
          } catch (_) { return <LatLng>[]; }
        }).where((b) => b.isNotEmpty).toList();
      }
      if (mounted) setState(() => _currentH3Boundary = boundary);
    } catch (_) {}
  }

  void _onTileTap(H3Tile tile) {
    HapticFeedback.lightImpact();
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    pushDetailPage(context, builder: (_) => TileInfoSheet(tile: tile, isDark: isDark, l10n: l10n));
  }

  void _openSensorSheet() {
    pushDetailPage(context, title: context.l10n.sensorLiveSheetTitle, builder: (_) => _SensorLiveSheet(locationService: _locationService));
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Stack(
          children: [
            // 0. Full-screen heatmap
            ListenableBuilder(
              listenable: Listenable.merge([
                _userLocationNotifier,
                _userAccuracyNotifier,
                _locationService.isRunning,
                _locationService.isPaused,
              ]),
              builder: (context, _) {
                final isTracking = _locationService.isRunning.value &&
                    !_locationService.isPaused.value;
                return CoverageMapWidget(
                  tiles: [...(_showCommunity ? _globalTiles : <H3Tile>[]), ..._h3Tiles],
                  userLocation: _userLocationNotifier.value,
                  userAccuracy: _userAccuracyNotifier.value,
                  currentH3Boundary: _currentH3Boundary,
                  pendingCellBoundaries: _pendingCellBoundaries,
                  isTracking: isTracking,
                  onTileTap: _onTileTap,
                  onTileLongPress: _onTileTap,
                  fillScreen: true,
                  isLoading: _h3TilesLoading,
                  recenterTrigger: _recenterTrigger,
                  followModeNotifier: _followModeNotifier,
                  lastSessionAt: _prefs.lastSessionEndAt,
                  controlsPadding: EdgeInsets.only(
                    top: topPadding,
                    bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceLg,
                  ),
                );
              },
            ),

            // 0b. Cold-start hint - shown after 8s if still loading
            if (_showSlowLoadHint)
              Positioned(
                bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceXxl,
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs),
                    decoration: BoxDecoration(
                      color: AppColors.mapOverlayMid,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      context.l10n.serverWakingUp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.darkTextSecondary,
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                  ),
                ),
              ),

            // Overlays
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.floatingNavHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // Top bar: Mine/All left - stats right
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mine / All toggle
                          _MineAllToggle(
                            showCommunity: _showCommunity,
                            mineCount: _claimedTileCount,
                            communityCount: _globalTiles.length,
                            onChanged: (val) =>
                                setState(() => _showCommunity = val),
                          ),
                          const Spacer(),
                          // Area summary top-right - tap navigates to Stats
                          if (_claimedTileCount > 0)
                            _MapSummary(
                              claimedTileCount: _claimedTileCount,
                              territoryLabel: _prefs.territoryLabel,
                              areaConditionLine: _areaConditionLine,
                              onTap: () => widget.onGoToStats?.call(),
                            ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Zero-state - shown once to new users before first zone
                    if (_h3Tiles.isEmpty && !_h3TilesLoading && !_locationService.isRunning.value)
                      const _ZeroStateCard(),

                    // Permission lost banner
                    if (_permissionLost)
                      Padding(
                        padding: const EdgeInsets.only(
                            left: AppTheme.spaceMd,
                            right: AppTheme.spaceMd,
                            bottom: AppTheme.spaceSm),
                        child: _PermissionLostCard(
                          onFix: () async {
                            await Geolocator.openAppSettings();
                          },
                        ),
                      ),

                    if (_batteryRestricted && !_permissionLost)
                      Padding(
                        padding: const EdgeInsets.only(
                            left: AppTheme.spaceMd,
                            right: AppTheme.spaceMd,
                            bottom: AppTheme.spaceSm),
                        child: _BatteryHint(onTap: _openBatteryDialog),
                      ),

                    // Bottom row - floating buttons, no container
                    Padding(
                      padding: const EdgeInsets.only(
                          left: AppTheme.spaceMd,
                          right: AppTheme.spaceMd,
                          bottom: AppTheme.spaceMd),
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          _locationService.isRunning,
                          _locationService.isPaused,
                          _userLocationNotifier,
                        ]),
                        builder: (context, _) {
                          final isRunning = _locationService.isRunning.value;
                          final isPaused  = _locationService.isPaused.value;
                          final hasLoc    = _userLocationNotifier.value != null;
                          return Row(
                            children: [
                              _InfoButton(onTap: _openSensorSheet),
                              Expanded(
                                child: Center(
                                  child: _HomeActionBar(
                                    isRunning: isRunning,
                                    isPaused: isPaused,
                                    isBusy: _actionBusy,
                                    onStart: _actionStart,
                                    onStop: _actionStop,
                                    onResume: _actionResume,
                                  ),
                                ),
                              ),
                              if (hasLoc)
                                Semantics(
                                  button: true,
                                  label: context.l10n.semanticsCenterOnMe,
                                  child: _MyLocationButton(
                                    onPressed: () => _recenterTrigger.value++,
                                    followModeNotifier: _followModeNotifier,
                                  ),
                                )
                              else
                                const SizedBox(width: _kLocationBtnSize),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Map overlay pieces

/// One compact panel: area mapped, then neighbourhood and any notable
/// condition as quiet secondary lines. Streak and today's gain live in Stats -
/// the map stays the focus.
class _MapSummary extends StatelessWidget {
  const _MapSummary({
    required this.claimedTileCount,
    required this.territoryLabel,
    required this.areaConditionLine,
    required this.onTap,
  });

  final int claimedTileCount;
  final String? territoryLabel;
  final String? areaConditionLine;
  final VoidCallback onTap;

  String _areaLabel(BuildContext context) {
    final km2 = claimedTileCount * kKm2PerCell;
    final area = km2 < 1.0
        ? '${km2.toStringAsFixed(2)} km²'
        : '${km2.toStringAsFixed(1)} km²';
    return context.l10n.homeStatArea(area);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = [territoryLabel, areaConditionLine]
        .whereType<String>()
        .where((s) => s.isNotEmpty);
    return PressScaleDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
        decoration: BoxDecoration(
          color: AppColors.shadowDark(0.55),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _areaLabel(context),
              style: textTheme.labelLarge?.copyWith(
                fontWeight: AppFontWeights.semibold,
                color: AppColors.darkTextPrimary,
              ),
            ),
            for (final line in secondary)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown once to new users before their first zone - fully static, so `const`
/// keeps it out of every rebuild.
class _ZeroStateCard extends StatelessWidget {
  const _ZeroStateCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
        decoration: BoxDecoration(
          color: AppColors.mapOverlayMid,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hexagon_outlined,
                size: AppIconSizes.sm, color: AppColors.primary),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.mapZeroStateTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: AppFontWeights.semibold,
                      color: AppColors.darkTextPrimary,
                      letterSpacing: AppTheme.letterSpacingSubtle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom action bar

class _HomeActionBar extends StatelessWidget {
  const _HomeActionBar({
    required this.isRunning,
    required this.isPaused,
    required this.isBusy,
    required this.onStart,
    required this.onStop,
    required this.onResume,
  });

  final bool isRunning;
  /// Only meaningful while [isRunning]: true when paused from the
  /// notification's Pause action (there is no in-app pause trigger).
  final bool isPaused;
  final bool isBusy;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!isRunning) {
      // Icon-only, like a media player's play button - no label needed, the
      // icon language is already universal.
      return _ActionButton(
        semanticLabel: l10n.homeActionStart,
        icon: Icons.play_arrow_rounded,
        iconSize: AppIconSizes.lg,
        padding: AppTheme.spaceLg,
        busy: isBusy,
        onPressed: onStart,
        style: _ActionBtnStyle.primary,
      );
    }
    if (isPaused) {
      // Distinct from both Start and Stop: this used to render identically to
      // the active Stop button, so pausing from the notification looked like
      // nothing had happened in the app.
      return _ActionButton(
        semanticLabel: l10n.homeActionResume,
        icon: Icons.play_arrow_rounded,
        iconSize: AppIconSizes.lg,
        padding: AppTheme.spaceLg,
        busy: isBusy,
        onPressed: onResume,
        style: _ActionBtnStyle.primary,
      );
    }
    return _ActionButton(
      semanticLabel: l10n.homeActionStop,
      icon: Icons.stop_rounded,
      iconSize: AppIconSizes.sm,
      padding: AppTheme.spaceSm,
      busy: isBusy,
      onPressed: onStop,
      style: _ActionBtnStyle.danger,
    );
  }
}

/// Icon-only circular action button. [semanticLabel] carries the meaning for
/// screen readers since there is no visible text - the icon alone (play/stop,
/// same convention as any media player) is enough for sighted users.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.semanticLabel,
    required this.icon,
    required this.iconSize,
    required this.padding,
    required this.busy,
    required this.onPressed,
    required this.style,
  });

  final String semanticLabel;
  final IconData icon;
  final double iconSize;
  final double padding;
  final bool busy;
  final VoidCallback onPressed;
  final _ActionBtnStyle style;

  @override
  Widget build(BuildContext context) {
    final bgColor = switch (style) {
      _ActionBtnStyle.primary => AppColors.primary,
      _ActionBtnStyle.danger  => AppColors.actionDangerBg,
    };
    final fgColor = switch (style) {
      _ActionBtnStyle.primary => AppColors.actionPrimaryFg,
      _ActionBtnStyle.danger  => AppColors.error,
    };
    final borderColor = switch (style) {
      _ActionBtnStyle.primary => Colors.transparent,
      _ActionBtnStyle.danger  => AppColors.error.withValues(alpha: 0.25),
    };

    return Semantics(
      button: true,
      label: semanticLabel,
      child: AnimatedOpacity(
        duration: AppDurations.press,
        opacity: busy ? 0.65 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy ? null : onPressed,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: Ink(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: borderColor, width: AppBorderWidths.thin),
                boxShadow: style == _ActionBtnStyle.primary
                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 3))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: busy
                    ? SizedBox(
                        width: iconSize, height: iconSize,
                        child: CircularProgressIndicator(strokeWidth: 2, color: fgColor),
                      )
                    : Icon(icon, size: iconSize, color: fgColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ActionBtnStyle { primary, danger }

// Private widgets

/// Shows gps_fixed (primary tint) when follow mode is active, gps_not_fixed otherwise.
class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.onPressed, this.followModeNotifier});
  final VoidCallback onPressed;
  final ValueNotifier<bool>? followModeNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: followModeNotifier ?? ValueNotifier(false),
      builder: (context, isFollowing, _) {
        // Standard pattern (Google Maps / Apple Maps):
        // Button background stays white always - icon color signals state.
        return Material(
          color: AppColors.mapOverlayDark,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: _kLocationBtnSize,
              height: _kLocationBtnSize,
              child: AnimatedSwitcher(
                duration: AppDurations.fast,
                child: Icon(
                  isFollowing ? Icons.gps_fixed : Icons.gps_not_fixed,
                  key: ValueKey(isFollowing),
                  color: isFollowing
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.55),
                  size: AppIconSizes.sm,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet showing live sensor readings.
/// Opened when user taps the status chip - progressive disclosure pattern.
class _SensorLiveSheet extends StatelessWidget {
  const _SensorLiveSheet({required this.locationService});
  final ForegroundLocationService locationService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppTheme.pagePadding,
      children: [
        SensorSection(locationService: locationService),
        const SizedBox(height: AppTheme.spaceSm),
        _TransparencyCard(locationService: locationService),
      ],
    );
  }
}

/// "What leaves your phone" - plain-language statement of exactly what is
/// uploaded, and explicitly what is NOT collected. Trust through visibility.
class _TransparencyCard extends StatelessWidget {
  const _TransparencyCard({required this.locationService});
  final ForegroundLocationService locationService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_outlined,
              size: AppIconSizes.xs,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The line that matters - what we do NOT take.
                  Text(
                    l10n.transparencyNothingElse,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary(isDark),
                      fontWeight: AppFontWeights.semibold,
                      height: AppLineHeights.snug,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXxxs),
                  ValueListenableBuilder<UploadStatusSnapshot>(
                    valueListenable: locationService.uploadStatus,
                    builder: (context, status, _) {
                      final last = status.lastUpload;
                      final style = theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary(isDark),
                      );
                      if (last == null) {
                        return Text(l10n.transparencyNoUploadYet, style: style);
                      }
                      return Row(
                        children: [
                          Text('${l10n.transparencyLastUpload} · ', style: style),
                          TimeAgoText(timestamp: last, style: style),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Map layer toggle - switches between personal and community coverage tiles.
/// Mine / All segmented pill toggle.
class _MineAllToggle extends StatelessWidget {
  const _MineAllToggle({
    required this.showCommunity,
    required this.onChanged,
    this.mineCount = 0,
    this.communityCount = 0,
  });
  final bool showCommunity;
  final ValueChanged<bool> onChanged;
  final int mineCount;
  final int communityCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.shadowDark(0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      padding: const EdgeInsets.all(AppTheme.spaceXxxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Seg(
            label: mineCount > 0 ? '${l10n.layerMine} $mineCount' : l10n.layerMine,
            active: !showCommunity,
            onTap: () => onChanged(false),
          ),
          _Seg(
            label: l10n.layerAll,
            active: showCommunity,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScaleDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.segmentToggle,
        curve: Curves.easeOut,
        // Vertical padding keeps the tap target above the 24px WCAG 2.2 minimum.
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs - 2),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: active ? AppFontWeights.bold : AppFontWeights.medium,
            color: active ? AppColors.actionSegActiveFg : AppColors.darkTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// Small circular info button - opens sensor sheet.
class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScaleDetector(
      onTap: onTap,
      semanticLabel: context.l10n.sensorLiveSheetTitle,
      child: Container(
        width: _kLocationBtnSize,
        height: _kLocationBtnSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.shadowDark(0.6),
        ),
        child: const Icon(Icons.info_outline_rounded,
            color: AppColors.darkTextSecondary, size: AppIconSizes.sm),
      ),
    );
  }
}

/// One-line, tap-to-open hint. Sits in the layout (never over the map's
/// controls) and does nothing until the user chooses to act on it.
class _BatteryHint extends StatelessWidget {
  const _BatteryHint({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: PressScaleDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
          decoration: BoxDecoration(
            color: AppColors.mapOverlayMid,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.battery_alert_rounded,
                  size: AppIconSizes.sm, color: AppColors.warning),
              const SizedBox(width: AppTheme.spaceXs),
              Expanded(
                child: Text(
                  context.l10n.batteryDialogTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.darkTextPrimary,
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: AppIconSizes.sm, color: AppColors.darkTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persistent banner shown when background location permission was revoked
/// while tracking is supposed to be running. Not dismissable - stays until fixed.
class _PermissionLostCard extends StatelessWidget {
  const _PermissionLostCard({required this.onFix});
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PressScaleDetector(
      onTap: onFix,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off_rounded, color: AppColors.warning, size: AppIconSizes.sm),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.permissionLostTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: AppFontWeights.semibold,
                      color: AppColors.warning,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs + 2, vertical: AppTheme.spaceTiny + 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
              ),
              child: Text(
                l10n.permissionLostCta,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: AppFontWeights.semibold,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
