import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:h3_flutter/h3_flutter.dart' as h3f;
import 'package:latlong2/latlong.dart' as ll;
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../data/models/h3_tile.dart';

export '../data/models/h3_tile.dart';

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
const _kLayerTilesLabel = 'gg-tiles-label';
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
  bool _hasCenteredOnUser = false; // true after first auto-center on GPS fix
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
      final color = _colorHex(tile);
      // Centroid = average of boundary points — used for label placement
      final lats = tile.boundary!.map((p) => p.latitude);
      final lngs = tile.boundary!.map((p) => p.longitude);
      final cLat = lats.reduce((a, b) => a + b) / tile.boundary!.length;
      final cLng = lngs.reduce((a, b) => a + b) / tile.boundary!.length;
      features.add({
        'type': 'Feature',
        'properties': {
          'h3Index': tile.h3Index,
          'color': color,
          'fillOpacity': _fillOpacity(tile),
          'borderOpacity': _strokeOpacity(tile),
          'borderWidth': tile.isGlobal ? 0.0 : 1.8,
          // Label: quality % for personal, nothing for global (too cluttered)
          'label': tile.isGlobal ? '' : '${_qualityPct(tile)}%',
          'centLng': cLng,
          'centLat': cLat,
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              ...tile.boundary!.map((ll.LatLng p) => [p.longitude, p.latitude]),
              [tile.boundary!.first.longitude, tile.boundary!.first.latitude],
            ],
          ],
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Separate point GeoJSON for hex labels — MapLibre symbol layers need Point geometry.
  Map<String, dynamic> _tileLabelsGeoJson() {
    final features = <Map<String, dynamic>>[];
    for (final tile in widget.tiles) {
      if (tile.isGlobal || tile.boundary == null || tile.boundary!.isEmpty) continue;
      final lats = tile.boundary!.map((p) => p.latitude);
      final lngs = tile.boundary!.map((p) => p.longitude);
      final cLat = lats.reduce((a, b) => a + b) / tile.boundary!.length;
      final cLng = lngs.reduce((a, b) => a + b) / tile.boundary!.length;
      features.add({
        'type': 'Feature',
        'properties': {
          'label': '${_qualityPct(tile)}%',
          'color': _colorHex(tile),
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [cLng, cLat],
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

  // ── Quality-based palette ─────────────────────────────────────────────────
  // Colors communicate data quality — universally readable regardless of sensor
  // type. Green = high quality, yellow = medium, red = poor.
  // Global tiles are slightly dimmer so personal tiles always read as "yours".

  /// Returns the effective quality score (0–100) for a tile.
  /// Uses qualityScore when available (global tiles), confidence otherwise.
  static int _qualityPct(H3Tile tile) {
    if (tile.qualityScore != null) return (tile.qualityScore! * 100).round();
    return (tile.confidence * 100).round();
  }

  static String _colorHex(H3Tile tile) {
    final q = _qualityPct(tile);
    if (tile.isGlobal) {
      // Muted versions — community context, not personal territory
      if (q >= 75) return '#059669'; // emerald-600
      if (q >= 50) return '#b45309'; // amber-700
      return '#b91c1c';              // red-700
    }
    if (q >= 75) return '#10b981';   // emerald-500 — high quality
    if (q >= 50) return '#fbbf24';   // amber-400   — medium
    return '#ef4444';                // red-400     — poor
  }

  static double _fillOpacity(H3Tile tile) {
    if (tile.isGlobal) return 0.16;
    final q = _qualityPct(tile);
    if (q >= 75) return 0.28;
    if (q >= 50) return 0.24;
    return 0.20;
  }

  static double _strokeOpacity(H3Tile tile) {
    if (tile.isGlobal) return 0.0;
    final q = _qualityPct(tile);
    if (q >= 75) return 0.90;
    if (q >= 50) return 0.75;
    return 0.60;
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
      ctrl.addGeoJsonSource('gg-tile-labels', _kEmptyFC),
    ]);

    // ── Ghost grid — faint outlines (only visible at zoom ≥ 9 to avoid ANR) ──
    await ctrl.addLineLayer(
      _kSourceGrid,
      _kLayerGridLines,
      const LineLayerProperties(
        lineColor: '#7dd3fc', // sky-blue tint — more readable than pure white on dark
        lineOpacity: 0.25,
        lineWidth: 0.8,
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
      minzoom: 9.0,
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
      minzoom: 9.0,
    );

    // ── Hex quality labels — shown at zoom ≥ 12, personal tiles only ──
    await ctrl.addSymbolLayer(
      'gg-tile-labels',
      _kLayerTilesLabel,
      const SymbolLayerProperties(
        textField: ['get', 'label'],
        textColor: ['get', 'color'],
        textSize: 10.0,
        textFont: ['DIN Offc Pro Medium', 'Arial Unicode MS Regular'],
        textAllowOverlap: false,
        textIgnorePlacement: false,
      ),
      minzoom: 12.0,
    );

    // ── Live cell (amber — same as AppColors.light) ──
    await ctrl.addFillLayer(
      _kSourceLiveCell,
      _kLayerLiveFill,
      const FillLayerProperties(
        fillColor: AppColors.lightHex,
        fillOpacity: 0.28,
      ),
    );
    await ctrl.addLineLayer(
      _kSourceLiveCell,
      _kLayerLiveLine,
      const LineLayerProperties(
        lineColor: AppColors.lightHex,
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
        circleColor: AppColors.primaryHex,
        circleOpacity: 0.18,
        circleStrokeWidth: 0,
      ),
    );
    await ctrl.addCircleLayer(
      _kSourceUserDot,
      _kLayerUserDot,
      const CircleLayerProperties(
        circleRadius: 7.0,
        circleColor: AppColors.primaryHex,
        circleOpacity: 1.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: '#ffffff',
      ),
    );

    // ── Carto labels on top — street names / city names float above hexagons ──
    // Only needed for the CartoDB raster fallback (no Protomaps key).
    // The source is already in the style JSON; we add the layer here so it
    // sits above all hex layers (fill, line, live cell, user dot).
    if (_kProtomapsKey.isEmpty) {
      try {
        await ctrl.addRasterLayer(
          'carto-labels',
          'gg-carto-labels',
          const RasterLayerProperties(),
        );
      } catch (e) {
        debugPrint('MapLibre: carto-labels layer skipped ($e)');
      }
    }

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
      ctrl.setGeoJsonSource('gg-tile-labels', _tileLabelsGeoJson()),
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

    // First GPS fix after map init — auto-center once, silently.
    // initialCameraPosition is frozen at build time so if location wasn't
    // available yet (common on cold start) we move the camera here instead.
    if (!_hasCenteredOnUser &&
        old.userLocation == null &&
        widget.userLocation != null &&
        _ctrl != null) {
      _hasCenteredOnUser = true;
      _ctrl!.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(
            widget.userLocation!.latitude,
            widget.userLocation!.longitude,
          ),
          zoom: 14.0,
        )),
      );
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
    final topInset = MediaQuery.paddingOf(context).top;

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
      compassEnabled: widget.showControls && widget.fillScreen,
      compassViewPosition: CompassViewPosition.topRight,
      compassViewMargins: widget.fillScreen
          ? Point<double>(12, topInset + widget.controlsPadding.top > 0
              ? widget.controlsPadding.top
              : topInset + 8)
          : const Point<double>(12, 12),
      rotateGesturesEnabled: widget.showControls,
      scrollGesturesEnabled: widget.showControls,
      zoomGesturesEnabled: widget.showControls,
      tiltGesturesEnabled: false,
      myLocationEnabled: false,
    );

    final mapStack = Stack(
      children: [
        mapWidget,

        // ── Loading overlay (all modes) ───────────────────────────────────
        if (widget.isLoading)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              strokeWidth: 2.5,
            ),
          ),

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
    // Legend always floats over the dark map — always dark glass.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppTheme.glassBlurSigma, sigmaY: AppTheme.glassBlurSigma),
        child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: AppColors.glassDecoration(isDark: true, backgroundAlpha: 0.50, borderAlpha: 0.12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendDot(color: AppColors.quality,  label: '≥75%'),
          const SizedBox(height: 4),
          _LegendDot(color: AppColors.light,    label: '50–74%'),
          const SizedBox(height: 4),
          _LegendDot(color: const Color(0xFFef4444), label: '<50%'),
          if (hasCommunityTiles) ...[
            Divider(height: 10, color: Colors.white24),
            _LegendDot(
              color: AppColors.community.withValues(alpha: 0.7),
              label: context.l10n.tileInfoCommunity,
            ),
          ],
        ],
      ),
        ),
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

    final qualityPct = tile.qualityScore != null
        ? (tile.qualityScore! * 100).round()
        : (tile.confidence * 100).round();
    final qualityColor = qualityPct >= 75
        ? AppColors.quality
        : qualityPct >= 50
            ? AppColors.light
            : AppColors.error;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border(
          top: BorderSide(color: qualityColor, width: 3),
          left: BorderSide(color: AppColors.border(isDark)),
          right: BorderSide(color: AppColors.border(isDark)),
          bottom: BorderSide(color: AppColors.border(isDark)),
        ),
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
            // Title + quality badge row
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceMd),
              child: Row(
                children: [
                  Text(
                    isPersonal ? l10n.tileInfoPersonal : l10n.tileInfoCommunity,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary(isDark),
                          fontWeight: AppFontWeights.semibold,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXxxs),
                    decoration: BoxDecoration(
                      color: qualityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      '$qualityPct%',
                      style: TextStyle(
                        color: qualityColor,
                        fontSize: 12,
                        fontWeight: AppFontWeights.bold,
                      ),
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
