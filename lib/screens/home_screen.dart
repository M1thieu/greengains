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
import '../widgets/contribution_stats_card.dart';
import '../widgets/contextual_tip_card.dart';
import '../widgets/service_control_button.dart';
import '../widgets/battery_optimization_dialog.dart';
import '../widgets/tracking_status_banner.dart';
import '../widgets/impact_summary_card.dart';
import '../widgets/sensor_section.dart';
import '../widgets/coverage_map_widget.dart';
import 'coverage_map_screen.dart';

// Constants
const double _kDefaultTileConfidence = 0.5;

/// Home screen with Option B layout
/// Clear visual hierarchy: Status -> Coverage Map (50%) -> Impact/Stats -> Technical Details
/// Combines impact metrics with today's stats for space efficiency
/// Optimized for fast performance with minimal animations
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _locationService = ForegroundLocationService.instance;
  final _statsKey = GlobalKey<ContributionStatsCardState>();
  final _contributionRepo = ContributionRepository();
  final _prefs = AppPreferences.instance;
  final Set<String> _dismissedTips = {};
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

  Future<void> _checkBatteryOptimization() async {
    // Wait for the UI to be ready
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

      if (!_locationService.isRunning.value) {
        return;
      }

      const platform = MethodChannel('greengains/foreground');
      final bool isIgnoring = await platform.invokeMethod('isIgnoringBatteryOptimizations');

      if (!isIgnoring && mounted) {
        _batteryPromptOpen = true;
        await _prefs.setBatteryOptimizationPromptLastShown(DateTime.now());
        // Directly open Android's native battery optimization settings
        try {
          await platform.invokeMethod('requestIgnoreBatteryOptimizations');
        } catch (e) {
          print("Failed to request battery optimization: $e");
        } finally {
          _batteryPromptOpen = false;
        }
      }
    } on PlatformException catch (e) {
      print("Failed to check battery optimization: '${e.message}'.");
    }
  }

  void _loadDismissedTips() {
    // Load which tips have been dismissed
    setState(() {
      if (_prefs.isTipDismissed('expand_sensors')) {
        _dismissedTips.add('expand_sensors');
      }
    });
  }

  Future<void> _dismissTip(String tipId) async {
    await _prefs.dismissTip(tipId);
    setState(() {
      _dismissedTips.add(tipId);
    });
  }

  bool _shouldShowTip(String tipId) {
    return !_dismissedTips.contains(tipId);
  }

  void _setupUploadSuccessListener() {
    _uploadSuccessSub = AppEventBus.instance
        .on<UploadSuccessEvent>()
        .listen(_onUploadSuccess);
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
    // Clean up stream subscriptions
    _locationStreamSub?.cancel();
    _uploadSuccessSub?.cancel();
    _locationService.isRunning.removeListener(_handleServiceRunningChange);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Flush FIFO buffers only if service is running (which means permissions granted)
      if (_locationService.isRunning.value) {
        await _locationService.flushSensorBuffers();
      }
      // Sync service status with native
      _checkServiceStatus();
      // Reload last upload time from preferences
      _reloadUploadStatus();
      // Auto-refresh stats when user returns to app
      _statsKey.currentState?.refresh();
      _loadTileCoverage();
      _loadStats();
      _loadH3Tiles();
    }
  }

  Future<void> _reloadUploadStatus() async {
    await _prefs.ensureInitialized();
    final lastUpload = _prefs.lastUploadAt;
    if (lastUpload != null) {
      debugPrint('Reloaded last upload from SharedPreferences: $lastUpload');
      _locationService.uploadStatus.value =
          _locationService.uploadStatus.value.copyWith(lastUpload: lastUpload);
    } else {
      debugPrint('No last upload timestamp found in SharedPreferences');
    }
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await _locationService.isServiceRunning();

    // Auto-restart service if it was running before but got killed (e.g., force-stop)
    if (!isRunning && _prefs.foregroundServiceEnabled) {
      debugPrint('Service was running before but is now stopped. Auto-restarting...');
      final wasPaused = _prefs.trackingPaused;
      await _locationService.start();
      // Restore paused state if it was paused before the kill
      if (wasPaused) {
        await _locationService.pauseTracking();
        debugPrint('Restored paused state after auto-restart');
      }
    }
  }

  Future<void> _refreshData() async {
    HapticFeedback.lightImpact();
    // Flush FIFO buffers only if service is running (which means permissions granted)
    if (_locationService.isRunning.value) {
      await _locationService.flushSensorBuffers();
    }
    // Refresh contribution stats
    await _statsKey.currentState?.refresh();
    await _loadTileCoverage();
    await _loadStats();
    await _loadH3Tiles();
    // Min duration for better UX feedback
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
      if (mounted) {
        setState(() {
          _tileCoverageLoading = false;
        });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _contributionRepo.getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (_) {
      // Silently fail - stats card will handle empty state
    }
  }

  Future<void> _loadH3Tiles() async {
    setState(() {
      _h3TilesLoading = true;
    });

    try {
      final response = await BackendClient.get('/api/user/tiles?hours=72');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tilesData = data['tiles'] as List<dynamic>?;

        final tiles = tilesData?.map((tile) {
          // Extract centroid from backend response
          final centroid = tile['centroid'] as Map<String, dynamic>?;
          final lat = (centroid?['lat'] as num?)?.toDouble();
          final lng = (centroid?['lng'] as num?)?.toDouble();

          // Create simple circular boundary around centroid
          List<LatLng>? boundary;
          if (lat != null && lng != null) {
            const tileRadiusDegrees = 0.001; // ~100m at mid-latitudes
            const circlePoints = 16; // Points to approximate circle
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
            confidence: (tile['confidence'] as num?)?.toDouble() ?? _kDefaultTileConfidence,
            sampleCount: tile['sampleCount'] as int? ?? 0,
            deviceCount: tile['deviceCount'] as int? ?? 1,
            boundary: boundary,
          );
        }).toList() ?? [];

        if (mounted) {
          setState(() {
            _h3Tiles = tiles;
            _h3TilesLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        // User not authenticated, show empty map
        debugPrint('User not authenticated, showing empty map');
        if (mounted) {
          setState(() {
            _h3Tiles = [];
            _h3TilesLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load tiles: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to load H3 tiles: $e');
      if (mounted) {
        setState(() {
          _h3Tiles = [];
          _h3TilesLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      // Check permission first
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission not granted');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint('Failed to get user location: $e');
      // Keep _userLocation as null - map will show default bounds
    }
  }

  void _subscribeToLocationUpdates() {
    _locationStreamSub = _locationService.locationStream.listen((locationData) {
      if (mounted) {
        setState(() {
          _userLocation = LatLng(locationData.latitude, locationData.longitude);
        });
      }
    });
  }

  void _navigateToCoverageMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CoverageMapScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = context.isDarkMode;
    final isRunningNow = _locationService.isRunning.value;
    final overlayStyle = isRunningNow
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Main content with improved hierarchy
              RefreshIndicator(
                onRefresh: _refreshData,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
                  children: [
                    // 1. Service Control (Primary Action)
                    const ServiceControlButton(),
                    const SizedBox(height: AppTheme.spaceMd),

                    // 2. Tracking Status Banner (Always visible - not buried)
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _locationService.isRunning,
                        _locationService.isPaused,
                        _locationService.uploadStatus,
                      ]),
                      builder: (context, _) {
                        final isRunning = _locationService.isRunning.value;
                        final isPaused = _locationService.isPaused.value;
                        final status = _locationService.uploadStatus.value;
                        return TrackingStatusBanner(
                          isTracking: isRunning && !isPaused,
                          isPaused: isRunning && isPaused,
                          lastUpload: status.lastUpload,
                          errorMessage: status.lastError,
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    // 3. Coverage Map (50% height - Option B)
                    CoverageMapWidget(
                      tiles: _h3Tiles,
                      userLocation: _userLocation,
                      heightFraction: 0.5,
                      showControls: true, // Enable pan/zoom
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // 4. Merged Impact Summary + Today Stats
                    ImpactSummaryCard(
                      stats: _stats,
                      tileCoverage: _tileCoverage,
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // 5. Contextual Tips
                    if (_locationService.isRunning.value &&
                        !_locationService.isPaused.value &&
                        _shouldShowTip('expand_sensors'))
                      ContextualTipCard(
                        tipId: 'expand_sensors',
                        icon: Icons.expand_more,
                        title: 'View live data',
                        message: 'Expand the sensor section below to verify data is streaming correctly',
                        onDismiss: () => _dismissTip('expand_sensors'),
                      ),

                    // 6. Technical Details (Collapsible)
                    SensorSection(
                      locationService: _locationService,
                      onExpansionChanged: () {
                        // Dismiss tip when user expands sensors
                        if (_shouldShowTip('expand_sensors')) {
                          _dismissTip('expand_sensors');
                        }
                      },
                    ),

                    // Bottom padding for better scrolling experience
                    const SizedBox(height: AppTheme.spaceLg),
                  ],
                ),
              ),

              // DailyPot + CreditsDisplay hidden until feature is ready
            ],
          ),
        ),
      ),
    );
  }
}
