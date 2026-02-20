import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';
import 'package:latlong2/latlong.dart';
import '../core/extensions/context_extensions.dart';
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
///
/// Base tiles: Carto Dark Matter (dark) / Carto Voyager (light)
/// Free, no API key required, professional dark look used by major mapping apps.
/// H3 polygon overlay is tile-provider-agnostic — works with any base.
class CoverageMapWidget extends StatefulWidget {
  final List<H3Tile> tiles;
  final LatLng? userLocation;
  final double heightFraction; // used only when fillScreen == false
  final bool showControls;
  final bool fillScreen;
  final bool isLoading;
  /// Incrementing this notifier triggers a smooth recenter on [userLocation].
  /// Provider-agnostic: parent never touches MapController directly.
  final ValueNotifier<int>? recenterTrigger;
  /// Extra inset applied to map control widgets (scalebar, compass) so the
  /// parent's overlays (sheet peek, FAB row) don't obscure them.
  /// Pass [EdgeInsets.only(bottom: sheetPeekHeight + margin)] from fillScreen
  /// callers. Defaults to EdgeInsets.zero — no layout knowledge baked in.
  final EdgeInsets controlsPadding;

  const CoverageMapWidget({
    super.key,
    required this.tiles,
    this.userLocation,
    this.heightFraction = 0.5,
    this.showControls = true,
    this.fillScreen = false,
    this.isLoading = false,
    this.recenterTrigger,
    this.controlsPadding = EdgeInsets.zero,
  });

  @override
  State<CoverageMapWidget> createState() => _CoverageMapWidgetState();
}

class _CoverageMapWidgetState extends State<CoverageMapWidget> {
  late MapController _mapController;

  // Polygon cache — recomputed only when widget.tiles changes, never on every build
  List<Polygon> _cachedPolygons = const [];
  bool _hasPolygons = false;

  // Carto basemap URLs — no API key needed, free, professional quality
  // Used by numerous mapping/mobility startups for their clean dark aesthetic.
  // H3 hexagon polygons layer on top of these tiles identically regardless of provider.
  static const _cartoDark =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
  static const _cartoVoyager =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const _cartoSubdomains = ['a', 'b', 'c', 'd'];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    widget.recenterTrigger?.addListener(_onRecenterTrigger);
    _updatePolygonCache();
  }

  @override
  void didUpdateWidget(CoverageMapWidget old) {
    super.didUpdateWidget(old);
    if (old.recenterTrigger != widget.recenterTrigger) {
      old.recenterTrigger?.removeListener(_onRecenterTrigger);
      widget.recenterTrigger?.addListener(_onRecenterTrigger);
    }
    if (!identical(old.tiles, widget.tiles)) {
      _updatePolygonCache();
    }
  }

  void _updatePolygonCache() {
    _cachedPolygons = widget.tiles
        .where((tile) => tile.boundary != null && tile.boundary!.isNotEmpty)
        .map((tile) {
      final opacity = (tile.confidence * 0.55).clamp(0.08, 0.55);
      return Polygon(
        points: tile.boundary!,
        color: AppColors.primary.withValues(alpha: opacity),
        borderColor: AppColors.primary.withValues(alpha: (opacity + 0.15).clamp(0.0, 1.0)),
        borderStrokeWidth: 1.0,
      );
    }).toList();
    _hasPolygons = _cachedPolygons.isNotEmpty;
  }

  @override
  void dispose() {
    widget.recenterTrigger?.removeListener(_onRecenterTrigger);
    _mapController.dispose();
    super.dispose();
  }

  void _onRecenterTrigger() => _recenterOnUser();

  /// Calculate initial map center from tiles + user location.
  /// Falls back to Colmar, France (dev/testing location).
  LatLng _calculateCenter() {
    if (widget.userLocation != null) return widget.userLocation!;

    if (widget.tiles.isNotEmpty) {
      double lat = 0, lng = 0;
      int count = 0;
      for (final tile in widget.tiles) {
        if (tile.boundary != null && tile.boundary!.isNotEmpty) {
          final centroid = tile.boundary![0];
          lat += centroid.latitude;
          lng += centroid.longitude;
          count++;
        }
      }
      if (count > 0) return LatLng(lat / count, lng / count);
    }

    return const LatLng(48.08, 7.36); // Colmar default
  }

  void _recenterOnUser() {
    if (widget.userLocation != null) {
      _mapController.move(widget.userLocation!, _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final center = _calculateCenter();

    // Tile base color behind all layers — prevents white flash while tiles load.
    // Carto Dark Matter renders on near-black; Voyager on warm off-white.
    final tileBackground =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFECE8E0);

    final mapStack = Stack(
      children: [
        // Base color fill — sits below FlutterMap so unloaded tile areas
        // show this instead of transparent/white.
        Positioned.fill(child: ColoredBox(color: tileBackground)),
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
            // ── Base tiles (Carto) ─────────────────────────────────────────
            // Dark Matter: professional dark used by Helium, mobility startups
            // Voyager: clean neutral for light mode
            // Both free, no API key, scales to millions of tiles/month
            TileLayer(
              urlTemplate: isDark ? _cartoDark : _cartoVoyager,
              subdomains: _cartoSubdomains,
              userAgentPackageName: 'com.eremat.greengains',
              maxNativeZoom: 19,
              // More tiles cached around viewport → less white on pan
              keepBuffer: 5,
              panBuffer: 2,
            ),

            // ── Coverage overlay ────────────────────────────────────────────
            // Currently: geohash-approximated circles (16-point polygons)
            // Future: real H3 hexagons — same PolygonLayer API, just different points
            // Polygons are cached in _updatePolygonCache(), rebuilt only on tile changes
            if (_hasPolygons)
              PolygonLayer(polygons: _cachedPolygons),

            // ── User location marker ─────────────────────────────────────────
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
                          border: Border.all(color: Colors.white, width: 3),
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

            // ── Scale bar ───────────────────────────────────────────────────
            // Adapts to dark/light theme; positioned bottom-left so it doesn't
            // clash with the FAB (bottom-right) or My Location button (bottom-left
            // in fillScreen mode — the My Location button is at HomeScreen level
            // so it renders above this and naturally covers any overlap).
            Scalebar(
              alignment: Alignment.bottomLeft,
              padding: EdgeInsets.only(
                left: 12,
                bottom: widget.controlsPadding.bottom + 16,
              ),
              textStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 11,
              ),
              lineColor: isDark ? Colors.white70 : Colors.black87,
              length: ScalebarLength.s,
            ),

            // ── Compass ─────────────────────────────────────────────────────
            // Hidden when map is north-up (hideIfRotatedNorth: true).
            // Top-left avoids the reload button (top-right in HomeScreen).
            MapCompass.cupertino(
              hideIfRotatedNorth: true,
              alignment: Alignment.topLeft,
              padding: EdgeInsets.only(
                top: widget.controlsPadding.top + 10,
                left: 10,
              ),
            ),

            // Attribution (required by Carto + OSM ToS)
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
                TextSourceAttribution('© CARTO'),
              ],
            ),
          ],
        ),

        // ── In card mode: tile count legend + recenter FAB ────────────────
        // These are HIDDEN in fillScreen mode — HomeScreen manages its own
        // overlay layer (TrackingStatusChip + TrackingFab at HomeScreen level).
        if (!widget.fillScreen) ...[
          if (widget.tiles.isNotEmpty)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border(isDark)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hexagon, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.tilesCount(widget.tiles.length),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary(isDark),
                            fontWeight: AppFontWeights.medium,
                          ),
                    ),
                  ],
                ),
              ),
            ),

          if (widget.showControls && widget.userLocation != null)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _recenterOnUser,
                backgroundColor: isDark ? Colors.grey[850] : Colors.white,
                elevation: 4,
                child: Icon(Icons.my_location, color: AppColors.primary, size: 20),
              ),
            ),

          // Empty state (card mode only — full-screen map always shows base tiles)
          if (!widget.isLoading && widget.tiles.isEmpty)
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
                    Icon(Icons.map_outlined,
                        size: 48, color: AppColors.textSecondary(isDark)),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      context.l10n.noCoverageYet,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary(isDark),
                            fontWeight: AppFontWeights.semibold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.startTrackingToMap,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(isDark),
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );

    if (widget.fillScreen) {
      return SizedBox.expand(child: mapStack);
    }

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
}
