import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';
import 'package:latlong2/latlong.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';

/// H3 hexagon tile model
class H3Tile {
  final String h3Index;
  final double confidence; // 0.0–1.0
  final int sampleCount;
  final int deviceCount;
  final List<LatLng>? boundary;
  /// True for community/global tiles (other users); false for personal tiles.
  final bool isGlobal;

  const H3Tile({
    required this.h3Index,
    required this.confidence,
    required this.sampleCount,
    required this.deviceCount,
    this.boundary,
    this.isGlobal = false,
  });
}

/// Coverage map with H3 hexagon heatmap visualization.
///
/// Tile coloring uses the app semantic color palette as a cold→warm gradient:
///   pressure blue → movement teal → quality green → light amber
/// Personal tiles are vivid; community tiles are muted (max 18% opacity).
///
/// When [isTracking] is true and [currentH3Boundary] is provided, the live
/// cell is highlighted in amber to show "scanning now".
///
/// Tap any polygon → [onTileTap] callback with the tapped [H3Tile].
class CoverageMapWidget extends StatefulWidget {
  final List<H3Tile> tiles;
  final LatLng? userLocation;
  /// Pre-computed boundary of the H3 cell the user is currently inside.
  /// Only rendered when [isTracking] is true.
  final List<LatLng>? currentH3Boundary;
  final bool isTracking;
  final void Function(H3Tile tile)? onTileTap;
  final double heightFraction; // used only when fillScreen == false
  final bool showControls;
  final bool fillScreen;
  final bool isLoading;
  final ValueNotifier<int>? recenterTrigger;
  final EdgeInsets controlsPadding;

  const CoverageMapWidget({
    super.key,
    required this.tiles,
    this.userLocation,
    this.currentH3Boundary,
    this.isTracking = false,
    this.onTileTap,
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

  List<Polygon<H3Tile>> _cachedPolygons = const [];
  bool _hasPolygons = false;
  late LatLng _cachedCenter;

  /// Fires when the user taps a polygon — holds the first hit tile.
  final LayerHitNotifier<H3Tile> _hitNotifier = LayerHitNotifier(null);

  // Carto basemap — free, no API key, professional dark used by DePIN apps
  static const _cartoDark =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
  static const _cartoVoyager =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const _cartoSubdomains = ['a', 'b', 'c', 'd'];

  // ── Heatmap palette (cold → warm, mirrors app semantic colors) ─────────────
  // sampleCount 0   → transparent (no fill until data exists)
  // sampleCount 1–2 → pressure blue  #0ea5e9
  // sampleCount 3–5 → movement teal  #14b8a6
  // sampleCount 6–9 → quality green  #10b981
  // sampleCount 10+ → light amber    #fbbf24
  static Color _tileColor(int sampleCount, {bool isGlobal = false}) {
    final Color base;
    if (sampleCount >= 10) {
      base = AppColors.light;      // amber  — very dense coverage
    } else if (sampleCount >= 6) {
      base = AppColors.quality;    // green  — solid coverage
    } else if (sampleCount >= 3) {
      base = AppColors.movement;   // teal   — moderate coverage
    } else {
      base = AppColors.pressure;   // blue   — sparse coverage
    }
    return base;
  }

  static double _tileFillOpacity(int sampleCount, {bool isGlobal = false}) {
    if (isGlobal) {
      // Community tiles: very subtle, max 18%
      return (sampleCount >= 5 ? 0.18 : 0.10);
    }
    if (sampleCount >= 10) return 0.65;
    if (sampleCount >= 6)  return 0.52;
    if (sampleCount >= 3)  return 0.40;
    return 0.28;
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    widget.recenterTrigger?.addListener(_onRecenterTrigger);
    _updatePolygonCache();
    _cachedCenter = _calculateCenter();
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
    if (!identical(old.tiles, widget.tiles) ||
        old.userLocation != widget.userLocation) {
      _cachedCenter = _calculateCenter();
    }
  }

  void _updatePolygonCache() {
    _cachedPolygons = widget.tiles
        .where((t) => t.boundary != null && t.boundary!.isNotEmpty)
        .map((tile) {
      final color = _tileColor(tile.sampleCount, isGlobal: tile.isGlobal);
      final fillOpacity =
          _tileFillOpacity(tile.sampleCount, isGlobal: tile.isGlobal);
      final borderOpacity = (fillOpacity + 0.15).clamp(0.0, 1.0);
      return Polygon<H3Tile>(
        points: tile.boundary!,
        color: color.withValues(alpha: fillOpacity),
        borderColor: color.withValues(alpha: borderOpacity),
        borderStrokeWidth: tile.isGlobal ? 0.6 : 1.0,
        hitValue: tile,
      );
    }).toList();
    _hasPolygons = _cachedPolygons.isNotEmpty;
  }

  @override
  void dispose() {
    widget.recenterTrigger?.removeListener(_onRecenterTrigger);
    _hitNotifier.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onRecenterTrigger() => _recenterOnUser();

  LatLng _calculateCenter() {
    if (widget.userLocation != null) return widget.userLocation!;
    if (widget.tiles.isNotEmpty) {
      double lat = 0, lng = 0;
      int count = 0;
      for (final tile in widget.tiles) {
        if (tile.boundary != null && tile.boundary!.isNotEmpty) {
          lat += tile.boundary![0].latitude;
          lng += tile.boundary![0].longitude;
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

  void _handleMapTap(TapPosition tapPos, LatLng latlng) {
    final hit = _hitNotifier.value;
    if (hit != null && hit.hitValues.isNotEmpty) {
      widget.onTileTap?.call(hit.hitValues.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final center = _cachedCenter;
    final tileBackground =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFECE8E0);

    final showLiveCell = widget.isTracking &&
        widget.currentH3Boundary != null &&
        widget.currentH3Boundary!.isNotEmpty;

    final mapStack = Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: tileBackground)),
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.0,
            minZoom: 5.0,
            maxZoom: 18.0,
            onTap: _handleMapTap,
            interactionOptions: InteractionOptions(
              flags: widget.showControls
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            // ── Base map ──────────────────────────────────────────────────
            TileLayer(
              urlTemplate: isDark ? _cartoDark : _cartoVoyager,
              subdomains: _cartoSubdomains,
              userAgentPackageName: 'com.eremat.greengains',
              maxNativeZoom: 19,
              keepBuffer: 5,
              panBuffer: 2,
            ),

            // ── Community + personal heatmap polygons ─────────────────────
            if (_hasPolygons)
              PolygonLayer<H3Tile>(
                polygons: _cachedPolygons,
                hitNotifier: _hitNotifier,
              ),

            // ── Live scan cell (amber highlight, top layer) ───────────────
            if (showLiveCell)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: widget.currentH3Boundary!,
                    color: AppColors.light.withValues(alpha: 0.22),
                    borderColor: AppColors.light.withValues(alpha: 0.9),
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),

            // ── User location dot ─────────────────────────────────────────
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

            // ── Scalebar ──────────────────────────────────────────────────
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

            // ── Compass ───────────────────────────────────────────────────
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

        // ── Card-mode controls (hidden in fillScreen) ─────────────────────
        if (!widget.fillScreen) ...[
          if (widget.tiles.isNotEmpty)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                child:
                    Icon(Icons.my_location, color: AppColors.primary, size: 20),
              ),
            ),

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

// ── Map legend (compact, top-right) ─────────────────────────────────────────

/// Compact heatmap legend showing coverage intensity scale.
/// Only shown in fullScreen mode via HomeScreen overlay.
class MapHeatmapLegend extends StatelessWidget {
  const MapHeatmapLegend({super.key, required this.hasCommunityTiles});
  final bool hasCommunityTiles;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppColors.border(isDark).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendDot(color: AppColors.light,    label: '10+'),
          const SizedBox(height: 4),
          _LegendDot(color: AppColors.quality,  label: '6–9'),
          const SizedBox(height: 4),
          _LegendDot(color: AppColors.movement, label: '3–5'),
          const SizedBox(height: 4),
          _LegendDot(color: AppColors.pressure, label: '1–2'),
          if (hasCommunityTiles) ...[
            Divider(height: 10, color: AppColors.border(isDark)),
            _LegendDot(
              color: AppColors.pressure.withValues(alpha: 0.5),
              label: context.l10n.tileInfoCommunity,
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet shown when user taps a coverage tile.
class TileInfoSheet extends StatelessWidget {
  const TileInfoSheet({super.key, required this.tile});
  final H3Tile tile;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final isPersonal = !tile.isGlobal;
    final accentColor = isPersonal ? AppColors.quality : AppColors.pressure;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary(isDark).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceMd),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceXs),
                  Text(
                    isPersonal ? l10n.tileInfoPersonal : l10n.tileInfoCommunity,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary(isDark),
                          fontWeight: AppFontWeights.semibold,
                        ),
                  ),
                ],
              ),
            ),

            // Stats row
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, 0,
                  AppTheme.spaceMd, AppTheme.spaceLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    value: '${tile.sampleCount}',
                    label: l10n.tileInfoSamples(tile.sampleCount),
                    isDark: isDark,
                  ),
                  _StatItem(
                    value: '${(tile.confidence * 100).round()}%',
                    label: l10n.tileInfoConfidence,
                    isDark: isDark,
                  ),
                  _StatItem(
                    value: '${tile.deviceCount}',
                    label: l10n.tileInfoDevices(tile.deviceCount),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.isDark,
  });
  final String value;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary(isDark),
                fontWeight: AppFontWeights.semibold,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }
}
