import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:h3_flutter/h3_flutter.dart' as h3f;
import 'package:latlong2/latlong.dart' as ll;
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';

// ── Background isolate grid computation ──────────────────────────────────────

typedef _GridInput = ({
  double centerLat,
  double centerLon,
  int resolution,
  int k,
});

/// Disk radius `k` by H3 resolution — keeps cell count ≤ 127.
/// | res | k | cells | approx radius |
/// |  9  | 6 |  127  |     ~1 km     |
/// |  8  | 5 |   91  |    ~2.3 km    |
/// |  7  | 4 |   61  |    ~4.9 km    |
/// | 4–6 | 3 |   37  |  ~10–100 km   |
int _gridDiskK(int res) {
  if (res >= 9) return 6;
  if (res == 8) return 5;
  if (res == 7) return 4;
  return 3;
}

/// Top-level function so compute() can spawn it in a background isolate.
/// Uses gridDisk(centerCell, k) so the ghost grid is stable across pans —
/// the same cells stay visible until the camera crosses a cell boundary,
/// eliminating the pop-in/pop-out jank of polygonToCells (Nodle/Helium style).
/// h3_flutter uses DynamicLibrary.process() — safe in compute() isolates.
Map<String, dynamic> _buildGrid(_GridInput input) {
  final h3 = const h3f.H3Factory().load();
  final centerCell = h3.geoToCell(
    h3f.GeoCoord(lat: input.centerLat, lon: input.centerLon),
    input.resolution,
  );
  final cells = h3.gridDisk(centerCell, input.k);
  if (cells.isEmpty) return {'type': 'FeatureCollection', 'features': <dynamic>[]};

  final features = cells.take(500).map((cell) {
    final boundary = h3.cellToBoundary(cell);
    final ring = [
      ...boundary.map((c) => [c.lon, c.lat]),
      [boundary.first.lon, boundary.first.lat],
    ];
    return <String, dynamic>{
      'type': 'Feature',
      'properties': <String, dynamic>{},
      'geometry': <String, dynamic>{
        'type': 'Polygon',
        'coordinates': [ring],
      },
    };
  }).toList();
  return {'type': 'FeatureCollection', 'features': features};
}

/// H3 hexagon tile model
class H3Tile {
  final String h3Index;
  final double confidence; // 0.0–1.0
  final int sampleCount;
  final int deviceCount;
  final List<ll.LatLng>? boundary;
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

// ── Timing constants ──────────────────────────────────────────────────────────
/// Camera-idle debounce before recomputing the ghost grid.
/// 500ms is intentional — slower than UI animations to avoid thrashing FFI.
const _kGridDebounce = Duration(milliseconds: 500);

// ── Layer / source ID constants ───────────────────────────────────────────────
const _kSourceGrid      = 'gg-grid';
const _kSourceTiles     = 'gg-tiles';
const _kSourceLiveCell  = 'gg-live';
const _kSourceUserDot   = 'gg-user';
const _kLayerGridLines  = 'gg-grid-lines';
const _kLayerTilesFill  = 'gg-tiles-fill';
const _kLayerTilesLine  = 'gg-tiles-line';
const _kLayerLiveFill   = 'gg-live-fill';
const _kLayerLiveLine   = 'gg-live-line';
const _kLayerUserHalo   = 'gg-user-halo';
const _kLayerUserDot    = 'gg-user-dot';

/// Returns H3 resolution appropriate for the current zoom level.
/// Mapping is 3 levels coarser than naive (1:1) to keep cell count manageable
/// and match DePIN industry practice (Helium res 8 at zoom ~14).
int _gridRes(double zoom) {
  if (zoom >= 15) return 9;
  if (zoom >= 14) return 8;
  if (zoom >= 13) return 7;
  if (zoom >= 12) return 6;
  if (zoom >= 10) return 5;
  return 4; // zoom 8-9 (layer won't render below minzoom 9 anyway)
}


/// Protomaps API key — injected at build time via --dart-define-from-file.
const _kProtomapsKey =
    String.fromEnvironment('PROTOMAPS_KEY', defaultValue: '');

/// Empty GeoJSON feature collection (initial state for all sources).
final _kEmptyFC = <String, dynamic>{
  'type': 'FeatureCollection',
  'features': <dynamic>[],
};

/// Coverage map powered by MapLibre GL + Protomaps vector tiles (or CartoDB
/// raster fallback when no Protomaps key is available).
///
/// Layer stack (bottom → top):
///   vector/raster base map
///   ghost H3 grid — faint white outlines covering the entire viewport
///   data fill — personal + community H3 tiles with heatmap colors
///   data borders — tile outlines
///   live cell — amber highlight for the cell being scanned now
///   user halo — translucent ring around user position
///   user dot — solid green circle + white stroke
///
/// All hex layers are placed BELOW the label tiles so street names and place
/// labels float above the hexagons (Helium/Nodle DePIN depth effect).
class CoverageMapWidget extends StatefulWidget {
  final List<H3Tile> tiles;
  final ll.LatLng? userLocation;
  /// Pre-computed boundary of the H3 cell the user is currently inside.
  /// Only rendered when [isTracking] is true.
  final List<ll.LatLng>? currentH3Boundary;
  final bool isTracking;
  final void Function(H3Tile tile)? onTileTap;
  final double heightFraction;
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
  MapLibreMapController? _ctrl;
  bool _styleLoaded = false;
  bool _pendingStyleLoad = false; // style fired before _ctrl was ready
  final Map<String, H3Tile> _tileById = {};
  Timer? _gridTimer;
  int _gridGeneration = 0;   // incremented on each refresh; stale results are discarded
  String? _lastGridCenterCell; // H3 cell hex string of last computed grid center
  int _lastGridZoom = -1;      // floor(zoom) at last grid compute

  // ── Style URL / JSON ────────────────────────────────────────────────────────

  // DePIN apps (Helium, Nodle, Hivemapper) always force dark map — never follow
  // system theme. The dark base is what makes hex overlays readable and the
  // whole aesthetic work.
  String _styleUrl(bool isDark) {
    if (_kProtomapsKey.isNotEmpty) {
      return 'https://api.protomaps.com/styles/v4/dark/en.json?key=$_kProtomapsKey';
    }
    return _cartoFallbackStyle(true); // force dark fallback too
  }

  static String _cartoFallbackStyle(bool isDark) {
    final base = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
    final sources = <String, dynamic>{
      'carto-base': {
        'type': 'raster',
        'tiles': [
          base.replaceAll('{s}', 'a'),
          base.replaceAll('{s}', 'b'),
          base.replaceAll('{s}', 'c'),
        ],
        'tileSize': 256,
        'attribution': '© CARTO © OpenStreetMap contributors',
      },
      if (isDark)
        'carto-labels': {
          'type': 'raster',
          'tiles': [
            'https://a.basemaps.cartocdn.com/dark_only_labels/{z}/{x}/{y}.png',
          ],
          'tileSize': 256,
        },
    };
    final layers = <Map<String, dynamic>>[
      {
        'id': 'bg',
        'type': 'background',
        'paint': {'background-color': isDark ? '#111927' : '#F4F1EB'},
      },
      {'id': 'carto-base', 'type': 'raster', 'source': 'carto-base'},
      // Labels layer is added AFTER hex layers via addLayer so it appears on top
    ];
    return jsonEncode({'version': 8, 'sources': sources, 'layers': layers});
  }

  // ── GeoJSON builders ────────────────────────────────────────────────────────

  Map<String, dynamic> _tilesToGeoJson() {
    _tileById.clear();
    final features = <Map<String, dynamic>>[];
    for (final tile in widget.tiles) {
      if (tile.boundary == null || tile.boundary!.isEmpty) continue;
      _tileById[tile.h3Index] = tile;
      final fill = _fillOpacity(tile.sampleCount, isGlobal: tile.isGlobal);
      features.add({
        'type': 'Feature',
        'properties': {
          'h3Index': tile.h3Index,
          'color': _colorHex(tile.sampleCount, isGlobal: tile.isGlobal),
          'fillOpacity': fill,
          'borderOpacity': (fill + 0.15).clamp(0.0, 1.0),
          'borderWidth': tile.isGlobal ? 0.5 : 1.2,
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            tile.boundary!
                .map((ll.LatLng p) => [p.longitude, p.latitude])
                .toList(),
          ],
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  Map<String, dynamic> _liveCellGeoJson() {
    // Show the current cell whenever we have a boundary (running OR paused).
    // isTracking drives opacity in the layer paint, not visibility here.
    if (widget.currentH3Boundary == null) {
      return _kEmptyFC;
    }
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                ...widget.currentH3Boundary!
                    .map((ll.LatLng p) => [p.longitude, p.latitude]),
                // h3_flutter does not auto-close rings — close it manually
                [widget.currentH3Boundary!.first.longitude,
                 widget.currentH3Boundary!.first.latitude],
              ],
            ],
          },
        },
      ],
    };
  }

  Map<String, dynamic> _userDotGeoJson() {
    final loc = widget.userLocation;
    if (loc == null) return _kEmptyFC;
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {},
          'geometry': {
            'type': 'Point',
            'coordinates': [loc.longitude, loc.latitude],
          },
        },
      ],
    };
  }

  // ── Heatmap palette (pressure blue → movement teal → quality green → light amber) ──

  static String _colorHex(int count, {bool isGlobal = false}) {
    if (count >= 10) return '#fbbf24'; // AppColors.light  — amber
    if (count >= 6)  return '#10b981'; // AppColors.quality — green
    if (count >= 3)  return '#14b8a6'; // AppColors.movement — teal
    return '#0ea5e9';                  // AppColors.pressure — blue
  }

  static double _fillOpacity(int count, {bool isGlobal = false}) {
    if (isGlobal) return count >= 5 ? 0.25 : 0.15;
    if (count >= 10) return 0.82;
    if (count >= 6)  return 0.70;
    if (count >= 3)  return 0.58;
    return 0.45;
  }

  // ── MapLibre lifecycle ──────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) {
    _ctrl = controller;
    widget.recenterTrigger?.addListener(_onRecenter);
    // Style may have loaded from cache before _ctrl was assigned — flush pending
    if (_pendingStyleLoad) {
      _pendingStyleLoad = false;
      _onStyleLoaded();
    }
  }

  void _onRecenter() {
    if (widget.userLocation == null || _ctrl == null) return;
    _ctrl!.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(widget.userLocation!.latitude, widget.userLocation!.longitude),
      ),
    );
  }

  Future<void> _onStyleLoaded() async {
    final ctrl = _ctrl;
    if (ctrl == null) {
      debugPrint('MapLibre: style loaded before _ctrl ready — deferring');
      _pendingStyleLoad = true;
      return;
    }
    _styleLoaded = true;
    debugPrint('MapLibre: style loaded OK, adding GeoJSON sources + layers...');

    // ── Add sources (empty, populated below) ──
    await Future.wait([
      ctrl.addGeoJsonSource(_kSourceGrid, _kEmptyFC),
      ctrl.addGeoJsonSource(_kSourceTiles, _kEmptyFC),
      ctrl.addGeoJsonSource(_kSourceLiveCell, _kEmptyFC),
      ctrl.addGeoJsonSource(_kSourceUserDot, _kEmptyFC),
    ]);

    // ── Ghost grid — white outlines (only visible at zoom ≥ 9 to avoid ANR) ──
    await ctrl.addLineLayer(
      _kSourceGrid,
      _kLayerGridLines,
      const LineLayerProperties(
        lineColor: '#ffffff',
        lineOpacity: 0.45,
        lineWidth: 1.0,
      ),
      minzoom: 9.0,
    );

    // ── Data tiles fill ──
    await ctrl.addFillLayer(
      _kSourceTiles,
      _kLayerTilesFill,
      const FillLayerProperties(
        fillColor: ['get', 'color'],
        fillOpacity: ['get', 'fillOpacity'],
      ),
      enableInteraction: true,
    );

    // ── Data tiles border ──
    await ctrl.addLineLayer(
      _kSourceTiles,
      _kLayerTilesLine,
      const LineLayerProperties(
        lineColor: ['get', 'color'],
        lineOpacity: ['get', 'borderOpacity'],
        lineWidth: ['get', 'borderWidth'],
      ),
    );

    // ── Live cell (amber) ──
    await ctrl.addFillLayer(
      _kSourceLiveCell,
      _kLayerLiveFill,
      const FillLayerProperties(
        fillColor: '#fbbf24',
        fillOpacity: 0.28,
      ),
    );
    await ctrl.addLineLayer(
      _kSourceLiveCell,
      _kLayerLiveLine,
      const LineLayerProperties(
        lineColor: '#fbbf24',
        lineOpacity: 0.95,
        lineWidth: 2.0,
      ),
    );

    // ── User location — halo ring + solid dot ──
    await ctrl.addCircleLayer(
      _kSourceUserDot,
      _kLayerUserHalo,
      const CircleLayerProperties(
        circleRadius: 16.0,
        circleColor: '#10b981',
        circleOpacity: 0.18,
        circleStrokeWidth: 0,
      ),
    );
    await ctrl.addCircleLayer(
      _kSourceUserDot,
      _kLayerUserDot,
      const CircleLayerProperties(
        circleRadius: 7.0,
        circleColor: '#10b981',
        circleOpacity: 1.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: '#ffffff',
      ),
    );

    debugPrint('MapLibre: all layers added — populating sources...');
    // ── Populate sources ──
    await _refreshAllSources();
    // Wait for MapLibre camera + viewport to fully settle before grid
    await Future<void>.delayed(AppDurations.medium);
    await _refreshGrid();
    debugPrint('MapLibre: initial grid + sources populated');
  }

  Future<void> _refreshAllSources() async {
    final ctrl = _ctrl;
    if (!_styleLoaded || ctrl == null) return;

    // Live cell dims when paused but stays visible so user sees their position.
    final liveFillOpacity = widget.isTracking ? 0.28 : 0.10;
    final liveLineOpacity = widget.isTracking ? 0.95 : 0.35;

    await Future.wait([
      ctrl.setGeoJsonSource(_kSourceTiles, _tilesToGeoJson()),
      ctrl.setGeoJsonSource(_kSourceLiveCell, _liveCellGeoJson()),
      ctrl.setGeoJsonSource(_kSourceUserDot, _userDotGeoJson()),
      ctrl.setLayerProperties(_kLayerLiveFill, FillLayerProperties(fillOpacity: liveFillOpacity)),
      ctrl.setLayerProperties(_kLayerLiveLine, LineLayerProperties(lineOpacity: liveLineOpacity)),
    ]);
  }

  Future<void> _refreshGrid() async {
    final ctrl = _ctrl;
    if (!_styleLoaded || ctrl == null) return;

    final zoom = ctrl.cameraPosition?.zoom ?? 13.0;
    if (zoom < 9.0) return; // below layer minzoom — skip

    final center = ctrl.cameraPosition?.target;
    if (center == null) return;

    final res = _gridRes(zoom);
    final zoomInt = zoom.floor();

    // Single geoToCell call on the main thread — cheap FFI, determines if
    // the camera has moved to a different H3 cell since the last grid render.
    // If still in the same cell at the same zoom level, the existing grid is
    // already correct and no recompute is needed (Nodle/Helium stable-grid pattern).
    final h3 = const h3f.H3Factory().load();
    final centerCell = h3.geoToCell(
      h3f.GeoCoord(lat: center.latitude, lon: center.longitude),
      res,
    );
    final cellStr = centerCell.toRadixString(16);

    if (cellStr == _lastGridCenterCell && zoomInt == _lastGridZoom) return;
    _lastGridCenterCell = cellStr;
    _lastGridZoom = zoomInt;

    final gen = ++_gridGeneration;

    Map<String, dynamic> geojson;
    try {
      geojson = await compute(_buildGrid, (
        centerLat: center.latitude,
        centerLon: center.longitude,
        resolution: res,
        k: _gridDiskK(res),
      ));
    } catch (e) {
      debugPrint('MapLibre: grid compute error: $e');
      return;
    }

    // Discard if camera moved again while compute() was running
    if (gen != _gridGeneration || !_styleLoaded || _ctrl == null) return;
    await ctrl.setGeoJsonSource(_kSourceGrid, geojson);
    debugPrint('MapLibre: grid ${(geojson["features"] as List).length} cells at res $res (zoom ${zoom.toStringAsFixed(1)})');
  }

  void _scheduleGridRefresh() {
    _gridTimer?.cancel();
    _gridTimer = Timer(_kGridDebounce, _refreshGrid);
  }

  void _onMapTap(Point<double> point, LatLng coords) async {
    final ctrl = _ctrl;
    if (ctrl == null || widget.onTileTap == null) return;
    final features =
        await ctrl.queryRenderedFeatures(point, [_kLayerTilesFill], null);
    if (features.isEmpty) return;
    final props = (features.first as Map<Object?, Object?>?)
        ?['properties'] as Map<Object?, Object?>?;
    final h3Index = props?['h3Index'] as String?;
    if (h3Index != null && _tileById.containsKey(h3Index)) {
      widget.onTileTap!(_tileById[h3Index]!);
    }
  }

  // ── Widget lifecycle ────────────────────────────────────────────────────────

  @override
  void didUpdateWidget(CoverageMapWidget old) {
    super.didUpdateWidget(old);
    if (old.recenterTrigger != widget.recenterTrigger) {
      old.recenterTrigger?.removeListener(_onRecenter);
      widget.recenterTrigger?.addListener(_onRecenter);
    }
    if (!_styleLoaded) return;

    final tilesChanged = !identical(old.tiles, widget.tiles);
    final locationChanged = old.userLocation != widget.userLocation;
    final liveChanged = !identical(
          old.currentH3Boundary,
          widget.currentH3Boundary,
        ) ||
        old.isTracking != widget.isTracking;

    if (tilesChanged || locationChanged || liveChanged) {
      _refreshAllSources();
    }
  }

  @override
  void dispose() {
    _gridTimer?.cancel();
    widget.recenterTrigger?.removeListener(_onRecenter);
    super.dispose();
  }

  LatLng get _initialCenter {
    if (widget.userLocation != null) {
      return LatLng(
        widget.userLocation!.latitude,
        widget.userLocation!.longitude,
      );
    }
    return const LatLng(48.08, 7.36); // Colmar default
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mapWidget = MapLibreMap(
      key: const ValueKey('map'), // stable key — always dark style
      initialCameraPosition: CameraPosition(
        target: _initialCenter,
        zoom: 14.0,
      ),
      styleString: _styleUrl(isDark),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraIdle: _scheduleGridRefresh,
      onMapClick: widget.showControls ? _onMapTap : null,
      compassEnabled: widget.showControls,
      rotateGesturesEnabled: widget.showControls,
      scrollGesturesEnabled: widget.showControls,
      zoomGesturesEnabled: widget.showControls,
      tiltGesturesEnabled: false,
      myLocationEnabled: false,
    );

    final mapStack = Stack(
      children: [
        mapWidget,

        // ── No-data placeholder (card mode) ───────────────────────────────
        if (!widget.fillScreen && !widget.isLoading && widget.tiles.isEmpty)
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

        // ── Tile count badge (card mode) ──────────────────────────────────
        if (!widget.fillScreen && widget.tiles.isNotEmpty)
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
      ],
    );

    if (widget.fillScreen) return SizedBox.expand(child: mapStack);

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

// ── Map legend ────────────────────────────────────────────────────────────────

/// Compact heatmap legend showing coverage intensity scale.
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
          _LegendDot(color: const Color(0xFFfbbf24), label: '10+'),
          const SizedBox(height: 4),
          _LegendDot(color: const Color(0xFF10b981), label: '6–9'),
          const SizedBox(height: 4),
          _LegendDot(color: const Color(0xFF14b8a6), label: '3–5'),
          const SizedBox(height: 4),
          _LegendDot(color: const Color(0xFF0ea5e9), label: '1–2'),
          if (hasCommunityTiles) ...[
            Divider(height: 10, color: AppColors.border(isDark)),
            _LegendDot(
              color: const Color(0xFF0ea5e9).withValues(alpha: 0.5),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

// ── Tile info bottom sheet ────────────────────────────────────────────────────

/// Bottom sheet shown when user taps a coverage tile.
class TileInfoSheet extends StatelessWidget {
  const TileInfoSheet({super.key, required this.tile});
  final H3Tile tile;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final isPersonal = !tile.isGlobal;
    final accentColor =
        isPersonal ? const Color(0xFF10b981) : const Color(0xFF0ea5e9);

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
                color:
                    AppColors.textSecondary(isDark).withValues(alpha: 0.3),
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
                        color: accentColor, shape: BoxShape.circle),
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
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    value: '${tile.sampleCount}',
                    label: l10n.tileInfoSamplesLabel,
                    isDark: isDark,
                  ),
                  _StatItem(
                    value: '${(tile.confidence * 100).round()}%',
                    label: l10n.tileInfoConfidence,
                    isDark: isDark,
                  ),
                  _StatItem(
                    value: '${tile.deviceCount}',
                    label: l10n.tileInfoDevicesLabel,
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
