import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../services/location/foreground_location_service.dart';

/// Coverage map screen showing geographic areas where user has contributed data
/// Lightweight map view with current location and navigation controls.
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const CoverageMapScreen()),
/// )
/// ```
class CoverageMapScreen extends StatefulWidget {
  const CoverageMapScreen({super.key});

  @override
  State<CoverageMapScreen> createState() => _CoverageMapScreenState();
}

class _CoverageMapScreenState extends State<CoverageMapScreen> {
  final _locationService = ForegroundLocationService.instance;
  late final MapController _mapController;
  LatLng? _userLocation;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadUserLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    // Get last known location from service
    final lastLocation = _locationService.lastLocation;
    if (lastLocation != null) {
      setState(() {
        _userLocation = LatLng(lastLocation.latitude, lastLocation.longitude);
        _loading = false;
      });
    } else {
      // No location yet — map will center on tile data or use widget default
      setState(() {
        _loading = false;
      });
    }
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        actions: [
          if (_userLocation != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              tooltip: l10n.mapCenterTooltip,
              onPressed: _centerOnUser,
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    l10n.mapLoadingText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation ?? LatLng(45.5017, -73.5673),
                    initialZoom: 14.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    // Smooth interactions
                    interactionOptions: const InteractionOptions(
                      enableMultiFingerGestureRace: true,
                      pinchZoomWinGestures: MultiFingerGesture.all,
                    ),
                  ),
                  children: [
                    // OpenStreetMap tile layer
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.eremat.greengains',
                      // Respect OSM usage policy
                      maxZoom: 18,
                    ),

                    // User location marker
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Map controls overlay (bottom)
                Positioned(
                  bottom: AppTheme.spaceMd,
                  right: AppTheme.spaceMd,
                  child: Column(
                    children: [
                      // Zoom in
                      _MapControlButton(
                        icon: Icons.add,
                        onPressed: () {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom + 1,
                          );
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppTheme.spaceXs),
                      // Zoom out
                      _MapControlButton(
                        icon: Icons.remove,
                        onPressed: () {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom - 1,
                          );
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Map control button (zoom, center, etc.)
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;

  const _MapControlButton({
    required this.icon,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark
          ? AppColors.darkSurface.withValues(alpha: 0.95)
          : Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.border(isDark),
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            color: AppColors.textPrimary(isDark),
            size: 24,
          ),
        ),
      ),
    );
  }
}
