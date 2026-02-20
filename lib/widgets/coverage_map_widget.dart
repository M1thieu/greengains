import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/themes.dart';

/// H3 hexagon tile model
/// Note: H3 visualization will be added in a future update when backend is ready
class H3Tile {
  final String h3Index;
  final double confidence; // 0.0-1.0
  final int sampleCount;
  final int deviceCount;
  final List<LatLng>? boundary; // Pre-computed boundary points

  const H3Tile({
    required this.h3Index,
    required this.confidence,
    required this.sampleCount,
    required this.deviceCount,
    this.boundary,
  });
}

/// Coverage map with H3 hexagon visualization.
/// Supports two modes:
/// - [fillScreen] = false (default): fixed height via [heightFraction], card-style chrome
/// - [fillScreen] = true: expands to fill its parent (Stack/SizedBox.expand), no card chrome
class CoverageMapWidget extends StatefulWidget {
  final List<H3Tile> tiles;
  final LatLng? userLocation;
  final double heightFraction; // used only when fillScreen == false
  final bool showControls;
  final bool fillScreen;

  const CoverageMapWidget({
    super.key,
    required this.tiles,
    this.userLocation,
    this.heightFraction = 0.5,
    this.showControls = true,
    this.fillScreen = false,
  });

  @override
  State<CoverageMapWidget> createState() => _CoverageMapWidgetState();
}

class _CoverageMapWidgetState extends State<CoverageMapWidget> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Calculate initial map bounds from tiles + user location
  LatLngBounds _calculateBounds() {
    if (widget.tiles.isEmpty && widget.userLocation == null) {
      // Default: Colmar, France
      return LatLngBounds(
        const LatLng(48.0, 7.3),
        const LatLng(48.1, 7.4),
      );
    }

    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    // Include user location
    if (widget.userLocation != null) {
      final loc = widget.userLocation!;
      minLat = loc.latitude;
      maxLat = loc.latitude;
      minLng = loc.longitude;
      maxLng = loc.longitude;
    }

    // Include all tile boundaries (if pre-computed)
    for (final tile in widget.tiles) {
      if (tile.boundary != null) {
        for (final point in tile.boundary!) {
          minLat = minLat < point.latitude ? minLat : point.latitude;
          maxLat = maxLat > point.latitude ? maxLat : point.latitude;
          minLng = minLng < point.longitude ? minLng : point.longitude;
          maxLng = maxLng > point.longitude ? maxLng : point.longitude;
        }
      }
    }

    // Add padding (5%)
    final latPadding = (maxLat - minLat) * 0.05;
    final lngPadding = (maxLng - minLng) * 0.05;

    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  void _recenterOnUser() {
    if (widget.userLocation != null) {
      _mapController.move(widget.userLocation!, _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bounds = _calculateBounds();
    final center = LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );

    final mapStack = Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              interactionOptions: InteractionOptions(
                flags: widget.showControls
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
            ),
            children: [
              // Base map tiles (OpenStreetMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.eremat.greengains',
                tileBuilder: isDark ? _darkModeTileBuilder : null,
              ),

              // H3 hexagon layer (if tiles have pre-computed boundaries)
              if (widget.tiles.any((t) => t.boundary != null))
                PolygonLayer(
                  polygons: widget.tiles
                      .where((tile) => tile.boundary != null && tile.boundary!.isNotEmpty)
                      .map((tile) {
                    // Gradient opacity based on confidence
                    final opacity = (tile.confidence * 0.7).clamp(0.1, 0.7);

                    return Polygon(
                      points: tile.boundary!,
                      color: AppColors.primary.withValues(alpha: opacity),
                      borderColor: AppColors.primary.withValues(alpha: opacity + 0.2),
                      borderStrokeWidth: 1.5,
                    );
                  }).toList(),
                ),

              // User location marker
              if (widget.userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.userLocation!,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: widget.showControls ? _recenterOnUser : null,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
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
                    ),
                  ],
                ),
            ],
          ),

          // Legend overlay (top-right)
          if (widget.tiles.isNotEmpty)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border(isDark),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hexagon,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.tiles.length} tiles',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary(isDark),
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Recenter button (bottom-right) - Google Maps style
          if (widget.showControls && widget.userLocation != null)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _recenterOnUser,
                backgroundColor: isDark
                    ? Colors.grey[850]
                    : Colors.white,
                elevation: 4,
                child: Icon(
                  Icons.my_location,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),

          // Empty state
          if (widget.tiles.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppColors.border(isDark)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 48,
                      color: AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'No coverage yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary(isDark),
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start tracking to map your area',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
    );

    if (widget.fillScreen) {
      // Edge-to-edge background — no card chrome, expands to fill parent Stack
      return SizedBox.expand(child: mapStack);
    }

    // Card mode — fixed height with border + shadow
    return Container(
      height: MediaQuery.of(context).size.height * widget.heightFraction,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border(isDark), width: 1),
        boxShadow: isDark
            ? AppColors.elevationDark(active: false)
            : AppColors.elevationLight(active: false),
      ),
      clipBehavior: Clip.antiAlias,
      child: mapStack,
    );
  }

  /// Dark mode tile filter
  Widget _darkModeTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.8, 0, 0, 0, 255, // Red
        0, -0.8, 0, 0, 255, // Green
        0, 0, -0.8, 0, 255, // Blue
        0, 0, 0, 1, 0, // Alpha
      ]),
      child: tileWidget,
    );
  }
}
