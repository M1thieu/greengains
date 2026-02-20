import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../data/models/contribution_stats.dart';
import '../data/repositories/contribution_repository.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../services/location/foreground_location_service.dart';
import '../services/network/backend_client.dart';
import '../models/sensor_models.dart';
import '../core/events/app_events.dart';
import '../utils/app_snackbars.dart';
import '../core/app_preferences.dart';
import '../widgets/contextual_tip_card.dart';
import '../widgets/battery_optimization_dialog.dart';
import '../widgets/impact_summary_card.dart';
import '../widgets/sensor_section.dart';
import '../widgets/coverage_map_widget.dart';
import '../widgets/tracking_status_chip.dart';
import '../widgets/tracking_fab.dart';

const double _kDefaultTileConfidence = 0.5;

/// Home screen — map-as-background layout.
///
/// Layer order (bottom → top):
///   0. CoverageMapWidget (edge-to-edge background)
///   1. Status chip + refresh button (top overlay)
///   2. DraggableScrollableSheet (stats + sensors, 3 snap positions)
///   3. TrackingFab (bottom-right, fades when sheet is expanded)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _locationService = ForegroundLocationService.instance;
  final _contributionRepo = ContributionRepository();
  final _prefs = AppPreferences.instance;
  final Set<String> _dismissedTips = {};
  final _sheetController = DraggableScrollableController();
  final _fabOpacity = ValueNotifier<double>(1.0);

  TileCoverageStats? _tileCoverage;
  bool _tileCoverageLoading = true;
  bool _batteryPromptOpen = false;
  ContributionStats? _stats;
  StreamSubscription<UploadSuccessEvent>? _uploadSuccessSub;
  StreamSubscription<LocationData>? _locationStreamSub;
  List<H3Tile> _h3Tiles = [];
  bool _h3TilesLoading = true;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService.isRunning.addListener(_handleServiceRunningChange);
    _sheetController.addListener(_updateFabOpacity);
    _checkServiceStatus();
    _setupUploadSuccessListener();
    _loadDismissedTips();
    _checkBatteryOptimization();
    _loadTileCoverage();
    _loadStats();
    _loadH3Tiles();
    _loadUserLocation();
    _subscribeToLocationUpdates();
  }

  void _handleServiceRunningChange() {
    if (_locationService.isRunning.value) {
      _checkBatteryOptimization();
    }
  }

  /// Fade the FAB out as the sheet approaches the mid snap position (40%).
  void _updateFabOpacity() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    // Start fading at 28%, fully hidden at 40%
    final opacity = ((0.35 - size) / (0.35 - 0.26)).clamp(0.0, 1.0);
    _fabOpacity.value = opacity;
  }

  Future<void> _checkBatteryOptimization() async {
    await Future.delayed(const Duration(seconds: 2));
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

  void _loadDismissedTips() {
    setState(() {
      if (_prefs.isTipDismissed('expand_sensors')) {
        _dismissedTips.add('expand_sensors');
      }
    });
  }

  Future<void> _dismissTip(String tipId) async {
    await _prefs.dismissTip(tipId);
    setState(() => _dismissedTips.add(tipId));
  }

  bool _shouldShowTip(String tipId) => !_dismissedTips.contains(tipId);

  void _setupUploadSuccessListener() {
    _uploadSuccessSub =
        AppEventBus.instance.on<UploadSuccessEvent>().listen(_onUploadSuccess);
  }

  void _onUploadSuccess(UploadSuccessEvent event) {
    if (!mounted) return;
    AppSnackbars.showSuccess(context, 'Contribution uploaded successfully!');
    _loadTileCoverage();
    _loadStats();
    _loadH3Tiles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationStreamSub?.cancel();
    _uploadSuccessSub?.cancel();
    _locationService.isRunning.removeListener(_handleServiceRunningChange);
    _sheetController.removeListener(_updateFabOpacity);
    _sheetController.dispose();
    _fabOpacity.dispose();
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
      _loadTileCoverage();
      _loadStats();
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

  Future<void> _refreshData() async {
    HapticFeedback.lightImpact();
    if (_locationService.isRunning.value) {
      await _locationService.flushSensorBuffers();
    }
    await _loadTileCoverage();
    await _loadStats();
    await _loadH3Tiles();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _loadTileCoverage() async {
    try {
      final stats = await _contributionRepo.getTodayTileCoverage();
      if (mounted) {
        setState(() {
          _tileCoverage = stats;
          _tileCoverageLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tileCoverageLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _contributionRepo.getStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  Future<void> _loadH3Tiles() async {
    setState(() => _h3TilesLoading = true);

    try {
      final response = await BackendClient.get('/api/user/tiles?hours=72');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tilesData = data['tiles'] as List<dynamic>?;

        final tiles = tilesData?.map((tile) {
          final centroid = tile['centroid'] as Map<String, dynamic>?;
          final lat = (centroid?['lat'] as num?)?.toDouble();
          final lng = (centroid?['lng'] as num?)?.toDouble();

          List<LatLng>? boundary;
          if (lat != null && lng != null) {
            const tileRadiusDegrees = 0.001;
            const circlePoints = 16;
            boundary = [
              for (var i = 0; i < circlePoints; i++)
                LatLng(
                  lat + tileRadiusDegrees * cos(i * pi / 8),
                  lng + tileRadiusDegrees * sin(i * pi / 8),
                ),
            ];
          }

          return H3Tile(
            h3Index: tile['h3Index'] as String,
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
      } else if (response.statusCode == 401) {
        if (mounted) setState(() => _h3TilesLoading = false);
      } else {
        throw Exception('Failed to load tiles: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to load H3 tiles: $e');
      if (mounted) setState(() => _h3TilesLoading = false);
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted) {
        setState(() =>
            _userLocation = LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      debugPrint('Failed to get user location: $e');
    }
  }

  void _subscribeToLocationUpdates() {
    _locationStreamSub =
        _locationService.locationStream.listen((locationData) {
      if (mounted) {
        setState(() => _userLocation =
            LatLng(locationData.latitude, locationData.longitude));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Stack(
          children: [
            // ── 0. Full-screen map (edge-to-edge background) ──────────────
            CoverageMapWidget(
              tiles: _h3Tiles,
              userLocation: _userLocation,
              fillScreen: true,
            ),

            // ── 1. Top overlay: status chip + refresh button ───────────────
            Positioned(
              top: topPadding + 8,
              left: 16,
              right: 56, // leave room for the refresh button
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
                  );
                },
              ),
            ),
            Positioned(
              top: topPadding + 4,
              right: 12,
              child: _RefreshButton(onPressed: _refreshData),
            ),

            // ── 2. Bottom sheet: stats + sensors ──────────────────────────
            DraggableScrollableSheet(
              controller: _sheetController,
              minChildSize: 0.18,
              initialChildSize: 0.22,
              maxChildSize: 0.65,
              snap: true,
              snapSizes: const [0.18, 0.40, 0.65],
              builder: (ctx, scrollController) => _BottomSheetContent(
                scrollController: scrollController,
                stats: _stats,
                tileCoverage: _tileCoverage,
                locationService: _locationService,
                shouldShowTip: _shouldShowTip,
                onDismissTip: _dismissTip,
              ),
            ),

            // ── 3. FAB (fades out when sheet is expanded) ─────────────────
            Positioned(
              right: 16,
              bottom: screenHeight * 0.18 + 16,
              child: ValueListenableBuilder<double>(
                valueListenable: _fabOpacity,
                builder: (_, opacity, child) => AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 150),
                  child: child,
                ),
                child: const TrackingFab(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Private widgets ────────────────────────────────────────────────────────

/// Small icon button overlaid on the map to trigger a data refresh.
class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.onPressed});
  final Future<void> Function() onPressed;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _loading = false;

  Future<void> _tap() async {
    if (_loading) return;
    setState(() => _loading = true);
    await widget.onPressed();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        shape: BoxShape.circle,
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
              onPressed: _tap,
              tooltip: 'Refresh',
            ),
    );
  }
}

/// Draggable bottom sheet content: handle + ImpactSummaryCard + sensors.
class _BottomSheetContent extends StatelessWidget {
  const _BottomSheetContent({
    required this.scrollController,
    required this.stats,
    required this.tileCoverage,
    required this.locationService,
    required this.shouldShowTip,
    required this.onDismissTip,
  });

  final ScrollController scrollController;
  final ContributionStats? stats;
  final TileCoverageStats? tileCoverage;
  final ForegroundLocationService locationService;
  final bool Function(String) shouldShowTip;
  final Future<void> Function(String) onDismissTip;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false, // content allowed to go under nav bar gesture area
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            // Drag handle
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Impact + stats card
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: ImpactSummaryCard(
                  stats: stats,
                  tileCoverage: tileCoverage,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Contextual tip (dismissible)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: ListenableBuilder(
                listenable: Listenable.merge([
                  locationService.isRunning,
                  locationService.isPaused,
                ]),
                builder: (context, _) {
                  final isActive = locationService.isRunning.value &&
                      !locationService.isPaused.value;
                  if (!isActive || !shouldShowTip('expand_sensors')) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: ContextualTipCard(
                      tipId: 'expand_sensors',
                      icon: Icons.expand_more,
                      title: 'View live data',
                      message:
                          'Tap below to see what data you\'re contributing right now',
                      onDismiss: () => onDismissTip('expand_sensors'),
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 4)),

            // Live sensor readings (collapsible)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: SensorSection(
                  locationService: locationService,
                  onExpansionChanged: () {
                    // no-op: tip is hidden by shouldShowTip once dismissed
                  },
                ),
              ),
            ),

            // Bottom padding (accounts for system nav bar)
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
