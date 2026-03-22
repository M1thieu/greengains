import 'dart:async';
import 'dart:convert';
import 'package:h3_flutter/h3_flutter.dart' as h3f;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

const double _kDefaultTileConfidence = 0.5;

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
  final _userLocationNotifier = ValueNotifier<LatLng?>(null);
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
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (_batteryPromptOpen) return;

    try {
      await _prefs.ensureInitialized();
      if (_prefs.batteryOptimizationPromptDismissed) return;

      final lastShown = _prefs.batteryOptimizationPromptLastShown;
      if (lastShown != null &&
          DateTime.now().difference(lastShown) < const Duration(days: 2)) {
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
    AppSnackbars.showSuccess(context, context.l10n.uploadSuccessMessage);
    _loadH3Tiles();
    _maybeRequestReview();
  }

  /// Show the Play Store in-app review dialog once, after the user's 5th upload.
  Future<void> _maybeRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('total_upload_count') ?? 0;
      if (count < 5) return;
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
      final response = await BackendClient.get('/api/user/tiles');
      debugPrint('Tiles: HTTP ${response.statusCode} (${response.body.length}B)');

      if (response.statusCode == 401) {
        // Auth not ready yet — retry once after a short delay
        debugPrint('Tiles: 401 (auth race?), retrying in 2s');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _loadH3Tiles();
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tilesData = data['tiles'] as List<dynamic>?;

        final tiles = tilesData?.map((tile) {
          final hexIndex = tile['h3Index'] as String? ?? '';
          List<LatLng>? boundary;
          final rawBoundary = tile['boundary'] as List<dynamic>?;
          if (rawBoundary != null && rawBoundary.isNotEmpty) {
            try {
              // API returns [[lng, lat], ...] GeoJSON order — flip to LatLng(lat, lng)
              boundary = rawBoundary.map((pt) {
                final pair = pt as List<dynamic>;
                return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
              }).toList();
            } catch (_) {}
          }
          return H3Tile(
            h3Index: hexIndex,
            confidence: (tile['confidence'] as num?)?.toDouble() ??
                _kDefaultTileConfidence,
            sampleCount: tile['sampleCount'] as int? ?? 0,
            deviceCount: tile['deviceCount'] as int? ?? 1,
            boundary: boundary,
          );
        }).toList() ??
            [];

        if (mounted) {
          setState(() {
            _h3Tiles = tiles;
            _h3TilesLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load tiles: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to load H3 tiles: $e');
      if (mounted) setState(() => _h3TilesLoading = false);
      // Retry once after 4 s — catches Render cold-start connection aborts
      await Future.delayed(const Duration(seconds: 4));
      if (mounted && _h3Tiles.isEmpty) _loadH3Tiles();
    }
  }

  /// Load community coverage tiles (all users, cached 5 min on server).
  /// Loads silently in background — never blocks the loading spinner.
  Future<void> _loadGlobalTiles() async {
    try {
      final response = await BackendClient.get('/api/tiles/global');
      debugPrint('Global tiles: HTTP ${response.statusCode} (${response.body.length}B)');
      if (response.statusCode == 401) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && _globalTiles.isEmpty) _loadGlobalTiles();
        return;
      }
      if (response.statusCode != 200 || !mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tilesData = data['tiles'] as List<dynamic>?;
      final tiles = tilesData?.map((tile) {
        final hexIndex = tile['h3Index'] as String? ?? '';
        List<LatLng>? boundary;
        final rawBoundary = tile['boundary'] as List<dynamic>?;
        if (rawBoundary != null && rawBoundary.isNotEmpty) {
          try {
            // API returns [[lng, lat], ...] GeoJSON order — flip to LatLng(lat, lng)
            boundary = rawBoundary.map((pt) {
              final pair = pt as List<dynamic>;
              return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
            }).toList();
          } catch (_) {}
        }
        return H3Tile(
          h3Index: hexIndex,
          confidence: (tile['confidence'] as num?)?.toDouble() ?? 0.3,
          sampleCount: tile['sampleCount'] as int? ?? 0,
          deviceCount: tile['deviceCount'] as int? ?? 1,
          boundary: boundary,
          isGlobal: true,
        );
      }).toList() ?? [];
      if (mounted) setState(() => _globalTiles = tiles);
    } catch (e) {
      debugPrint('Failed to load global tiles: $e');
      // Retry once after 5 s — catches Render cold-start connection aborts
      await Future.delayed(const Duration(seconds: 5));
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
        _userLocationNotifier.value =
            LatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Failed to get user location: $e');
    }
  }

  void _subscribeToLocationUpdates() {
    _locationStreamSub =
        _locationService.locationStream.listen((locationData) {
      if (!mounted) return;
      final pos = LatLng(locationData.latitude, locationData.longitude);
      _userLocationNotifier.value = pos;
      _updateCurrentH3Cell(pos);
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => TileInfoSheet(tile: tile),
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
                  );
                },
              ),
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

