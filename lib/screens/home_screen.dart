import 'dart:async';
import 'package:h3_flutter/h3_flutter.dart' as h3f;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/extensions/context_extensions.dart';
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

// My Location button: 48×48 standard touch target.
const _kLocationBtnSize = AppTheme.minTouchTarget; // 48
// H3 resolution for live cell highlight (res 9 ≈ 174m edge length — city block scale)
const _kLiveCellResolution = 9;
// FAB height — kept in sync with _kFabSize in tracking_fab.dart
const _kFabHeight = 72.0;

/// Home screen — full-screen map layout.
///
/// Layer order (bottom → top):
///   0. CoverageMapWidget (edge-to-edge background)
///   1. Status chip (top overlay)
///   2. Map legend (top-right overlay)
///   3. TrackingFab + MyLocationButton (bottom overlay)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onGoToStats});
  final VoidCallback? onGoToStats;

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
  /// True when map is actively following the user's GPS position.
  final _followModeNotifier = ValueNotifier<bool>(false);
  StreamSubscription? _locationStreamSub;
  List<H3Tile> _h3Tiles = [];
  List<H3Tile> _globalTiles = [];
  bool _h3TilesLoading = true;
  /// Boundary of the H3 cell the user is currently inside — shown as live amber
  /// highlight on the map while tracking is active.
  List<LatLng>? _currentH3Boundary;
  /// Last computed H3 cell index — prevents redundant setState on every GPS ping.
  BigInt? _currentH3Index;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService.isRunning.addListener(_handleServiceRunningChange);
    _checkServiceStatus();
    _setupUploadSuccessListener();
    _checkBatteryOptimization();
    _loadH3Tiles();
    _loadGlobalTiles();
    _loadUserLocation();
    _subscribeToLocationUpdates();
  }

  void _handleServiceRunningChange() {
    if (_locationService.isRunning.value) {
      // Snapshot zone count so we can show "+N new" delta during this session.
      _sessionStartZoneCount = _h3Tiles.where((t) => t.boundary != null).length;
      _checkBatteryOptimization();
      _maybeShowFirstStart();
    } else {
      _sessionStartZoneCount = 0;
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
    final prevCount = _h3Tiles.where((t) => t.boundary != null).length;
    _loadH3Tiles().then((_) {
      if (!mounted) return;
      final newCount = _h3Tiles.where((t) => t.boundary != null).length;
      final gained = newCount - prevCount;
      // First upload ever — show special celebration before regular snackbar.
      if (!_prefs.firstUploadCelebrated && newCount > 0) {
        unawaited(_prefs.setFirstUploadCelebrated());
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => const _FirstUploadSheet(),
        );
        return; // skip generic snackbar — sheet is richer
      }
      final msg = gained > 0
          ? context.l10n.uploadSuccessNewZone(newCount)
          : context.l10n.uploadSuccessMessage;
      HapticFeedback.lightImpact();
      AppSnackbars.showSuccess(context, msg);
      if (gained > 0) {
        _maybeCelebrateMilestone(newCount);
        _maybeFireZoneNotification(gained, newCount);
      }
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

  Future<void> _maybeFireZoneNotification(int gained, int total) async {
    try {
      const platform = MethodChannel('greengains/foreground');
      await platform.invokeMethod('showZoneNotification', {
        'newZones': gained,
        'totalZones': total,
      });
    } catch (_) {}
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
    _locationService.isRunning.removeListener(_handleServiceRunningChange);
    _recenterTrigger.dispose();
    _userLocationNotifier.dispose();
    _followModeNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (_locationService.isRunning.value) {
        await _locationService.flushSensorBuffers();
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

  Future<void> _loadH3Tiles() async {
    // Only show loading spinner on first fetch — reloads update tiles in-place.
    if (_h3Tiles.isEmpty) setState(() => _h3TilesLoading = true);
    try {
      final data = await BackendClient.get(kApiUserTiles);
      final response = UserTilesResponse.fromJson(data);
      debugPrint('Tiles: ${response.tiles.length} personal tiles');
      if (mounted) setState(() { _h3Tiles = response.tiles; _h3TilesLoading = false; });
    } on ApiException catch (e) {
      debugPrint('Tiles: ApiException ${e.statusCode}');
      if (e.isUnauthorized) {
        // Auth race on cold start — retry once after 2s
        await Future.delayed(kRetryDelay401);
        if (mounted) _loadH3Tiles();
        return;
      }
      if (mounted) setState(() => _h3TilesLoading = false);
      await Future.delayed(kRetryDelayNetError);
      if (mounted && _h3Tiles.isEmpty) _loadH3Tiles();
    } catch (e) {
      debugPrint('Failed to load H3 tiles: $e');
      if (mounted) setState(() => _h3TilesLoading = false);
      await Future.delayed(kRetryDelayNetError);
      if (mounted && _h3Tiles.isEmpty) _loadH3Tiles();
    }
  }

  /// Load community coverage tiles (all users, cached 5 min on server).
  /// Loads silently in background — never blocks the loading spinner.
  Future<void> _loadGlobalTiles() async {
    try {
      final data = await BackendClient.get(kApiTilesGlobal);
      final response = GlobalTilesResponse.fromJson(data);
      debugPrint('Global tiles: ${response.tiles.length} community tiles');
      if (mounted) setState(() => _globalTiles = response.tiles);
    } on ApiException catch (e) {
      debugPrint('Global tiles: ApiException ${e.statusCode}');
      if (e.isUnauthorized) {
        await Future.delayed(kRetryDelay401);
        if (mounted && _globalTiles.isEmpty) _loadGlobalTiles();
        return;
      }
      await Future.delayed(kGlobalTileRetryDelay);
      if (mounted && _globalTiles.isEmpty) _loadGlobalTiles();
    } catch (e) {
      debugPrint('Failed to load global tiles: $e');
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
        timeLimit: const Duration(seconds: 5),
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
      // Only recompute boundary + rebuild when the cell actually changes.
      if (cellIndex == _currentH3Index) return;
      _currentH3Index = cellIndex;
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
                  controlsPadding: EdgeInsets.only(
                    top: topPadding,
                    bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceLg,
                  ),
                );
              },
            ),

            // ── 0b. First-use hint — sits just above the FAB row ─────────
            // Positioned is correct here — Center+bottom-padding doesn't work
            // for directional placement (Center ignores directional offsets).
            if (_h3Tiles.isEmpty && !_locationService.isRunning.value)
              Positioned(
                left: AppTheme.spaceLg,
                right: AppTheme.spaceLg,
                bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceLg + 64,
                child: Center(child: _FirstUseHint()),
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
                ]),
                builder: (context, _) {
                  final status = _locationService.uploadStatus.value;
                  // Count sensor types that have recent data (non-null)
                  final svc = _locationService;
                  final activeSensors = [
                    svc.lastLight,
                    svc.lastAccelerometer,
                    svc.lastPressure,
                    svc.lastGyroscope,
                    svc.lastMagneticField,
                  ].where((s) => s != null).length;
                  return TrackingStatusChip(
                    isTracking: svc.isRunning.value && !svc.isPaused.value,
                    isPaused: svc.isRunning.value && svc.isPaused.value,
                    lastUpload: status.lastUpload,
                    tileCount: _h3Tiles.where((t) => t.boundary != null).length,
                    isUploading: status.isUploading,
                    activeSensorCount: activeSensors,
                    onTap: _openSensorSheet,
                  );
                },
              ),
            ),

            // ── 1b. Zone count pill — stacked above the location button ─────
            // bottom = nav row + location button height + a gap
            if (_h3Tiles.isNotEmpty)
              Positioned(
                left: AppTheme.spaceMd,
                right: AppTheme.spaceMd,
                bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceLg +
                    _kLocationBtnSize + AppTheme.spaceSm,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ZoneCountPill(
                    count: _h3Tiles.where((t) => t.boundary != null).length,
                    sessionNew: _sessionStartZoneCount > 0
                        ? (_h3Tiles.where((t) => t.boundary != null).length - _sessionStartZoneCount).clamp(0, 999)
                        : 0,
                    onTap: widget.onGoToStats,
                  ),
                ),
              ),

            // ── 1c. Live sensor ticker — centered above FAB when recording ──
            ListenableBuilder(
              listenable: Listenable.merge([
                _locationService.isRunning,
                _locationService.isPaused,
              ]),
              builder: (context, _) {
                final isActive = _locationService.isRunning.value &&
                    !_locationService.isPaused.value;
                if (!isActive) return const SizedBox.shrink();
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomPadding + AppTheme.floatingNavHeight +
                      AppTheme.spaceLg + _kFabHeight + AppTheme.spaceSm,
                  child: const Center(child: _LiveDataTicker()),
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

/// First-use hint — shown until user has tiles or starts tracking.
/// Solid dark pill (same style as TrackingStatusChip) pointing toward the FAB.
class _FirstUseHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCC111927),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        context.l10n.homeFirstUseHint,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13.0,
          fontWeight: AppFontWeights.medium,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Compact pill showing personal zone count — retention hook (territory growing).
/// When [sessionNew] > 0 also shows "+N new" in green to highlight session progress.
/// Solid dark pill matching TrackingStatusChip style.
class _ZoneCountPill extends StatelessWidget {
  const _ZoneCountPill({required this.count, this.sessionNew = 0, this.onTap});
  final int count;
  /// New zones added in the current tracking session. 0 = hide delta.
  final int sessionNew;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
      decoration: BoxDecoration(
        color: const Color(0xCC111927),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sessionNew > 0) ...[
            Text(
              '+$sessionNew',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12.0,
                fontWeight: AppFontWeights.bold,
                letterSpacing: 0.2,
              ),
            ),
            Container(
              width: 1,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXxs),
              color: Colors.white24,
            ),
          ],
          Text(
            context.l10n.homeZonesMapped(count),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.0,
              fontWeight: AppFontWeights.medium,
              letterSpacing: 0.2,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppTheme.spaceXxxs + 1),
            const Icon(Icons.chevron_right, size: 13, color: Colors.white38),
          ],
        ],
      ),
    );

    if (onTap == null) return pill;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: pill,
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
/// zone appears on the map. Replaces the generic "Map updated!" snackbar.
class _FirstUploadSheet extends StatelessWidget {
  const _FirstUploadSheet();

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
                l10n.firstUploadTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: AppFontWeights.bold,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                l10n.firstUploadBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(isDark),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceXl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.firstUploadCta),
                ),
              ),
            ],
          ),
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

/// Three-chip strip showing live sensor readings while tracking is active.
/// Positioned centered above the FAB — makes the foreground feel like a live
/// data instrument rather than a static map + button.
///
/// Updates in real-time via sensor streams. Each chip uses the standard sensor
/// color (light=amber, pressure=blue, movement=teal) for instant recognition.
class _LiveDataTicker extends StatefulWidget {
  const _LiveDataTicker();

  @override
  State<_LiveDataTicker> createState() => _LiveDataTickerState();
}

class _LiveDataTickerState extends State<_LiveDataTicker> {
  final _svc = ForegroundLocationService.instance;
  LightData? _light;
  PressureData? _pressure;
  AccelerometerData? _accel;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    // Seed from cached last-known values (instant display on open)
    _light    = _svc.lastLight;
    _pressure = _svc.lastPressure;
    _accel    = _svc.lastAccelerometer;
    // Stream updates
    _subs.add(_svc.lightStream.listen((d) {
      if (mounted) setState(() => _light = d);
    }));
    _subs.add(_svc.pressureStream.listen((d) {
      if (mounted) setState(() => _pressure = d);
    }));
    _subs.add(_svc.accelerometerStream.listen((d) {
      if (mounted) setState(() => _accel = d);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) { s.cancel(); }
    super.dispose();
  }

  String _luxLabel(double lux) {
    if (lux >= 10000) return '${(lux / 1000).toStringAsFixed(0)}k lx';
    if (lux >= 1000) return '${(lux / 1000).toStringAsFixed(1)}k lx';
    return '${lux.toStringAsFixed(0)} lx';
  }

  String _accelLabel(double mag) {
    if (mag < 2.0) return 'still';
    if (mag < 8.0) return 'moving';
    return 'active';
  }

  @override
  Widget build(BuildContext context) {
    // Build list of (icon, color, label) for sensors that have data
    final entries = <(IconData, Color, String)>[];
    if (_light != null) {
      entries.add((Icons.light_mode_outlined, AppColors.light, _luxLabel(_light!.lux)));
    }
    if (_pressure != null) {
      entries.add((Icons.compress, AppColors.pressure, '${_pressure!.hPa.toStringAsFixed(0)} hPa'));
    }
    if (_accel != null) {
      entries.add((Icons.vibration, AppColors.movement, _accelLabel(_accel!.magnitude)));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.spaceXxxs + 1),
          _TickerChip(
            icon: entries[i].$1,
            color: entries[i].$2,
            label: entries[i].$3,
          ),
        ],
      ],
    );
  }
}

/// Single sensor reading chip for the live data ticker.
class _TickerChip extends StatelessWidget {
  const _TickerChip({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXxs + 1,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCC111927),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: AppTheme.spaceXxs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: AppFontWeights.semibold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

