import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:h3_flutter/h3_flutter.dart' as h3f;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../core/extensions/context_extensions.dart';
import '../l10n/app_localizations.dart';
import '../core/themes.dart';
import '../services/location/foreground_location_service.dart';
import '../services/network/backend_client.dart';
import '../core/events/app_events.dart';
import '../utils/app_snackbars.dart';
import '../core/app_preferences.dart';
import '../widgets/coverage_map_widget.dart';
import '../widgets/tracking_status_chip.dart';
import '../widgets/tracking_fab.dart';
import '../widgets/sensor_section.dart';
import '../models/sensor_models.dart';
import '../data/repositories/contribution_repository.dart';

// My Location button: 48×48 standard touch target.
const _kLocationBtnSize = AppTheme.minTouchTarget; // 48

/// Top-level BFS function — runs in a compute() isolate.
/// Takes H3 hex index strings (e.g. "891f9abc0a3ffff"), returns largest cluster.
int _computeMaxCluster(List<String> hexIndices) {
  if (hexIndices.isEmpty) return 0;
  final h3 = const h3f.H3Factory().load();
  // Parse hex strings → BigInt (H3 internal format)
  final cellSet = <BigInt>{};
  for (final s in hexIndices) {
    try { cellSet.add(BigInt.parse(s, radix: 16)); } catch (_) {}
  }
  if (cellSet.isEmpty) return 0;
  final visited = <BigInt>{};
  int maxCluster = 0;

  for (final cell in cellSet) {
    if (visited.contains(cell)) continue;
    int size = 0;
    final queue = <BigInt>[cell];
    visited.add(cell);
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      size++;
      for (final neighbor in h3.gridDisk(current, 1)) {
        if (!visited.contains(neighbor) && cellSet.contains(neighbor)) {
          visited.add(neighbor);
          queue.add(neighbor);
        }
      }
    }
    if (size > maxCluster) maxCluster = size;
  }
  return maxCluster;
}
// H3 resolution for live cell highlight (res 9 ≈ 174m edge length — city block scale)
const _kLiveCellResolution = 9;

/// Home screen — full-screen map layout.
///
/// Layer order (bottom → top):
///   0. CoverageMapWidget (edge-to-edge background)
///   1. Status chip (top overlay)
///   2. Map legend (top-right overlay)
///   3. TrackingFab + MyLocationButton (bottom overlay)
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
  final _h3 = const h3f.H3Factory().load();
  late final _userLocationNotifier = ValueNotifier<LatLng?>(_cachedLocation());
  /// Incrementing recenter triggers CoverageMapWidget to move camera to user.
  final _recenterTrigger = ValueNotifier<int>(0);

  bool _batteryPromptOpen = false;
  StreamSubscription<UploadSuccessEvent>? _uploadSuccessSub;
  /// Zone count at the moment tracking started (this foreground session).
  /// 0 = tracking was already running when app opened — no delta shown.
  int _sessionStartZoneCount = 0;
  /// Wall-clock time when tracking started — drives elapsed timer in hint pill.
  DateTime? _sessionStartTime;
  /// Zones gained since last app open — shown as re-engagement banner after tile load.
  int _zonesGainedSinceLastOpen = 0;
  /// True when map is actively following the user's GPS position.
  final _followModeNotifier = ValueNotifier<bool>(false);
  StreamSubscription? _locationStreamSub;
  List<H3Tile> _h3Tiles = [];
  List<H3Tile> _globalTiles = [];
  bool _h3TilesLoading = true;
  DateTime? _lastTilesFetch;
  static const _kTilesCooldown = Duration(minutes: 2);
  /// Retry counters — reset on success, capped at kMaxTileRetries.
  int _h3RetryCount = 0;
  int _globalRetryCount = 0;
  /// Flips true after 8s of loading with no response — shows "Starting up…" hint.
  bool _showSlowLoadHint = false;
  Timer? _slowLoadTimer;
  /// Largest contiguous H3 hex cluster — computed off-thread after tiles load.
  int _maxCluster = 0;

  /// Boundary of the H3 cell the user is currently inside — shown as live amber
  /// highlight on the map while tracking is active.
  List<LatLng>? _currentH3Boundary;
  /// Last committed H3 cell index — the one currently rendered on the map.
  BigInt? _currentH3Index;
  /// Candidate cell waiting for stability confirmation.
  BigInt? _pendingH3Index;
  /// How many consecutive GPS readings have landed in [_pendingH3Index].
  int _pendingH3Count = 0;
  /// Minimum consecutive hits before committing a new live cell.
  /// At 10s GPS interval: 2 hits = ~20s — imperceptible when walking, prevents
  /// bus-speed bouncing where cells change every 5-15s.
  static const _kLiveCellStabilityThreshold = 2;
  /// Cached tile count — avoids recomputing on every build frame.
  int get _claimedTileCount => _h3Tiles.where((t) => t.boundary != null).length;
  /// Current streak — loaded once from local DB on init, shown on idle home.
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService.isRunning.addListener(_handleServiceRunningChange);
    _checkServiceStatus();
    _setupUploadSuccessListener();
    _checkBatteryOptimization();
    // Load cached tiles off the main thread — map shows last known state before network.
    unawaited(_loadCachedTiles());
    // Prefetch Firebase token before tile requests fire — avoids token latency
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
      final stats = await ContributionRepository().getStats();
      if (mounted) setState(() => _currentStreak = stats.currentStreak);
    } catch (_) {}
  }

  void _handleServiceRunningChange() {
    if (_locationService.isRunning.value) {
      // Snapshot zone count so we can show "+N new" delta during this session.
      _sessionStartZoneCount = _claimedTileCount;
      _sessionStartTime = DateTime.now();
      _checkBatteryOptimization();
      _maybeShowFirstStart();
    } else {
      // Tracking stopped — persist session data for return hint.
      final gained = _claimedTileCount - _sessionStartZoneCount;
      final sessionDuration = _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!)
          : Duration.zero;
      unawaited(_prefs.saveLastSession(zonesGained: gained.clamp(0, 9999)));
      if (gained > 0 && _sessionStartZoneCount > 0 && mounted) {
        final total = _claimedTileCount;
        Future.delayed(AppDurations.fast, () {
          if (!mounted || !context.mounted) return;
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => _SessionSummarySheet(
              zonesGained: gained,
              totalZones: total,
              sessionDuration: sessionDuration,
              onViewStats: widget.onGoToStats,
            ),
          );
        });
      }
      _sessionStartZoneCount = 0;
      _sessionStartTime = null;
    }
  }

  Future<void> _maybeShowFirstStart() async {
    await _prefs.ensureInitialized();
    if (_prefs.trackingEverStarted) return;
    await _prefs.setTrackingEverStarted();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FirstStartSheet(),
    );
  }

  Future<void> _checkBatteryOptimization() async {
    await Future.delayed(AppDurations.fast);
    if (!mounted) return;
    if (_batteryPromptOpen) return;

    try {
      await _prefs.ensureInitialized();
      if (_prefs.batteryOptimizationPromptDismissed) return;

      final lastShown = _prefs.batteryOptimizationPromptLastShown;
      if (lastShown != null &&
          DateTime.now().difference(lastShown) < kBatteryPromptInterval) {
        return;
      }

      if (!_locationService.isRunning.value) return;

      const platform = MethodChannel('greengains/foreground');
      final bool isIgnoring =
          await platform.invokeMethod('isIgnoringBatteryOptimizations');

      if (!isIgnoring && mounted) {
        _batteryPromptOpen = true;
        await _prefs.setBatteryOptimizationPromptLastShown(DateTime.now());
        try {
          await platform.invokeMethod('requestIgnoreBatteryOptimizations');
        } catch (e) {
          debugPrint('Failed to request battery optimization: $e');
        } finally {
          _batteryPromptOpen = false;
        }
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to check battery optimization: '${e.message}'.");
    }
  }

  void _setupUploadSuccessListener() {
    _uploadSuccessSub =
        AppEventBus.instance.on<UploadSuccessEvent>().listen(_onUploadSuccess);
  }

  void _onUploadSuccess(UploadSuccessEvent event) {
    if (!mounted) return;
    final prevCount = _claimedTileCount;
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _loadH3Tiles(force: true).then((_) {
        if (!mounted) return;
        final newCount = _claimedTileCount;
        final gained = newCount - prevCount;
        // Haptic reward on every zone gain — light, non-intrusive.
        if (gained > 0) HapticFeedback.lightImpact();
        if (!_prefs.firstUploadCelebrated && newCount > 0) {
          unawaited(_prefs.setFirstUploadCelebrated());
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => const _FirstUploadSheet(),
          );
          return;
        }
        final msg = gained > 0
            ? context.l10n.uploadSuccessNewZone(newCount)
            : context.l10n.uploadSuccessMessage;
        HapticFeedback.lightImpact();
        AppSnackbars.showSuccess(context, msg);
        if (gained > 0) {
          _maybeCelebrateMilestone(newCount);
        }
      });
    });
    _maybeRequestReview();
    unawaited(_maybeCelebrateUploadMilestone());
  }

  static const _kMilestones = [5, 10, 25, 50, 100, 250, 500];
  static const _kUploadMilestones = [10, 50, 100, 500, 1000];

  Future<void> _maybeCelebrateMilestone(int zoneCount) async {
    await _prefs.ensureInitialized();
    final lastCelebrated = _prefs.lastMilestoneCelebrated;
    // Find the highest milestone reached that hasn't been celebrated yet.
    final earned = _kMilestones.where((m) => m <= zoneCount && m > lastCelebrated).toList();
    if (earned.isEmpty) return;
    final milestone = earned.last;
    await _prefs.setLastMilestoneCelebrated(milestone);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MilestoneSheet(zoneCount: milestone),
    );
  }

  Future<void> _maybeCelebrateUploadMilestone() async {
    await _prefs.ensureInitialized();
    final count = _prefs.totalUploadCount;
    final lastCelebrated = _prefs.lastUploadMilestoneCelebrated;
    final earned = _kUploadMilestones.where((m) => m <= count && m > lastCelebrated).toList();
    if (earned.isEmpty || !mounted) return;
    final milestone = earned.last;
    await _prefs.setLastUploadMilestoneCelebrated(milestone);
    if (!mounted) return;
    AppSnackbars.showSuccess(context, context.l10n.uploadMilestone(milestone));
  }

  /// Show the Play Store in-app review dialog once, after the user's 5th upload.
  Future<void> _maybeRequestReview() async {
    try {
      await _prefs.ensureInitialized();
      if (_prefs.totalUploadCount < kReviewRequestThreshold) return;
      if (_prefs.reviewRequested) return;
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        await _prefs.setReviewRequested();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationStreamSub?.cancel();
    _uploadSuccessSub?.cancel();
    _slowLoadTimer?.cancel();
    _locationService.isRunning.removeListener(_handleServiceRunningChange);
    _recenterTrigger.dispose();
    _userLocationNotifier.dispose();
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
      // Fire async work without awaiting — lifecycle callbacks must return synchronously.
      if (_locationService.isRunning.value) {
        unawaited(_locationService.flushSensorBuffers());
      }
      _checkServiceStatus();
      _reloadUploadStatus();
      _loadH3Tiles();
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

    // Decode both on background isolates in parallel — don't block UI thread.
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
    // Skip if recently fetched — prevents hammering backend on every resume.
    if (!force && _lastTilesFetch != null &&
        DateTime.now().difference(_lastTilesFetch!) < _kTilesCooldown) { return; }
    // Stale-while-revalidate: if we have cached tiles, keep showing them while
    // fetching fresh data in background — no spinner, no blank map on resume.
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
        final stored = _prefs.lastKnownZoneCount;
        final delta = (stored > 0) ? (newCount - stored).clamp(0, 9999) : 0;
        await _prefs.setLastKnownZoneCount(newCount);
        _h3RetryCount = 0;
        _slowLoadTimer?.cancel();
        setState(() {
          _h3Tiles = response.tiles;
          _h3TilesLoading = false;
          _showSlowLoadHint = false;
          _lastTilesFetch = DateTime.now();
          if (delta > 0) _zonesGainedSinceLastOpen = delta;
        });
        // Persist for instant display on next open.
        unawaited(_prefs.setCachedPersonalTiles(jsonEncode(data)));
        unawaited(_refreshTerritoryLabel(response.tiles));
        unawaited(_updateMaxCluster(response.tiles));
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

  /// Geocodes current GPS position (or most-sampled tile as fallback) and stores
  /// the neighborhood name. Refreshes every session — not cached permanently.
  Future<void> _refreshTerritoryLabel(List<H3Tile> tiles) async {
    // Prefer current GPS position; fall back to most-sampled tile centroid
    final currentPos = _userLocationNotifier.value;
    double? lat, lon;
    if (currentPos != null) {
      lat = currentPos.latitude;
      lon = currentPos.longitude;
    } else {
      final best = tiles
          .where((t) => !t.isGlobal && t.centroid != null)
          .fold<H3Tile?>(null, (prev, t) =>
              prev == null || t.sampleCount > prev.sampleCount ? t : prev);
      if (best == null) return;
      lat = best.centroid!.latitude;
      lon = best.centroid!.longitude;
    }
    try {
      final res = await nominatimClient.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'format': 'json',
          'lat': lat,
          'lon': lon,
          'zoom': 14,
          'addressdetails': 1,
        },
      );
      final address = res.data?['address'] as Map<String, dynamic>?;
      final name = (address?['suburb'] as String?)?.isNotEmpty == true
          ? address!['suburb'] as String
          : (address?['quarter'] as String?)?.isNotEmpty == true
              ? address!['quarter'] as String
              : (address?['neighbourhood'] as String?)?.isNotEmpty == true
                  ? address!['neighbourhood'] as String
                  : (address?['road'] as String?)?.isNotEmpty == true
                      ? address!['road'] as String
                      : null;
      if (name != null) await _prefs.setTerritoryLabel(name);
    } catch (_) {}
  }

  /// BFS cluster computation — off main thread, updates state when done.
  Future<void> _updateMaxCluster(List<H3Tile> tiles) async {
    final indices = tiles
        .where((t) => !t.isGlobal && t.h3Index.isNotEmpty)
        .map((t) => t.h3Index)
        .toList();
    if (indices.isEmpty) return;
    final cluster = await compute(_computeMaxCluster, indices);
    if (mounted && cluster != _maxCluster) {
      setState(() => _maxCluster = cluster);
    }
  }

  /// Load community coverage tiles (all users, cached 5 min on server).
  /// Loads silently in background — never blocks the loading spinner.
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

  /// Return last saved position from prefs — used as initial map center
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
      final pos = LatLng(locationData.latitude, locationData.longitude);
      _userLocationNotifier.value = pos;
      _updateCurrentH3Cell(pos);
      // Persist so next cold start opens at correct location
      _prefs.saveLastPosition(locationData.latitude, locationData.longitude);
    });
  }

  void _updateCurrentH3Cell(LatLng pos) {
    try {
      final cellIndex = _h3.geoToCell(
        h3f.GeoCoord(lat: pos.latitude, lon: pos.longitude),
        _kLiveCellResolution,
      );
      // Already showing this cell — nothing to do.
      if (cellIndex == _currentH3Index) {
        _pendingH3Index = null;
        _pendingH3Count = 0;
        return;
      }
      // Stability gate: require N consecutive readings in the new cell before
      // committing. Prevents bus-speed bouncing where cells change every 5-15s
      // due to GPS multipath — the hex stays locked until you've genuinely
      // settled in the new cell.
      if (cellIndex == _pendingH3Index) {
        _pendingH3Count++;
      } else {
        _pendingH3Index = cellIndex;
        _pendingH3Count = 1;
      }
      if (_pendingH3Count < _kLiveCellStabilityThreshold) return;

      // Stable — commit the new cell.
      _currentH3Index = cellIndex;
      _pendingH3Index = null;
      _pendingH3Count = 0;
      final boundary = _h3
          .cellToBoundary(cellIndex)
          .map((c) => LatLng(c.lat, c.lon))
          .toList();
      if (mounted) setState(() => _currentH3Boundary = boundary);
    } catch (_) {}
  }

  void _onTileTap(H3Tile tile) {
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TileInfoSheet(tile: tile, isDark: isDark, l10n: l10n),
    );
  }

  void _openSensorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SensorLiveSheet(locationService: _locationService),
    );
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
            // ── 0. Full-screen heatmap ────────────────────────────────────
            ListenableBuilder(
              listenable: Listenable.merge([
                _userLocationNotifier,
                _locationService.isRunning,
                _locationService.isPaused,
              ]),
              builder: (context, _) {
                final isTracking = _locationService.isRunning.value &&
                    !_locationService.isPaused.value;
                return CoverageMapWidget(
                  tiles: [..._globalTiles, ..._h3Tiles],
                  userLocation: _userLocationNotifier.value,
                  currentH3Boundary: _currentH3Boundary,
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

            // ── 0b. Cold-start hint — shown after 8s if still loading ───
            if (_showSlowLoadHint)
              Positioned(
                top: topPadding + AppTheme.spaceMd + 48,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs),
                    decoration: BoxDecoration(
                      color: const Color(0xCC111927),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      context.l10n.serverWakingUp,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                  ),
                ),
              ),

            // ── 0c. Contextual hint ─────────────────────────────────────
            // Active tracking → top-center under chip: "+N new zones · MM:SS"
            // Idle/first-use → bottom above FAB: onboarding or return CTA
            ListenableBuilder(
              listenable: Listenable.merge([
                _locationService.isRunning,
                _locationService.isPaused,
              ]),
              builder: (context, _) {
                final isRunning = _locationService.isRunning.value;
                final isPaused  = _locationService.isPaused.value;
                final isActive  = isRunning && !isPaused;

                if (isActive && _sessionStartTime != null) {
                  // Top-center under status chip — zone delta + elapsed + live conditions
                  return Positioned(
                    top: topPadding + AppTheme.spaceMd + 36,
                    left: 0, right: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TrackingHintPill(
                            newZones: (_claimedTileCount - _sessionStartZoneCount).clamp(0, 999),
                            sessionStart: _sessionStartTime ?? DateTime.now(),
                          ),
                          const SizedBox(height: 6),
                          _LiveConditionsLine(
                            conditionsNotifier: _locationService.liveConditions,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (isActive || isPaused) return const SizedBox.shrink();

                // Idle only — top-center below chip (mirrors design top: 74)
                return Positioned(
                  top: topPadding + AppTheme.spaceXs + 44,
                  left: 0, right: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _IdleHintPill(hasTiles: _h3Tiles.isNotEmpty),
                        if (_claimedTileCount > 0) ...[
                          const SizedBox(height: AppTheme.spaceXs),
                          _PassiveSummaryLine(
                            currentZones: _claimedTileCount,
                            lastKnownZones: _prefs.lastKnownZoneCount,
                            lastSessionAt: _prefs.lastSessionEndAt,
                          ),
                        ],
                        if (_currentStreak >= 2) ...[
                          const SizedBox(height: 3),
                          Text(
                            context.l10n.statsStreakDays(_currentStreak),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.warning.withValues(alpha: 0.75),
                              fontWeight: AppFontWeights.medium,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),


            // ── 0d. Top bar — brand mark idle only (clean, no buttons) ──
            ListenableBuilder(
              listenable: Listenable.merge([_locationService.isRunning, _locationService.isPaused]),
              builder: (context, _) {
                final isRunning = _locationService.isRunning.value;
                final isPaused  = _locationService.isPaused.value;
                if (isRunning || isPaused) return const SizedBox.shrink();
                return Positioned(
                  top: topPadding,
                  left: 0, right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs),
                    child: Row(
                      children: [
                        const _BrandMark(size: 18),
                        const SizedBox(width: AppTheme.spaceXs),
                        Text(
                          'GreenGains',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: AppFontWeights.medium,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),


            // ── 1. Status chip (intrinsic width, left-aligned) ────────────
            Positioned(
              top: topPadding + AppTheme.spaceXs,
              left: AppTheme.spaceMd,
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  _locationService.isRunning,
                  _locationService.isPaused,
                  _locationService.uploadStatus,
                  _locationService.pendingReadings,
                ]),
                builder: (context, _) {
                  final svc = _locationService;
                  final isRunning = svc.isRunning.value;
                  final isPaused  = svc.isPaused.value;
                  // Hide chip when fully idle — design only shows it when tracking/paused
                  if (!isRunning && !isPaused) return const SizedBox.shrink();
                  final status = svc.uploadStatus.value;
                  return TrackingStatusChip(
                    isTracking: isRunning && !isPaused,
                    isPaused: isRunning && isPaused,
                    lastUpload: status.lastUpload,
                    tileCount: _claimedTileCount,
                    isUploading: status.isUploading,
                    activeSensorCount: 0,
                    pendingReadings: svc.pendingReadings.value,
                    onTap: _openSensorSheet,
                  );
                },
              ),
            ),

            // ── 1b. Zone count pill — bottom-left, hidden when actively tracking ──
            if (_h3Tiles.isNotEmpty)
              ListenableBuilder(
                listenable: Listenable.merge([_locationService.isRunning, _locationService.isPaused]),
                builder: (context, _) {
                  final isActive = _locationService.isRunning.value && !_locationService.isPaused.value;
                  if (isActive) return const SizedBox.shrink();
                  return Positioned(
                left: AppTheme.spaceMd,
                bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceLg +
                    _kLocationBtnSize + AppTheme.spaceSm,
                child: _ZoneCountPill(
                    count: _claimedTileCount,
                    sessionNew: _sessionStartZoneCount > 0
                        ? (_claimedTileCount - _sessionStartZoneCount).clamp(0, 999)
                        : _zonesGainedSinceLastOpen,
                    onTap: widget.onGoToStats,
                    neighborhood: _prefs.territoryLabel,
                    communityCount: _globalTiles.length,
                  ),
              );
                },
              ),

            // ── 2. FAB (center-bottom, above floating nav bar) ───────────
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceLg,
              child: Center(
                child: Semantics(
                  button: true,
                  label: context.l10n.semanticsToggleTracking,
                  child: const TrackingFab(),
                ),
              ),
            ),

            // ── 3. My Location button (bottom-left) ───────────────────────
            ValueListenableBuilder<LatLng?>(
              valueListenable: _userLocationNotifier,
              builder: (context, userLocation, _) {
                if (userLocation == null) return const SizedBox.shrink();
                return Positioned(
                  left: AppTheme.spaceMd,
                  bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceLg,
                  child: Semantics(
                    button: true,
                    label: context.l10n.semanticsCenterOnMe,
                    child: _MyLocationButton(
                      onPressed: () => _recenterTrigger.value++,
                      followModeNotifier: _followModeNotifier,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Private widgets ────────────────────────────────────────────────────────

/// Return hint — shown when user has zones but isn't tracking.
/// Shows zone count + last session delta + time ago (or max cluster). Passive, no CTA.
/// Idle hint pill — gentle breathing pulse so it feels alive, not dead.
class _IdleHintPill extends StatefulWidget {
  const _IdleHintPill({required this.hasTiles});
  final bool hasTiles;
  @override
  State<_IdleHintPill> createState() => _IdleHintPillState();
}

class _IdleHintPillState extends State<_IdleHintPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(begin: 0.65, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd,
              vertical: AppTheme.spaceXs,
            ),
            decoration: BoxDecoration(
              color: const Color(0xD9111927),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              context.l10n.chipTapStart,
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFontWeights.medium,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: -0.05,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Passive summary — shown below idle pill when user has zones.
/// "+X zones since last time" or just "X zones on your map" if no delta.
class _PassiveSummaryLine extends StatelessWidget {
  const _PassiveSummaryLine({
    required this.currentZones,
    required this.lastKnownZones,
    required this.lastSessionAt,
  });
  final int currentZones;
  final int lastKnownZones;
  final DateTime? lastSessionAt;

  @override
  Widget build(BuildContext context) {
    final gained = currentZones - lastKnownZones;
    final l10n = context.l10n;
    final text = gained > 0
        ? l10n.homeSinceLastSession(gained)
        : l10n.homeZonesOnYourMap(currentZones);

    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: Colors.white.withValues(alpha: 0.5),
        fontWeight: AppFontWeights.medium,
        letterSpacing: -0.1,
      ),
    );
  }
}

/// Single line of live conditions shown below the tracking hint pill.
/// Icon + label per sensor — colored icons make each word legible without text labels.
class _LiveConditionsLine extends StatelessWidget {
  const _LiveConditionsLine({required this.conditionsNotifier});
  final ValueNotifier<({int? lux, double? hpa, double? rms})> conditionsNotifier;

  static String _luxLabel(int lux, AppLocalizations l10n) {
    if (lux < 50) return l10n.sensorLuxDark;
    if (lux < 500) return l10n.sensorLuxIndoor;
    if (lux < 10000) return l10n.sensorLuxBright;
    return l10n.sensorLuxDirect;
  }

  static String _hpaLabel(double hpa, AppLocalizations l10n) {
    if (hpa > 1010) return l10n.sensorHpaLow;
    if (hpa > 990) return l10n.sensorHpaMid;
    return l10n.sensorHpaHigh;
  }

  static String _rmsLabel(double rms, AppLocalizations l10n) {
    if (rms < 10.5) return l10n.sensorMovementLow;
    if (rms < 11.5) return l10n.sensorMovementMid;
    return l10n.sensorMovementHigh;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder(
      valueListenable: conditionsNotifier,
      builder: (_, snap, __) {
        final chips = <({IconData icon, Color color, String label})>[
          if (snap.lux != null)
            (icon: Icons.light_mode_outlined, color: AppColors.light, label: _luxLabel(snap.lux!, l10n)),
          if (snap.hpa != null)
            (icon: Icons.compress_outlined, color: AppColors.pressure, label: _hpaLabel(snap.hpa!, l10n)),
          if (snap.rms != null)
            (icon: Icons.vibration_outlined, color: AppColors.movement, label: _rmsLabel(snap.rms!, l10n)),
        ];
        if (chips.isEmpty) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(width: 6),
                Text('·', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
                const SizedBox(width: 6),
              ],
              Icon(chips[i].icon, size: 11, color: chips[i].color.withValues(alpha: 0.85)),
              const SizedBox(width: 3),
              Text(
                chips[i].label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: AppFontWeights.medium,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Flat-top hex brand mark — matches design's SVG exactly.
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.9),
      painter: _BrandMarkPainter(),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      ui.Path()
        ..moveTo(w * 5 / 20, h * 1 / 18)
        ..lineTo(w * 15 / 20, h * 1 / 18)
        ..lineTo(w, h * 9 / 18)
        ..lineTo(w * 15 / 20, h * 17 / 18)
        ..lineTo(w * 5 / 20, h * 17 / 18)
        ..lineTo(0, h * 9 / 18)
        ..close(),
      Paint()..color = AppColors.primary,
    );
    canvas.drawPath(
      ui.Path()
        ..moveTo(w * 7 / 20, h * 5 / 18)
        ..lineTo(w * 13 / 20, h * 5 / 18)
        ..lineTo(w * 16 / 20, h * 9 / 18)
        ..lineTo(w * 13 / 20, h * 13 / 18)
        ..lineTo(w * 7 / 20, h * 13 / 18)
        ..lineTo(w * 4 / 20, h * 9 / 18)
        ..close(),
      Paint()..color = const Color(0xFF0F1A1E),
    );
  }

  @override
  bool shouldRepaint(_BrandMarkPainter old) => false;
}


/// Coverage card shown bottom-left when idle — matches design's "Your map" card.
/// Shows zone count prominently, session delta if tracking, neighborhood context.
class _ZoneCountPill extends StatefulWidget {
  const _ZoneCountPill({
    required this.count,
    this.sessionNew = 0,
    this.onTap,
    this.neighborhood,
    this.communityCount = 0,
  });
  final int count;
  final int sessionNew;
  final VoidCallback? onTap;
  final String? neighborhood;
  final int communityCount;

  @override
  State<_ZoneCountPill> createState() => _ZoneCountPillState();
}

class _ZoneCountPillState extends State<_ZoneCountPill> {
  late int _fromCount;

  @override
  void initState() {
    super.initState();
    _fromCount = widget.count;
  }

  @override
  void didUpdateWidget(_ZoneCountPill old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _fromCount = old.count;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pct = widget.communityCount > 0
        ? (widget.count / widget.communityCount * 100).clamp(0.0, 100.0)
        : 0.0;
    final pctStr = pct > 0
        ? l10n.homeCityPct(pct.toStringAsFixed(pct < 1 ? 1 : 0))
        : null;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xD9111927),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.neighborhood != null
                    ? widget.neighborhood!.toUpperCase()
                    : l10n.homeYourMap,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: AppFontWeights.semibold,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 0.6,
                ),
              ),
              if (widget.onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 12,
                    color: Colors.white.withValues(alpha: 0.3)),
              ],
            ],
          ),
          const SizedBox(height: AppTheme.spaceXxxs + 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Animated counter — rolls up from previous value when zones increase.
              // 400ms ease-out matches the "number slot machine" feel Duolingo uses.
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: _fromCount, end: widget.count),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (_, value, __) => Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: AppFontWeights.semibold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceXxs + 1),
              Text(
                l10n.chipZones,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              if (widget.sessionNew > 0) ...[
                const SizedBox(width: AppTheme.spaceSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceXxs + 2,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAlpha(0.18),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    '+${widget.sessionNew}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: AppFontWeights.semibold,
                      color: AppColors.primary,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (pctStr != null) ...[
            const SizedBox(height: AppTheme.spaceXxs),
            Text(
              pctStr,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ],
        ],
      ),
    ),
      ),
    );

    if (widget.onTap == null) return card;
    return Semantics(
      button: true,
      label: '${widget.count} zones — view stats',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap!();
        },
        child: card,
      ),
    );
  }
}

/// My Location button — standard map UX (Google Maps / Waze / Apple Maps pattern).
/// 48×48 circular dark button.
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
        return Material(
          color: isFollowing
              ? AppColors.primary.withValues(alpha: 0.85)
              : AppColors.shadowDark(0.65),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onPressed();
            },
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: _kLocationBtnSize,
              height: _kLocationBtnSize,
              child: Icon(
                isFollowing ? Icons.gps_fixed : Icons.gps_not_fixed,
                color: Colors.white,
                size: AppIconSizes.sm,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// First-start celebration sheet — shown exactly once, the first time tracking starts.
/// Auto-dismisses after 3 s so it never blocks the map.
class _FirstStartSheet extends StatefulWidget {
  @override
  State<_FirstStartSheet> createState() => _FirstStartSheetState();
}

class _FirstStartSheetState extends State<_FirstStartSheet> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceLg,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sensors, color: AppColors.primary, size: AppIconSizes.md),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.firstStartTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: AppFontWeights.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXxxs),
                    Text(
                      l10n.firstStartBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(isDark),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Milestone celebration sheet — shown when user hits 5/10/25/50/100/250/500 zones.
/// Validates their contribution with a trophy moment, then auto-dismisses on CTA.
class _MilestoneSheet extends StatelessWidget {
  const _MilestoneSheet({required this.zoneCount});
  final int zoneCount;

  static const _kMilestones = [5, 10, 25, 50, 100, 250, 500, 1000];
  int? get _next {
    for (final m in _kMilestones) { if (m > zoneCount) return m; }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final next = _next;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary(isDark).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.map_outlined, color: AppColors.primary, size: AppIconSizes.lg),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                l10n.milestoneReachedTitle(zoneCount),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: AppFontWeights.bold,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                l10n.milestoneReachedBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(isDark),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (next != null) ...[
                const SizedBox(height: AppTheme.spaceMd),
                Divider(color: AppColors.divider(isDark), height: 1),
                const SizedBox(height: AppTheme.spaceMd),
                _NextMilestoneBar(current: zoneCount, target: next, isDark: isDark),
              ],
              const SizedBox(height: AppTheme.spaceXl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.milestoneReachedCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First-upload celebration sheet — shown exactly once when the user's first
/// zone appears on the map.
class _FirstUploadSheet extends StatelessWidget {
  const _FirstUploadSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 32, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              const _CelebrationHex(),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                context.l10n.firstUploadBadge,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: AppFontWeights.semibold,
                  color: AppColors.primary,
                  letterSpacing: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                context.l10n.firstUploadHeadline,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: AppFontWeights.semibold,
                  color: Color(0xF5FFFFFF),
                  letterSpacing: -0.6,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                context.l10n.firstUploadSubtext,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              // Proof row
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.firstUploadSensorsLabel, style: TextStyle(
                          fontSize: 10, fontWeight: AppFontWeights.semibold,
                          color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(context.l10n.firstUploadSensorsValue, style: const TextStyle(
                          fontSize: 12, color: Color(0xD9FFFFFF))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(context.l10n.firstUploadPrivacyLabel, style: TextStyle(
                          fontSize: 10, fontWeight: AppFontWeights.semibold,
                          color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(context.l10n.firstUploadPrivacyValue, style: const TextStyle(
                          fontSize: 12, color: AppColors.primary, fontWeight: AppFontWeights.semibold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                      child: Text(context.l10n.firstUploadKeepMappingCta),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated concentric hex rings — shown in the first-upload celebration sheet.
class _CelebrationHex extends StatefulWidget {
  const _CelebrationHex();
  @override
  State<_CelebrationHex> createState() => _CelebrationHexState();
}

class _CelebrationHexState extends State<_CelebrationHex>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) => CustomPaint(
        size: const Size(140, 128),
        painter: _CelebrationHexPainter(_progress.value),
      ),
    );
  }
}

class _CelebrationHexPainter extends CustomPainter {
  const _CelebrationHexPainter(this.t);
  final double t;

  static const _maxRings = 3;

  // Flat-top hex path centered at (cx, cy) with given radius
  ui.Path _hexPath(double cx, double cy, double r) {
    final path = ui.Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * 3.14159 / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    path.close();
    return path;
  }

  // Axial to pixel (flat-top)
  (double, double) _hexToPixel(int q, int r, double size, double cx, double cy) {
    final x = size * (3 / 2 * q);
    final y = size * (math.sqrt(3) / 2 * q + math.sqrt(3) * r);
    return (cx + x, cy + y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const hexR = 16.0;

    // Generate hex ring cells
    final cells = <(int, int, int)>[]; // q, r, dist
    cells.add((0, 0, 0));
    for (int ring = 1; ring <= _maxRings; ring++) {
      int q = ring, r = -ring;
      for (int dir = 0; dir < 6; dir++) {
        for (int step = 0; step < ring; step++) {
          cells.add((q, r, ring));
          const dq = [0, -1, -1, 0, 1, 1];
          const dr = [1, 1, 0, -1, -1, 0];
          q += dq[dir]; r += dr[dir];
        }
      }
    }

    for (final (q, r, dist) in cells) {
      final revealAt = dist / (_maxRings + 1);
      final opacity = ((t - revealAt) / 0.3).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final (px, py) = _hexToPixel(q, r, hexR * 1.15, cx, cy);
      final path = _hexPath(px, py, hexR * 0.92);

      if (dist == 0) {
        canvas.drawPath(path, Paint()
          ..color = AppColors.primary.withValues(alpha: opacity)
          ..style = PaintingStyle.fill);
        canvas.drawPath(path, Paint()
          ..color = AppColors.primary.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        canvas.drawPath(path, Paint()
          ..color = AppColors.primary.withValues(alpha: 0.35 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
      }
    }
  }

  @override
  bool shouldRepaint(_CelebrationHexPainter old) => old.t != t;
}

/// Bottom sheet showing live sensor readings.
/// Opened when user taps the status chip — progressive disclosure pattern.
class _SensorLiveSheet extends StatelessWidget {
  const _SensorLiveSheet({required this.locationService});
  final ForegroundLocationService locationService;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg)),
            border: Border.all(color: AppColors.border(isDark)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      vertical: AppTheme.spaceSm),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary(isDark)
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, 0,
                    AppTheme.spaceMd, AppTheme.spaceSm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.sensorLiveSheetTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: AppFontWeights.semibold,
                        ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: AppTheme.spaceMd,
                    right: AppTheme.spaceMd,
                    bottom: MediaQuery.paddingOf(context).bottom +
                        AppTheme.spaceMd,
                  ),
                  children: [
                    SensorSection(locationService: locationService),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Live sensor ticker ────────────────────────────────────────────────────────

/// Live sensor panel — bar charts for light, motion, and pressure.
// ─── Tracking hint pill — top-center during active session ──────────────────
class _TrackingHintPill extends StatefulWidget {
  const _TrackingHintPill({required this.newZones, required this.sessionStart});
  final int newZones;
  final DateTime sessionStart;

  @override
  State<_TrackingHintPill> createState() => _TrackingHintPillState();
}

class _TrackingHintPillState extends State<_TrackingHintPill> {
  @override
  Widget build(BuildContext context) {
    final label = context.l10n.homeSessionZones(widget.newZones);
    final hasZones = widget.newZones > 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceXs - 1,
          ),
          decoration: BoxDecoration(
            color: hasZones
                ? AppColors.primary.withValues(alpha: 0.18)
                : const Color(0xB2111927),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: hasZones
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: AppFontWeights.semibold,
                  color: hasZones ? AppColors.primary : Colors.white60,
                  letterSpacing: -0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Live sensor ticker — 3-column bar chart panel ──────────────────────────
class _LiveDataTicker extends StatefulWidget {
  const _LiveDataTicker();
  @override
  State<_LiveDataTicker> createState() => _LiveDataTickerState();
}

class _LiveDataTickerState extends State<_LiveDataTicker> {
  final _svc = ForegroundLocationService.instance;
  final List<StreamSubscription<dynamic>> _subs = [];

  static const _kMaxBars = 12;

  final _lightRaw    = <double>[];
  final _motionRaw   = <double>[];
  final _pressureRaw = <double>[];

  LightData?         _light;
  PressureData?      _pressure;
  AccelerometerData? _accel;

  void _push(List<double> buf, double val) {
    buf.add(val);
    if (buf.length > _kMaxBars) buf.removeAt(0);
  }

  @override
  void initState() {
    super.initState();
    _light    = _svc.lastLight;
    _pressure = _svc.lastPressure;
    _accel    = _svc.lastAccelerometer;
    if (_light    != null) _push(_lightRaw,    _light!.lux);
    if (_pressure != null) _push(_pressureRaw, _pressure!.hPa);
    if (_accel    != null) _push(_motionRaw,   _accel!.magnitude);

    _subs.add(_svc.lightStream.listen((d) {
      if (!mounted) return;
      setState(() { _light = d; _push(_lightRaw, d.lux); });
    }));
    _subs.add(_svc.pressureStream.listen((d) {
      if (!mounted) return;
      setState(() { _pressure = d; _push(_pressureRaw, d.hPa); });
    }));
    _subs.add(_svc.accelerometerStream.listen((d) {
      if (!mounted) return;
      setState(() { _accel = d; _push(_motionRaw, d.magnitude); });
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) { s.cancel(); }
    super.dispose();
  }

  String _luxLabel(double lux) {
    if (lux >= 10000) return '${(lux / 1000).toStringAsFixed(0)}k lx';
    if (lux >= 1000)  return '${(lux / 1000).toStringAsFixed(1)}k lx';
    return '${lux.toStringAsFixed(0)} lx';
  }

  @override
  Widget build(BuildContext context) {
    if (_light == null && _pressure == null && _accel == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMd, AppTheme.spaceSm, AppTheme.spaceMd, AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCC111927),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.liveSensorsHeader,
            style: TextStyle(
              fontSize: 10,
              fontWeight: AppFontWeights.semibold,
              color: Colors.white.withValues(alpha: 0.45),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXs + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SensorBarColumn(
                  label: context.l10n.sensorLight,
                  value: _light != null ? _luxLabel(_light!.lux) : '--',
                  color: AppColors.light,
                  rawHistory: _lightRaw,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SensorBarColumn(
                  label: context.l10n.liveSensorMotionLabel,
                  value: _accel != null
                      ? '${_accel!.magnitude.toStringAsFixed(2)} m/s\u00B2'
                      : '--',
                  color: AppColors.movement,
                  rawHistory: _motionRaw,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SensorBarColumn(
                  label: context.l10n.liveSensorPressureLabel,
                  value: _pressure != null
                      ? '${_pressure!.hPa.toStringAsFixed(0)} hPa'
                      : '--',
                  color: AppColors.pressure,
                  rawHistory: _pressureRaw,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorBarColumn extends StatelessWidget {
  const _SensorBarColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.rawHistory,
  });

  final String       label;
  final String       value;
  final Color        color;
  final List<double> rawHistory;

  static const _kBarCount = 12;
  static const _kBarGap   = 1.5;
  static const _kBarMaxH  = 18.0;
  static const _kBarMinH  = 2.0;

  @override
  Widget build(BuildContext context) {
    final minVal = rawHistory.isEmpty ? 0.0 : rawHistory.reduce((a, b) => a < b ? a : b);
    final maxVal = rawHistory.isEmpty ? 1.0 : rawHistory.reduce((a, b) => a > b ? a : b);
    final range  = (maxVal - minVal).clamp(0.001, double.infinity);

    final padded = List<double>.filled(_kBarCount, minVal)
      ..setRange(
        _kBarCount - rawHistory.length.clamp(0, _kBarCount),
        _kBarCount,
        rawHistory.length > _kBarCount
            ? rawHistory.sublist(rawHistory.length - _kBarCount)
            : rawHistory,
      );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: AppFontWeights.medium,
                color: Colors.white.withValues(alpha: 0.65),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(builder: (_, constraints) {
          final barW = (constraints.maxWidth - (_kBarCount - 1) * _kBarGap) / _kBarCount;
          return SizedBox(
            height: _kBarMaxH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < _kBarCount; i++) ...[
                  if (i > 0) SizedBox(width: _kBarGap),
                  Container(
                    width: barW,
                    height: _kBarMinH + ((padded[i] - minVal) / range) * (_kBarMaxH - _kBarMinH),
                    decoration: BoxDecoration(
                      color: color.withValues(
                        alpha: 0.35 + (i / (_kBarCount - 1)) * 0.55,
                      ),
                      borderRadius: BorderRadius.circular(0.5),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: AppTheme.spaceXxs),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: AppFontWeights.semibold,
            color: Colors.white.withValues(alpha: 0.92),
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

/// One sensor column: spark bars + label + current value.

// ─── Next milestone progress bar ─────────────────────────────────────────────

/// Thin progress bar + label showing how close the user is to their next zone milestone.
/// Used in session summary and milestone sheets — the forward pull that brings them back.
class _NextMilestoneBar extends StatelessWidget {
  const _NextMilestoneBar({
    required this.current,
    required this.target,
    required this.isDark,
  });
  final int current;
  final int target;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prev = _prevMilestone(target);
    final progress = ((current - prev) / (target - prev)).clamp(0.0, 1.0);
    final remaining = target - current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.statsMilestoneLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFontWeights.semibold,
                letterSpacing: 0.8,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            Text(
              l10n.statsMilestoneTarget(target),
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFontWeights.semibold,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXxs + 1),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMin),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: AppColors.divider(isDark),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: AppTheme.spaceXxxs),
        Text(
          l10n.statsMilestoneRemaining(remaining),
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary(isDark),
          ),
        ),
      ],
    );
  }

  static int _prevMilestone(int target) {
    const milestones = [0, 5, 10, 25, 50, 100, 250, 500, 1000];
    for (int i = milestones.length - 1; i >= 0; i--) {
      if (milestones[i] < target) return milestones[i];
    }
    return 0;
  }
}

// ─── Session summary sheet ───────────────────────────────────────────────────

/// Shown after tracking stops when the user claimed new zones this session.
/// The payoff moment — "here's what you built."
class _SessionSummarySheet extends StatefulWidget {
  const _SessionSummarySheet({
    required this.zonesGained,
    required this.totalZones,
    this.sessionDuration = Duration.zero,
    this.onViewStats,
  });

  final int zonesGained;
  final int totalZones;
  final Duration sessionDuration;
  final VoidCallback? onViewStats;

  @override
  State<_SessionSummarySheet> createState() => _SessionSummarySheetState();
}

class _SessionSummarySheetState extends State<_SessionSummarySheet> {
  static const _kMilestones = [5, 10, 25, 50, 100, 250, 500, 1000];

  int? _nextMilestone() {
    for (final m in _kMilestones) {
      if (m > widget.totalZones) return m;
    }
    return null;
  }

  Future<void> _share(AppLocalizations l10n, String km2Display) async {
    final text = l10n.sessionSummaryShareText(
      widget.zonesGained, widget.totalZones, km2Display,
    );
    HapticFeedback.lightImpact();
    await SharePlus.instance.share(ShareParams(text: text));
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtDate() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}·${now.day.toString().padLeft(2, '0')}·${now.year.toString().substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final km2 = widget.totalZones * 0.1053;
    final km2Display = km2 < 1.0 ? km2.toStringAsFixed(2) : km2.toStringAsFixed(1);
    final next = _nextMilestone();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.sessionSummaryBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: AppFontWeights.semibold,
                      color: Colors.white.withValues(alpha: 0.45),
                      letterSpacing: 1.2,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, size: 18,
                        color: AppColors.textSecondary(isDark)),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── Hero ─────────────────────────────────────────────────────
              Text(
                l10n.sessionSummaryZonesGainedLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: AppFontWeights.semibold,
                  color: AppColors.primary,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '+${widget.zonesGained}',
                style: const TextStyle(
                  fontSize: 108,
                  fontWeight: AppFontWeights.bold,
                  color: Colors.white,
                  letterSpacing: -5,
                  height: 0.92,
                  fontFeatures: [ui.FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                l10n.sessionSummarySubline,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: -0.1,
                ),
              ),

              // ── 3-stat row ───────────────────────────────────────────────
              const SizedBox(height: AppTheme.spaceMd),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _SummaryStatCell(label: l10n.sessionStatArea, value: '$km2Display km²'),
                    const VerticalDivider(width: 1, thickness: 1, color: Color(0x14FFFFFF)),
                    _SummaryStatCell(label: l10n.sessionStatDuration, value: _fmtDuration(widget.sessionDuration)),
                    const VerticalDivider(width: 1, thickness: 1, color: Color(0x14FFFFFF)),
                    _SummaryStatCell(label: l10n.sessionStatTotal, value: widget.totalZones.toString()),
                  ],
                ),
              ),

              // ── Next milestone ────────────────────────────────────────────
              if (next != null) ...[
                const SizedBox(height: AppTheme.spaceMd),
                _NextMilestoneBar(current: widget.totalZones, target: next, isDark: isDark),
              ],

              // ── Watermark row ─────────────────────────────────────────────
              const SizedBox(height: AppTheme.spaceMd),
              Row(
                children: [
                  const _BrandMark(size: 10),
                  const SizedBox(width: 6),
                  Text(
                    l10n.sessionSummaryWatermark,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: AppFontWeights.medium,
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _fmtDate(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 0.6,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spaceSm),

              // ── Next-session hook — one quiet line, contextual ────────────
              Text(
                widget.zonesGained > 0
                    ? l10n.sessionSummaryNextHook
                    : l10n.sessionSummaryNextHookEmpty,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.38),
                  letterSpacing: -0.1,
                ),
              ),

              const SizedBox(height: AppTheme.spaceMd),

              // ── CTA buttons ───────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _share(l10n, km2Display),
                      icon: const Icon(Icons.ios_share, size: 16),
                      label: Text(l10n.sessionSummaryShareCta),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onViewStats?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                      ),
                      child: Icon(Icons.bar_chart, size: 20,
                          color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStatCell extends StatelessWidget {
  const _SummaryStatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spaceSm, horizontal: AppTheme.spaceSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: AppFontWeights.medium,
                color: Color(0x73FFFFFF),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: AppFontWeights.semibold,
                color: Color(0xF5FFFFFF),
                letterSpacing: -0.5,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

