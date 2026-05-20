import 'dart:async';
import 'dart:convert';
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
import '../widgets/press_scale_detector.dart';
import '../widgets/sensor_section.dart';
import '../data/repositories/contribution_repository.dart';

// My Location button: 48×48 standard touch target.
const _kLocationBtnSize = AppTheme.minTouchTarget; // 48

const _kMilestones = [5, 10, 25, 50, 100, 250, 500, 1000];

// H3 resolution for live cell highlight (res 9 ≈ 174m edge length — city block scale)
const _kLiveCellResolution = 9;

/// Home screen — full-screen map layout.
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
  final _h3 = const h3f.H3Factory().load();
  late final _userLocationNotifier = ValueNotifier<LatLng?>(_cachedLocation());
  /// Incrementing recenter triggers CoverageMapWidget to move camera to user.
  final _recenterTrigger = ValueNotifier<int>(0);

  bool _batteryPromptOpen = false;
  bool _permissionLost = false;
  StreamSubscription<UploadSuccessEvent>? _uploadSuccessSub;
  /// Zone count at the moment tracking started (this foreground session).
  /// 0 = tracking was already running when app opened — no delta shown.
  int _sessionStartZoneCount = 0;
  /// Wall-clock time when tracking started — drives elapsed timer in hint pill.
  DateTime? _sessionStartTime;
  /// Zones gained since last app open — shown as re-engagement banner after tile load.
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

  /// Boundary of the H3 cell the user is currently inside — shown as live amber
  /// highlight on the map while tracking is active.
  List<LatLng>? _currentH3Boundary;
  /// Last committed H3 cell index — the one currently rendered on the map.
  BigInt? _currentH3Index;
  /// Cells visited this session — shown as optimistic pending tiles before backend confirms.
  final Set<BigInt> _sessionVisitedCells = {};
  List<List<LatLng>> _pendingCellBoundaries = [];
  /// Candidate cell waiting for stability confirmation.
  BigInt? _pendingH3Index;
  /// How many consecutive GPS readings have landed in [_pendingH3Index].
  int _pendingH3Count = 0;
  /// Minimum consecutive hits before committing a new live cell.
  /// At 10s GPS interval: 3 hits = ~30s — prevents H3 cell drift from low-accuracy
  /// fixes leaking into the live map. Accuracy filter in ForegroundService now rejects
  /// >50m reads, so stable 3-hit confirmation eliminates the last ~5% drift cases.
  static const _kLiveCellStabilityThreshold = 3;
  /// Cached tile count — avoids recomputing on every build frame.
  int get _claimedTileCount => _h3Tiles.where((t) => t.boundary != null).length;
  /// Current streak — loaded after session ends, shown in session summary sheet.
  int _currentStreak = 0;
  /// Upload count during the current tracking session — shown in the live pill and summary sheet.
  int _sessionUploadCount = 0;
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
    _loadReturnDelta();
    _maybeShowPendingFirstUpload();
  }

  void _maybeShowPendingFirstUpload() {
    if (!_prefs.firstUploadPending) return;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || !context.mounted) return;
      _showFirstUploadSheet();
    });
  }

  void _loadReturnDelta() {
    final zones = _prefs.lastSessionZonesGained;
    final endAt = _prefs.lastSessionEndAt;
    if (zones <= 0 || endAt == null) return;
    // Only show if last session ended more than 10 min ago (not an immediate re-open
    // after the session summary was already shown) but less than 24h ago.
    final age = DateTime.now().difference(endAt);
    if (age < const Duration(minutes: 10) || age > const Duration(hours: 24)) return;
    // return-delta removed from UI — no-op
  }

  Future<void> _loadStreak() async {
    try {
      final stats = await ContributionRepository().getStats();
      if (!mounted) return;
      final next = stats.currentStreak;
      await _prefs.setLastKnownStreak(next);
      setState(() { _currentStreak = next; });
    } catch (_) {}
  }

  void _handleServiceRunningChange() {
    if (_locationService.isRunning.value) {
      _sessionStartZoneCount = _claimedTileCount;
      _sessionStartTime = DateTime.now();
      _sessionUploadCount = 0;
      _sessionVisitedCells.clear();
      _pendingCellBoundaries = [];
      _checkBatteryOptimization();
      _maybeShowFirstStart();
    } else {
      // Tracking stopped — persist session data for return hint.
      final gained = _claimedTileCount - _sessionStartZoneCount;
      final sessionDuration = _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!)
          : Duration.zero;
      final clampedGained = gained.clamp(0, 9999);
      final isPersonalBest = clampedGained > 0 && clampedGained > _prefs.bestSessionZonesGained;
      unawaited(_prefs.saveLastSession(zonesGained: clampedGained));
      // Show summary for any session ≥2 min, regardless of whether zones were gained.
      final worthSummary = sessionDuration >= const Duration(minutes: 2);
      if (worthSummary && _sessionStartZoneCount >= 0 && mounted) {
        final total = _claimedTileCount;
        final uploads = _sessionUploadCount;
        Future.delayed(AppDurations.fast, () {
          if (!mounted || !context.mounted) return;
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => _SessionSummarySheet(
              zonesGained: clampedGained,
              totalZones: total,
              sessionDuration: sessionDuration,
              streak: _currentStreak,
              isPersonalBest: isPersonalBest,
              uploadsInSession: uploads,
              onViewStats: widget.onGoToStats,
            ),
          );
        });
      }
      _sessionStartZoneCount = 0;
      _sessionStartTime = null;
      _sessionUploadCount = 0;
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

  // ── Bottom action bar controls ──────────────────────────────────────────────

  bool _actionBusy = false;

  Future<bool> _requestAndCheckPermission() async {
    final current = await Geolocator.checkPermission();
    if (current == LocationPermission.deniedForever) {
      if (mounted) AppSnackbars.showInfo(context, context.l10n.permissionLocationMessage);
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

  void _showFirstUploadSheet() {
    unawaited(_prefs.setFirstUploadCelebrated());
    unawaited(_prefs.setFirstUploadPending(false));
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FirstUploadSheet(),
    );
  }

  void _onUploadSuccess(UploadSuccessEvent event) {
    if (!mounted) return;
    if (_locationService.isRunning.value) {
      setState(() => _sessionUploadCount++);
    }
    // Mark pending immediately — if the app goes to background before the sheet
    // shows, the resumed check in didChangeAppLifecycleState will pick it up.
    if (!_prefs.firstUploadCelebrated) {
      unawaited(_prefs.setFirstUploadPending(true));
    }
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
        if (!_prefs.firstUploadCelebrated && newCount > 0) {
          _showFirstUploadSheet();
          return;
        }
        final msg = gained > 0
            ? context.l10n.uploadSuccessNewZone(newCount)
            : context.l10n.uploadSuccessMessage;
        AppSnackbars.showSuccess(context, msg);
        if (gained > 0) {
          _maybeCelebrateMilestone(newCount);
        }
      });
    });
    _maybeRequestReview();
    unawaited(_maybeCelebrateUploadMilestone());
  }

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
    HapticFeedback.heavyImpact();
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
      unawaited(_checkPermissionHealth());
      _maybeShowPendingFirstUpload();
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
        await _prefs.setLastKnownZoneCount(newCount);
        _h3RetryCount = 0;
        _slowLoadTimer?.cancel();
        setState(() {
          _h3Tiles = response.tiles;
          _h3TilesLoading = false;
          _showSlowLoadHint = false;
          _lastTilesFetch = DateTime.now();
        });
        // Persist for instant display on next open.
        unawaited(_prefs.setCachedPersonalTiles(jsonEncode(data)));
        // Geocode neighborhood from the most-sampled tile centroid — fire-and-forget.
        // Only runs once (or when name is missing). Sends H3 cell centroid (~461m),
        // not the user's actual GPS position.
        if (_prefs.territoryLabel == null && response.tiles.isNotEmpty) {
          unawaited(_refreshNeighborhoodName(response.tiles));
        }
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
                  tiles: [...(_showCommunity ? _globalTiles : <H3Tile>[]), ..._h3Tiles],
                  userLocation: _userLocationNotifier.value,
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

            // ── 0b. Cold-start hint — shown after 8s if still loading ───
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
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      context.l10n.serverWakingUp,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: AppTheme.fontSizeBody,
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Overlays ──────────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.floatingNavHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // Top bar: Mine/All left — stats right
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mine / All toggle
                          _MineAllToggle(
                            showCommunity: _showCommunity,
                            onChanged: (val) =>
                                setState(() => _showCommunity = val),
                          ),
                          const Spacer(),
                          // Stats pills stacked top-right — tap navigates to Stats
                          PressScaleDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onGoToStats?.call();
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (_claimedTileCount > 0)
                                  _StatPill(
                                    icon: Icons.place_rounded,
                                    label: context.l10n.homeStatPlaces(_claimedTileCount),
                                  ),
                                if (_currentStreak > 0) ...[
                                  const SizedBox(height: AppTheme.spaceXxs),
                                  _StatPill(
                                    icon: Icons.bolt_rounded,
                                    label: context.l10n.homeStatStreak(_currentStreak),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Live session counter pill
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _locationService.isRunning,
                        _locationService.isPaused,
                      ]),
                      builder: (context, _) {
                        final active = _locationService.isRunning.value && !_locationService.isPaused.value;
                        final show = active && _sessionUploadCount > 0;
                        final zonesGained = (_claimedTileCount - _sessionStartZoneCount).clamp(0, 9999);
                        final l10n = context.l10n;
                        final pillText = zonesGained > 0
                            ? l10n.homeSessionPillWithZones(_sessionUploadCount, zonesGained)
                            : l10n.homeSessionPill(_sessionUploadCount);
                        return AnimatedSwitcher(
                          duration: AppDurations.medium,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                              child: child,
                            ),
                          ),
                          child: show ? Padding(
                            key: ValueKey('$_sessionUploadCount-$zonesGained'),
                            padding: const EdgeInsets.only(bottom: AppTheme.spaceXs),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXxs + 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  pillText,
                                  style: const TextStyle(
                                    fontSize: AppTheme.fontSizeSm,
                                    fontWeight: AppFontWeights.semibold,
                                    color: AppColors.primary,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                            ),
                          ) : const SizedBox.shrink(key: ValueKey('pill_hidden')),
                        );
                      },
                    ),

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

                    // Bottom row — floating buttons, no container
                    Padding(
                      padding: const EdgeInsets.only(
                          left: AppTheme.spaceMd,
                          right: AppTheme.spaceMd,
                          bottom: AppTheme.spaceMd),
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          _locationService.isRunning,
                          _userLocationNotifier,
                        ]),
                        builder: (context, _) {
                          final isRunning = _locationService.isRunning.value;
                          final hasLoc    = _userLocationNotifier.value != null;
                          return Row(
                            children: [
                              _InfoButton(onTap: _openSensorSheet),
                              Expanded(
                                child: Center(
                                  child: _HomeActionBar(
                                    isRunning: isRunning,
                                    isBusy: _actionBusy,
                                    onStart: _actionStart,
                                    onStop: _actionStop,
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

// ─── Constants ───────────────────────────────────────────────────────────────


// ─── Bottom action bar ────────────────────────────────────────────────────────

class _HomeActionBar extends StatelessWidget {
  const _HomeActionBar({
    required this.isRunning,
    required this.isBusy,
    required this.onStart,
    required this.onStop,
  });

  final bool isRunning;
  final bool isBusy;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!isRunning) {
      return _ActionButton.primary(
        label: l10n.homeActionStart,
        icon: Icons.play_arrow_rounded,
        busy: isBusy,
        onPressed: onStart,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton.danger(
          label: l10n.homeActionStop,
          icon: Icons.stop_rounded,
          busy: isBusy,
          onPressed: onStop,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton._({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
    required this.style,
    this.disabled = false,
  });

  factory _ActionButton.primary({required String label, required IconData icon, required bool busy, required VoidCallback onPressed}) =>
      _ActionButton._(label: label, icon: icon, busy: busy, onPressed: onPressed, style: _ActionBtnStyle.primary);
  factory _ActionButton.danger({required String label, required IconData icon, required bool busy, required VoidCallback onPressed, bool disabled = false}) =>
      _ActionButton._(label: label, icon: icon, busy: busy, onPressed: onPressed, style: _ActionBtnStyle.danger, disabled: disabled);

  final String label;
  final IconData icon;
  final bool busy;
  final bool disabled;
  final VoidCallback onPressed;
  final _ActionBtnStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bgColor = switch (style) {
      _ActionBtnStyle.primary   => AppColors.primary,
      _ActionBtnStyle.secondary => AppColors.actionSecondaryBg,
      _ActionBtnStyle.danger    => AppColors.actionDangerBg,
    };
    final fgColor = switch (style) {
      _ActionBtnStyle.primary   => AppColors.actionPrimaryFg,
      _ActionBtnStyle.secondary => Colors.white,
      _ActionBtnStyle.danger    => AppColors.error,
    };
    final borderColor = switch (style) {
      _ActionBtnStyle.primary   => Colors.transparent,
      _ActionBtnStyle.secondary => Colors.white.withValues(alpha: 0.08),
      _ActionBtnStyle.danger    => AppColors.error.withValues(alpha: 0.25),
    };

    return Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (busy || disabled) ? null : onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: Ink(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: style == _ActionBtnStyle.primary
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 3))]
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Padding(
              // Danger button is icon-only (compact) — primary keeps full label
              padding: style == _ActionBtnStyle.danger
                  ? const EdgeInsets.all(AppTheme.spaceSm)
                  : const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd),
              child: busy
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fgColor),
                    )
                  : style == _ActionBtnStyle.danger
                      ? Icon(icon, size: AppIconSizes.sm, color: fgColor)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: AppIconSizes.sm, color: fgColor),
                            const SizedBox(width: AppTheme.spaceSm),
                            Text(
                              label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: fgColor,
                                fontWeight: AppFontWeights.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ActionBtnStyle { primary, secondary, danger }

// ─── Private widgets ────────────────────────────────────────────────────────

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
      Paint()..color = AppColors.darkBackground,
    );
  }

  @override
  bool shouldRepaint(_BrandMarkPainter old) => false;
}


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
class _MilestoneSheet extends StatefulWidget {
  const _MilestoneSheet({required this.zoneCount});
  final int zoneCount;
  @override
  State<_MilestoneSheet> createState() => _MilestoneSheetState();
}

class _MilestoneSheetState extends State<_MilestoneSheet> {
  int? get _next {
    for (final m in _kMilestones) { if (m > widget.zoneCount) return m; }
    return null;
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final next = _next;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
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
                  l10n.milestoneReachedTitle(widget.zoneCount),
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
                  _NextMilestoneBar(current: widget.zoneCount, target: next, isDark: isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First-upload celebration sheet — shown exactly once when the user's first
/// zone appears on the map.
class _FirstUploadSheet extends StatefulWidget {
  const _FirstUploadSheet();
  @override
  State<_FirstUploadSheet> createState() => _FirstUploadSheetState();
}

class _FirstUploadSheetState extends State<_FirstUploadSheet> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

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
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
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
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: AppFontWeights.semibold,
                    color: AppColors.primary,
                    letterSpacing: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  context.l10n.firstUploadHeadline,
                  style: TextStyle(
                    fontSize: AppTheme.spaceXl,
                    fontWeight: AppFontWeights.semibold,
                    color: Colors.white.withValues(alpha: 0.96),
                    letterSpacing: -0.6,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  context.l10n.firstUploadSubtext,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeSm,
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceMd),
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
                            fontSize: AppTheme.fontSizeNavLabel, fontWeight: AppFontWeights.semibold,
                            color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(context.l10n.firstUploadSensorsValue, style: TextStyle(
                            fontSize: AppTheme.fontSizeBody, color: Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(context.l10n.firstUploadPrivacyLabel, style: TextStyle(
                            fontSize: AppTheme.fontSizeNavLabel, fontWeight: AppFontWeights.semibold,
                            color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(context.l10n.firstUploadPrivacyValue, style: const TextStyle(
                            fontSize: AppTheme.fontSizeBody, color: AppColors.primary, fontWeight: AppFontWeights.semibold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  context.l10n.firstUploadKeepMappingCta,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated hex icon — shown in the first-upload celebration sheet.
class _CelebrationHex extends StatelessWidget {
  const _CelebrationHex();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (_, scale, __) => Transform.scale(
        scale: scale,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primaryAlpha(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.hexagon_outlined, color: AppColors.primary, size: AppIconSizes.lg),
        ),
      ),
    );
  }
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
                fontSize: AppTheme.fontSizeBody,
                fontWeight: AppFontWeights.semibold,
                letterSpacing: 0.8,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            Text(
              l10n.statsMilestoneTarget(target),
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: AppFontWeights.semibold,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceTiny),
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
            fontSize: AppTheme.fontSizeBody,
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
    this.streak = 0,
    this.isPersonalBest = false,
    this.uploadsInSession = 0,
    this.onViewStats,
  });

  final int zonesGained;
  final int totalZones;
  final Duration sessionDuration;
  final int streak;
  final bool isPersonalBest;
  final int uploadsInSession;
  final VoidCallback? onViewStats;

  @override
  State<_SessionSummarySheet> createState() => _SessionSummarySheetState();
}

class _SessionSummarySheetState extends State<_SessionSummarySheet> {
  int? _nextMilestone() {
    for (final m in _kMilestones) {
      if (m > widget.totalZones) return m;
    }
    return null;
  }

  /// Returns the milestone hit this session, if any.
  int? _hitMilestone() {
    final prev = widget.totalZones - widget.zonesGained;
    for (final m in _kMilestones) {
      if (prev < m && m <= widget.totalZones) return m;
    }
    return null;
  }

  Future<void> _share(AppLocalizations l10n, String km2Display) async {
    final text = widget.zonesGained > 0
        ? l10n.sessionSummaryShareText(widget.zonesGained, widget.totalZones, km2Display)
        : l10n.sessionSummaryShareTextEmpty(_fmtDuration(widget.sessionDuration), widget.totalZones, km2Display);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _nextHookCopy(AppLocalizations l10n) {
    if (widget.zonesGained == 0) return l10n.sessionSummaryNextHookEmpty;
    if (widget.streak >= 2) return l10n.sessionSummaryNextHookStreak;
    if (widget.streak == 1) return l10n.sessionSummaryNextHookFirst;
    return l10n.sessionSummaryNextHook;
  }

  String _fmtDate() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}·${now.day.toString().padLeft(2, '0')}·${now.year.toString().substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final km2 = widget.totalZones * kKm2PerCell;
    final km2Display = km2 < 1.0 ? km2.toStringAsFixed(2) : km2.toStringAsFixed(1);
    final next = _nextMilestone();
    final hit = _hitMilestone();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: AppFontWeights.semibold,
                      color: Colors.white.withValues(alpha: 0.5),
                      letterSpacing: 0.8,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      child: Icon(Icons.close, size: AppIconSizes.xs,
                          color: AppColors.textSecondary(isDark)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── Hero ─────────────────────────────────────────────────────
              if (widget.zonesGained > 0) ...[
                Text(
                  l10n.sessionSummaryZonesGainedLabel,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: AppFontWeights.semibold,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: widget.zonesGained),
                  duration: Duration(milliseconds: 600 + widget.zonesGained.clamp(0, 60) * 8),
                  curve: Curves.easeOut,
                  builder: (_, value, __) => Text(
                    '+$value',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeDisplay,
                      fontWeight: AppFontWeights.bold,
                      color: Colors.white,
                      letterSpacing: -5,
                      height: 0.92,
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  l10n.sessionSummarySubline,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeMd,
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: -0.1,
                  ),
                ),
              ] else ...[
                Text(
                  l10n.sessionSummaryNoZonesLabel,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: AppFontWeights.semibold,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: widget.totalZones),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  builder: (_, value, __) => Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeDisplay,
                      fontWeight: AppFontWeights.bold,
                      color: Colors.white,
                      letterSpacing: -5,
                      height: 0.92,
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  l10n.sessionSummaryNoZonesSubline,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeMd,
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: -0.1,
                  ),
                ),
              ],

              if (widget.isPersonalBest) ...[
                const SizedBox(height: AppTheme.spaceMd),
                Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: AppIconSizes.xs, color: AppColors.primary),
                    const SizedBox(width: AppTheme.spaceXxs),
                    Text(
                      l10n.sessionPersonalBest,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeSm,
                        fontWeight: AppFontWeights.semibold,
                        color: AppColors.primary,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ],

              // ── Milestone hit banner ──────────────────────────────────────
              if (hit != null) ...[
                const SizedBox(height: AppTheme.spaceMd),
                _MilestoneBanner(milestone: hit, l10n: l10n),
              ],

              // ── 2×2 stat grid ────────────────────────────────────────────
              const SizedBox(height: AppTheme.spaceMd),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _SummaryStatCell(
                      label: l10n.sessionStatArea,
                      value: '$km2Display km²',
                      subValue: l10n.statsCityBlocks((km2 / kKm2PerCityBlock).round()),
                    ),
                    VerticalDivider(width: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.08)),
                    _SummaryStatCell(label: l10n.sessionStatDuration, value: _fmtDuration(widget.sessionDuration)),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.08)),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _SummaryStatCell(label: l10n.sessionStatUploads, value: widget.uploadsInSession.toString()),
                    VerticalDivider(width: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.08)),
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
                      fontSize: AppTheme.fontSizeNavLabel,
                      fontWeight: AppFontWeights.medium,
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _fmtDate(),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeNavLabel,
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 0.6,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spaceSm),

              // ── Next-session hook — contextual, never commanding ──────────
              Text(
                _nextHookCopy(l10n),
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: Colors.white.withValues(alpha: 0.45),
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
                      icon: const Icon(Icons.ios_share, size: AppIconSizes.xs),
                      label: Text(l10n.sessionSummaryShareCta),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, AppTheme.minTouchTarget)),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  SizedBox(
                    width: AppTheme.minTouchTarget,
                    height: AppTheme.minTouchTarget,
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
                      child: Icon(Icons.bar_chart, size: AppIconSizes.sm,
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

/// Glowing banner shown on session summary when user crosses a zone milestone.
class _MilestoneBanner extends StatefulWidget {
  const _MilestoneBanner({required this.milestone, required this.l10n});
  final int milestone;
  final AppLocalizations l10n;

  @override
  State<_MilestoneBanner> createState() => _MilestoneBannerState();
}

class _MilestoneBannerState extends State<_MilestoneBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: _glow.value * 0.6)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: _glow.value * 0.15),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: AppColors.primary, size: 16),
            const SizedBox(width: AppTheme.spaceXs),
            Expanded(
              child: Text(
                widget.l10n.sessionMilestoneHit(widget.milestone),
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeSm,
                  fontWeight: AppFontWeights.semibold,
                  color: AppColors.primary,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Map layer toggle — switches between personal and community coverage tiles.
/// Mine / All segmented pill toggle.
class _MineAllToggle extends StatelessWidget {
  const _MineAllToggle({required this.showCommunity, required this.onChanged});
  final bool showCommunity;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.shadowDark(0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      padding: const EdgeInsets.all(AppTheme.spaceXxxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Seg(label: context.l10n.layerMine, active: !showCommunity,
              onTap: () => onChanged(false)),
          _Seg(label: context.l10n.layerAll, active: showCommunity,
              onTap: () => onChanged(true)),
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceTiny),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontSizeNavLabel,
            fontWeight: active ? AppFontWeights.bold : AppFontWeights.medium,
            color: active ? AppColors.actionSegActiveFg : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Small frosted pill showing a stat (places or streak).
class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceTiny),
      decoration: BoxDecoration(
        color: AppColors.shadowDark(0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSizes.xs, color: AppColors.primary),
          const SizedBox(width: AppTheme.spaceXxs),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeNavLabel,
              fontWeight: AppFontWeights.semibold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}


/// Small circular info button — opens sensor sheet.
class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScaleDetector(
      onTap: onTap,
      child: Container(
        width: _kLocationBtnSize,
        height: _kLocationBtnSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.shadowDark(0.6),
        ),
        child: const Icon(Icons.info_outline_rounded,
            color: Colors.white70, size: AppIconSizes.sm),
      ),
    );
  }
}

/// Persistent banner shown when background location permission was revoked
/// while tracking is supposed to be running. Not dismissable — stays until fixed.
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
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeSm,
                      fontWeight: AppFontWeights.semibold,
                      color: AppColors.warning,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.permissionLostBody,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
              ),
              child: Text(
                l10n.permissionLostCta,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBody,
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

class _SummaryStatCell extends StatelessWidget {
  const _SummaryStatCell({required this.label, required this.value, this.subValue});
  final String label;
  final String value;
  final String? subValue;

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
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: AppFontWeights.medium,
                color: Colors.white.withValues(alpha: 0.45),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: AppTheme.spaceXl,
                fontWeight: AppFontWeights.semibold,
                color: Colors.white.withValues(alpha: 0.96),
                letterSpacing: -0.5,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
            if (subValue != null) ...[
              const SizedBox(height: 2),
              Text(
                subValue!,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeNavLabel,
                  color: Colors.white.withValues(alpha: 0.33),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

