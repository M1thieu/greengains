import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../widgets/impact_summary_card.dart';
import '../widgets/sensor_section.dart';
import '../widgets/coverage_map_widget.dart';
import '../widgets/tracking_status_chip.dart';
import '../widgets/tracking_fab.dart';

const double _kDefaultTileConfidence = 0.5;
const double _kSheetMinSize = 0.14;
const double _kSheetInitialSize = 0.30;
const double _kSheetMaxSize = 0.72;

/// Home screen — map-as-background layout.
///
/// Layer order (bottom → top):
///   0. CoverageMapWidget (edge-to-edge background)
///   1. Status chip (top overlay)
///   2. DraggableScrollableSheet (stats + sensors, pull-to-refresh)
///   3. TrackingFab + MyLocationButton (fades when sheet is expanded)
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
  final _userLocationNotifier = ValueNotifier<LatLng?>(null);
  /// Incrementing recenter triggers CoverageMapWidget to move camera to user.
  /// Provider-agnostic: HomeScreen never touches MapController directly.
  final _recenterTrigger = ValueNotifier<int>(0);

  TileCoverageStats? _tileCoverage;
  bool _batteryPromptOpen = false;
  bool _isOnline = true;
  ContributionStats? _stats;
  StreamSubscription<UploadSuccessEvent>? _uploadSuccessSub;
  StreamSubscription<LocationData>? _locationStreamSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  List<H3Tile> _h3Tiles = [];
  List<H3Tile> _globalTiles = [];
  bool _h3TilesLoading = true;
  double _sheetInitialSize = _kSheetInitialSize;
  Timer? _sheetSizeSaveDebounce;

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
    _initConnectivity();
    _loadTileCoverage();
    _loadStats();
    _loadH3Tiles();
    _loadGlobalTiles();
    _loadUserLocation();
    _subscribeToLocationUpdates();
    _restoreSheetState();
  }

  void _handleServiceRunningChange() {
    if (_locationService.isRunning.value) {
      _checkBatteryOptimization();
    }
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOnline = results.any((r) => r != ConnectivityResult.none));
    }
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() => _isOnline = results.any((r) => r != ConnectivityResult.none));
      }
    });
  }

  /// Fade the FAB + My Location out as sheet expands toward sensor view (70%).
  void _updateFabOpacity() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    // Start fading at 38%, fully hidden at 52% (aligned with new snap points)
    final opacity = ((0.48 - size) / (0.48 - 0.36)).clamp(0.0, 1.0);
    _fabOpacity.value = opacity;
    _persistSheetState(size);
  }

  Future<void> _restoreSheetState() async {
    await _prefs.ensureInitialized();
    final saved = _prefs.homeSheetSize;
    if (saved == null) return;
    final restored = saved.clamp(_kSheetMinSize, _kSheetMaxSize);
    if (!mounted) return;
    setState(() => _sheetInitialSize = restored);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetController.isAttached) return;
      _sheetController.jumpTo(restored);
    });
  }

  void _persistSheetState(double size) {
    _sheetSizeSaveDebounce?.cancel();
    _sheetSizeSaveDebounce = Timer(const Duration(milliseconds: 300), () {
      _prefs.setHomeSheetSize(size.clamp(_kSheetMinSize, _kSheetMaxSize));
    });
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
    AppSnackbars.showSuccess(context, context.l10n.uploadSuccessMessage);
    _loadTileCoverage();
    _loadStats().then((_) => _maybeRequestReview());
    _loadH3Tiles();
  }

  /// Show the Play Store in-app review dialog once, after the user's 5th upload.
  /// The OS controls whether the dialog actually appears (rate-limited by Android).
  Future<void> _maybeRequestReview() async {
    try {
      final stats = _stats;
      if (stats == null || stats.totalUploads < 5) return;
      final prefs = await SharedPreferences.getInstance();
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
    _connectivitySub?.cancel();
    _locationService.isRunning.removeListener(_handleServiceRunningChange);
    _sheetController.removeListener(_updateFabOpacity);
    _sheetSizeSaveDebounce?.cancel();
    _sheetController.dispose();
    _fabOpacity.dispose();
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
        setState(() => _tileCoverage = stats);
      }
    } catch (_) {}
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
            h3Index: tile['h3Index'] as String? ?? '',
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

  /// Load community coverage tiles (all users, cached 5 min on server).
  /// Loads silently in background — never blocks the loading spinner.
  Future<void> _loadGlobalTiles() async {
    try {
      final response = await BackendClient.get('/api/tiles/global?hours=48');
      if (response.statusCode != 200 || !mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tilesData = data['tiles'] as List<dynamic>?;
      final tiles = tilesData?.map((tile) {
        final centroid = tile['centroid'] as Map<String, dynamic>?;
        final lat = (centroid?['lat'] as num?)?.toDouble();
        final lng = (centroid?['lng'] as num?)?.toDouble();
        List<LatLng>? boundary;
        if (lat != null && lng != null) {
          const r = 0.001;
          boundary = [for (var i = 0; i < 16; i++) LatLng(lat + r * cos(i * pi / 8), lng + r * sin(i * pi / 8))];
        }
        return H3Tile(
          h3Index: tile['h3Index'] as String? ?? '',
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
      if (mounted) {
        _userLocationNotifier.value =
            LatLng(locationData.latitude, locationData.longitude);
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
            ValueListenableBuilder<LatLng?>(
              valueListenable: _userLocationNotifier,
              builder: (context, userLocation, _) => CoverageMapWidget(
                // Global (community) tiles rendered first so personal tiles appear on top
                tiles: [..._globalTiles, ..._h3Tiles],
                userLocation: userLocation,
                fillScreen: true,
                isLoading: _h3TilesLoading,
                recenterTrigger: _recenterTrigger,
                controlsPadding: EdgeInsets.only(
                  top: topPadding,
                  bottom: screenHeight * 0.14 + 48,
                ),
              ),
            ),

            // ── 1. Top overlay: status chip ───────────────────────────────
            Positioned(
              top: topPadding + 8,
              left: 16,
              right: 16,
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
            // ── 2. Bottom sheet: stats + sensors ──────────────────────────
            DraggableScrollableSheet(
              controller: _sheetController,
              minChildSize: _kSheetMinSize,   // collapsed: just the handle
              initialChildSize: _sheetInitialSize,
              maxChildSize: _kSheetMaxSize,   // expanded: sensors fully readable
              snap: true,
              snapSizes: const [0.30, 0.72], // 2 natural positions (not 3)
              snapAnimationDuration: const Duration(milliseconds: 320),
              builder: (ctx, scrollController) => _BottomSheetContent(
                scrollController: scrollController,
                stats: _stats,
                tileCoverage: _tileCoverage,
                locationService: _locationService,
                shouldShowTip: _shouldShowTip,
                onDismissTip: _dismissTip,
                isOnline: _isOnline,
                onRefresh: _refreshData,
              ),
            ),

            // ── 3. FAB (fades out when sheet is expanded) ─────────────────
            Positioned(
              right: 16,
              bottom: screenHeight * 0.14 + 16,
              child: ValueListenableBuilder<double>(
                valueListenable: _fabOpacity,
                builder: (_, opacity, child) => AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 150),
                  child: child,
                ),
                child: Semantics(
                  button: true,
                  label: context.l10n.semanticsToggleTracking,
                  child: const TrackingFab(),
                ),
              ),
            ),

            // ── 4. My Location button (bottom-left, above sheet) ──────────
            // Standard map UX: every major map app (Google Maps, Waze, Apple Maps)
            // has a "recenter on me" button. Provider-agnostic via recenterTrigger.
            ValueListenableBuilder<LatLng?>(
              valueListenable: _userLocationNotifier,
              builder: (context, userLocation, _) {
                if (userLocation == null) return const SizedBox.shrink();
                return Positioned(
                  left: 16,
                  bottom: screenHeight * 0.14 + 16,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _fabOpacity,
                    builder: (_, opacity, child) => AnimatedOpacity(
                      opacity: opacity,
                      duration: const Duration(milliseconds: 150),
                      child: child,
                    ),
                    child: Semantics(
                      button: true,
                      label: context.l10n.semanticsCenterOnMe,
                      child: _MyLocationButton(
                        onPressed: () => _recenterTrigger.value++,
                      ),
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

/// Draggable bottom sheet content: handle + ImpactSummaryCard + sensors.
class _BottomSheetContent extends StatelessWidget {
  const _BottomSheetContent({
    required this.scrollController,
    required this.stats,
    required this.tileCoverage,
    required this.locationService,
    required this.shouldShowTip,
    required this.onDismissTip,
    required this.isOnline,
    required this.onRefresh,
  });

  final ScrollController scrollController;
  final ContributionStats? stats;
  final TileCoverageStats? tileCoverage;
  final ForegroundLocationService locationService;
  final bool Function(String) shouldShowTip;
  final Future<void> Function(String) onDismissTip;
  final bool isOnline;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        // surface (#1C1C1C) as base — cards inside use surfaceElevated (#262626)
        // so they properly float above the sheet (previously inverted and muddy).
        color: AppColors.surface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark(isDark ? 0.6 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false, // content allowed to go under nav bar gesture area
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
            // Drag handle — Material 3: 32dp wide, 4dp tall, white @20% opacity
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.shadowLight(0.2)
                        : AppColors.shadowDark(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Offline banner (connectivity_plus)
            if (!isOnline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, size: 15, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.offlineBannerMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.warning,
                            fontWeight: AppFontWeights.medium,
                          ),
                        ),
                      ],
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
                  // stats==null means API response not yet received → show skeleton
                  isLoading: stats == null,
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
                  final l10n = context.l10n;
                  return SliverToBoxAdapter(
                    child: ContextualTipCard(
                      tipId: 'expand_sensors',
                      icon: Icons.expand_more,
                      title: l10n.tipViewLiveDataTitle,
                      message: l10n.tipViewLiveDataMessage,
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
      ),
    );
  }
}

/// My Location button — standard map UX (Google Maps / Waze / Apple Maps pattern).
/// 48×48 circular dark button. Fades with TrackingFab as sheet expands.
/// Fades together with TrackingFab as sheet expands.
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
          width: 48,
          height: 48,
          child: Icon(Icons.my_location, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

