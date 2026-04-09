import 'dart:async';
import 'package:h3_flutter/h3_flutter.dart' as h3f;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

// My Location button: 48×48 standard touch target.
const _kLocationBtnSize = AppTheme.minTouchTarget; // 48
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
  const HomeScreen({super.key});

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
  StreamSubscription? _locationStreamSub;
  List<H3Tile> _h3Tiles = [];
  List<H3Tile> _globalTiles = [];
  bool _h3TilesLoading = true;
  /// Boundary of the H3 cell the user is currently inside — shown as live amber
  /// highlight on the map while tracking is active.
  List<LatLng>? _currentH3Boundary;

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
      _checkBatteryOptimization();
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

  void _onUploadSuccess(UploadSuccessEvent event) {
    if (!mounted) return;
    final prevCount = _h3Tiles.where((t) => t.boundary != null).length;
    _loadH3Tiles().then((_) {
      if (!mounted) return;
      final newCount = _h3Tiles.where((t) => t.boundary != null).length;
      final gained = newCount - prevCount;
      final msg = gained > 0
          ? context.l10n.uploadSuccessNewZone(newCount)
          : context.l10n.uploadSuccessMessage;
      AppSnackbars.showSuccess(context, msg);
    });
    _maybeRequestReview();
  }

  /// Show the Play Store in-app review dialog once, after the user's 5th upload.
  Future<void> _maybeRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('total_upload_count') ?? 0;
      if (count < kReviewRequestThreshold) return;
      if (prefs.getBool('review_requested') == true) return;
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        await prefs.setBool('review_requested', true);
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
    setState(() => _h3TilesLoading = true);
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
                  controlsPadding: EdgeInsets.only(
                    top: topPadding,
                    bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceLg,
                  ),
                );
              },
            ),

            // ── 0b. First-use hint — shown until user has tiles or starts tracking ──
            if (_h3Tiles.isEmpty && !_locationService.isRunning.value)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceXxl + 40,
                  ),
                  child: _FirstUseHint(),
                ),
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
                  return TrackingStatusChip(
                    isTracking: _locationService.isRunning.value &&
                        !_locationService.isPaused.value,
                    isPaused: _locationService.isRunning.value &&
                        _locationService.isPaused.value,
                    lastUpload: status.lastUpload,
                    tileCount: _h3Tiles.where((t) => t.boundary != null).length,
                    isUploading: status.isUploading,
                    onTap: _openSensorSheet,
                  );
                },
              ),
            ),

            // ── 1b. Personal zone count strip (above nav, shown when tiles loaded) ──
            if (_h3Tiles.isNotEmpty)
              Positioned(
                left: AppTheme.spaceMd,
                bottom: bottomPadding + AppTheme.floatingNavHeight + AppTheme.spaceLg + 52,
                child: _ZoneCountPill(count: _h3Tiles.length),
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
/// Solid dark pill matching TrackingStatusChip style.
class _ZoneCountPill extends StatelessWidget {
  const _ZoneCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
      decoration: BoxDecoration(
        color: const Color(0xCC111927),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        context.l10n.homeZonesMapped(count),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12.0,
          fontWeight: AppFontWeights.medium,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// My Location button — standard map UX (Google Maps / Waze / Apple Maps pattern).
/// 48×48 circular dark button.
class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.shadowDark(0.65),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: _kLocationBtnSize,
          height: _kLocationBtnSize,
          child: Icon(Icons.my_location, color: Colors.white, size: AppIconSizes.sm),
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

