import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:h3_flutter/h3_flutter.dart' as h3f;
import 'package:latlong2/latlong.dart' as ll;
import 'package:dart_geohash/dart_geohash.dart';
import 'package:intl/intl.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../data/local/database_helper.dart';
import '../data/models/h3_tile.dart';
import '../core/app_preferences.dart';
import '../core/sensor_insights.dart';
import '../l10n/app_localizations.dart';
import 'time_ago_text.dart';

export '../data/models/h3_tile.dart';

// ── Background isolate grid computation ──────────────────────────────────────

typedef _GridInput = ({
  double minLat,
  double maxLat,
  double minLng,
  double maxLng,
  int resolution,
});

/// Top-level function so compute() can spawn it in a background isolate.
/// Uses gridDisk from the viewport center to guarantee full viewport coverage.
///
/// polygonToCells only includes cells whose centroid falls inside the polygon —
/// edge cells get clipped leaving a ragged non-global mosaic. gridDisk(k) from
/// the center cell covers every cell within k steps, which forms a solid hex
/// disk that always fully covers the viewport when k is computed from the
/// diagonal. This is the approach Helium/Nodle use.
///
/// h3_flutter uses DynamicLibrary.process() — safe in compute() isolates.
Map<String, dynamic> _buildGrid(_GridInput input) {
  final h3 = const h3f.H3Factory().load();

  final centerLat = (input.minLat + input.maxLat) / 2;
  final centerLng = (input.minLng + input.maxLng) / 2;

  // Half-diagonal of the padded viewport in metres.
  // 111 000 m ≈ 1 degree of latitude; longitude degrees are shorter by cos(lat).
  final latHalfM  = (input.maxLat - input.minLat) / 2 * 111000;
  final lngHalfM  = (input.maxLng - input.minLng) / 2 * 111000 * cos(centerLat * pi / 180);
  final diagonalM = sqrt(latHalfM * latHalfM + lngHalfM * lngHalfM);

  // Average H3 edge lengths (metres) per resolution:
  //   res 8 → 461 m    res 9 → 174 m
  // Divide diagonal by edge length to get the grid-step radius needed, add
  // 3 cells of buffer so screen edges are always covered.
  final edgeM = input.resolution == 9 ? 174.0 : 461.0;
  final k     = (diagonalM / edgeM).ceil() + 3;

  // Safety cap: at res 8 + zoom 11 the viewport can be >30 km wide; gridDisk
  // of k=40 is ~5000 cells which is fine but we don't need more than that.
  final kCapped = k.clamp(3, 40);

  final centerCell = h3.geoToCell(
    h3f.GeoCoord(lat: centerLat, lon: centerLng),
    input.resolution,
  );

  List<BigInt> cells;
  try {
    cells = h3.gridDisk(centerCell, kCapped);
  } catch (_) {
    return {'type': 'FeatureCollection', 'features': <dynamic>[]};
  }
  if (cells.isEmpty) return {'type': 'FeatureCollection', 'features': <dynamic>[]};

  final features = cells.take(3000).map((cell) {
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
const _kSourcePending   = 'gg-pending';
const _kSourceUserDot   = 'gg-user';
const _kLayerGridFill   = 'gg-grid-fill';
const _kLayerGridLines  = 'gg-grid-lines';
const _kLayerTilesFill  = 'gg-tiles-fill';
const _kLayerTilesLine  = 'gg-tiles-line';
const _kLayerLiveFill   = 'gg-live-fill';
const _kLayerLiveGlow   = 'gg-live-glow';   // wide translucent ring — hex halo effect
const _kLayerLiveLine   = 'gg-live-line';
const _kLayerPendingFill = 'gg-pending-fill';
const _kLayerPendingLine = 'gg-pending-line';
const _kLayerUserHalo    = 'gg-user-halo';
const _kLayerUserDot     = 'gg-user-dot';
const _kSourceAccuracy   = 'gg-accuracy';
const _kLayerAccuracyRing = 'gg-accuracy-ring';

/// H3 resolution for the ghost grid at a given map zoom.
///
/// Rule: grid resolution always matches the data tile resolution so ghost cells
/// align exactly with personal/community tiles. No coarser than res 8 (community
/// tile resolution) so the mosaic always reads at "neighborhood" scale.
///
///   zoom ≥ 14  → res 9  (~174 m cells  — street block, personal tile res)
///   zoom ≥ 11  → res 8  (~461 m cells  — neighborhood, community tile res)
///   zoom < 11  → null   — cells would be city-sized, mosaic makes no sense
///
/// The layer minzoom handles the hide-below-11 case, but returning null lets
/// _refreshGrid skip the FFI call entirely.
int? _gridRes(double zoom) {
  if (zoom >= 13.5) return 9;  // res 9 (~174m) from zoom 13.5 — MapLibre
  if (zoom >= 11) return 8;    // camera reads back as 13.998 when set to 14.0
  return null; // below neighborhood scale — skip grid
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
  /// Long-press on a tile — same data, different UX affordance (hold to inspect).
  final void Function(H3Tile tile)? onTileLongPress;
  final double heightFraction;
  final bool showControls;
  final bool fillScreen;
  final bool isLoading;
  final ValueNotifier<int>? recenterTrigger;
  final EdgeInsets controlsPadding;
  /// Updated whenever follow mode toggles — lets parent show GPS fixed/not-fixed icon.
  final ValueNotifier<bool>? followModeNotifier;
  /// When set, community tiles updated AFTER this timestamp are highlighted
  /// as "new" — making the map feel alive between sessions.
  final DateTime? lastSessionAt;

  /// H3 cell boundaries visited this session but not yet confirmed by backend.
  /// Rendered as optimistic "pending" tiles so the map feels instant.
  final List<List<ll.LatLng>> pendingCellBoundaries;
  /// GPS accuracy radius in metres — renders a faint accuracy ring around user dot.
  final double? userAccuracy;

  const CoverageMapWidget({
    super.key,
    required this.tiles,
    this.userLocation,
    this.userAccuracy,
    this.currentH3Boundary,
    this.isTracking = false,
    this.onTileTap,
    this.onTileLongPress,
    this.heightFraction = 0.5,
    this.showControls = true,
    this.fillScreen = false,
    this.isLoading = false,
    this.recenterTrigger,
    this.controlsPadding = EdgeInsets.zero,
    this.followModeNotifier,
    this.lastSessionAt,
    this.pendingCellBoundaries = const [],
  });

  @override
  CoverageMapWidgetState createState() => CoverageMapWidgetState();
}

class CoverageMapWidgetState extends State<CoverageMapWidget> {
  MapLibreMapController? _ctrl;
  bool _styleLoaded = false;
  bool _pendingStyleLoad = false; // style fired before _ctrl was ready
  bool _hasCenteredOnUser = false; // true after first auto-center on GPS fix
  bool _hasFitTiles = false;       // true after first fit-to-tiles (no GPS case)
  final Map<String, H3Tile> _tileById = {};
  Timer? _gridTimer;
  Timer? _haloTimer;
  double _haloPhase = 0.0; // 0..2π, drives sine-wave pulse
  int _gridGeneration = 0;   // incremented on each refresh; stale results are discarded
  String? _lastGridCenterCell; // H3 cell hex string of last computed grid center
  int _lastGridZoom = -1;      // floor(zoom) at last grid compute
  // MapLibre fires onMapClick when the finger lifts after a long press — suppress
  // taps that arrive within 600 ms of a long press to avoid double-open sheets.
  int _lastLongPressMs = 0;
  bool _showMapHint = false;

  // ── Follow mode ─────────────────────────────────────────────────────────────
  // While tracking is active, the camera continuously follows the user's GPS.
  // Manual pan breaks follow mode. My Location button re-enables it.
  bool _followModeValue = false;
  bool get _followMode => _followModeValue;
  set _followMode(bool value) {
    if (_followModeValue == value) return;
    _followModeValue = value;
    widget.followModeNotifier?.value = value;
  }

  // Cached H3 instance — loading the native lib is expensive, reuse across calls.
  late final h3f.H3 _h3 = const h3f.H3Factory().load();


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
    return jsonEncode({
      'version': 8,
      'glyphs': 'https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf',
      'sources': sources,
      'layers': layers,
    });
  }

  // ── GeoJSON builders ────────────────────────────────────────────────────────

  Map<String, dynamic> _tilesToGeoJson() {
    _tileById.clear();
    final features = <Map<String, dynamic>>[];

    // Build set of res-8 parents for all personal tiles so we can skip global
    // tiles that are already covered by the user's own data. Without this, every
    // personal res-9 tile also renders a dim res-8 community overlay on top of it.
    final personalParents = <BigInt>{};
    for (final tile in widget.tiles) {
      if (!tile.isGlobal && tile.h3Index.isNotEmpty) {
        try {
          final idx = BigInt.parse(tile.h3Index, radix: 16);
          personalParents.add(_h3.cellToParent(idx, 8));
        } catch (_) {}
      }
    }

    for (final tile in widget.tiles) {
      if (tile.boundary == null || tile.boundary!.isEmpty) continue;
      // Skip global tile if the user already has personal coverage in that cell.
      if (tile.isGlobal && tile.h3Index.isNotEmpty) {
        try {
          final idx = BigInt.parse(tile.h3Index, radix: 16);
          if (personalParents.contains(idx)) continue;
        } catch (_) {}
      }
      _tileById[tile.h3Index] = tile;
      final isNew = _isNewSince(tile);
      final color = isNew ? _newColorHex(tile) : _colorHex(tile);
      final fillOpacity = isNew ? 0.32 : _fillOpacity(tile);
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
          'fillOpacity': fillOpacity,
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
  Map<String, dynamic> _labelsGeoJson() {
    final features = <Map<String, dynamic>>[];
    for (final tile in widget.tiles) {
      if (tile.isGlobal || tile.boundary == null || tile.boundary!.isEmpty) continue;
      final lats = tile.boundary!.map((p) => p.latitude);
      final lngs = tile.boundary!.map((p) => p.longitude);
      final cLat = lats.reduce((a, b) => a + b) / tile.boundary!.length;
      final cLng = lngs.reduce((a, b) => a + b) / tile.boundary!.length;
      final opacity = _fillOpacity(tile);
      final labelText = '${_qualityPct(tile)}%';
      final labelColor = _colorHex(tile);
      features.add({
        'type': 'Feature',
        'properties': {
          'label': labelText,
          'color': labelColor,
          'labelOpacity': (opacity * 1.4).clamp(0.5, 1.0),
        },
        'geometry': {'type': 'Point', 'coordinates': [cLng, cLat]},
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

  Map<String, dynamic> _pendingCellsGeoJson() {
    final boundaries = widget.pendingCellBoundaries;
    if (boundaries.isEmpty) return _kEmptyFC;
    return {
      'type': 'FeatureCollection',
      'features': boundaries.map((ring) => {
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [[
            ...ring.map((p) => [p.longitude, p.latitude]),
            [ring.first.longitude, ring.first.latitude],
          ]],
        },
      }).toList(),
    };
  }

  /// Builds a GeoJSON circle polygon for the GPS accuracy ring.
  /// Uses lat/lng offsets so the ring scales with zoom in real-world metres.
  Map<String, dynamic> _accuracyRingGeoJson() {
    final loc = widget.userLocation;
    final acc = widget.userAccuracy;
    if (loc == null || acc == null || acc <= 0) return _kEmptyFC;
    const steps = 32;
    const degPerMetre = 1.0 / 111320.0;
    final latRadius = acc * degPerMetre;
    final lngRadius = acc * degPerMetre / cos(loc.latitude * pi / 180);
    final ring = List.generate(steps, (i) {
      final angle = 2 * pi * i / steps;
      return [
        loc.longitude + lngRadius * cos(angle),
        loc.latitude  + latRadius * sin(angle),
      ];
    })..add([
      loc.longitude + lngRadius,
      loc.latitude,
    ]);
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [ring],
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
  // "New" community tiles (updated since last session) glow brighter — the map
  // is alive between sessions.

  /// True when this community tile was updated after the user's last session.
  bool _isNewSince(H3Tile tile) {
    final since = widget.lastSessionAt;
    if (!tile.isGlobal || since == null || tile.lastUpdate == null) return false;
    return tile.lastUpdate!.isAfter(since);
  }

  /// Returns the effective quality score (0–100) for a tile.
  static int _qualityPct(H3Tile tile) {
    if (tile.qualityRatio != null) return (tile.qualityRatio! * 100).round().clamp(0, 100);
    if (tile.qualityScore != null) return (tile.qualityScore! * 100).round().clamp(0, 100);
    return (tile.confidence * 100).round().clamp(0, 100);
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

  /// Brighter color for community tiles new since last session.
  static String _newColorHex(H3Tile tile) {
    final q = _qualityPct(tile);
    if (q >= 75) return '#10b981'; // full emerald — matches personal quality
    if (q >= 50) return '#f59e0b'; // amber-400
    return '#f87171';              // red-400
  }

  static double _fillOpacity(H3Tile tile) {
    if (tile.isGlobal) return 0.18;
    final q = _qualityPct(tile);
    double base = q >= 75 ? 0.45 : q >= 50 ? 0.36 : 0.28;
    if (tile.lastUpdate != null) {
      final age = DateTime.now().difference(tile.lastUpdate!).inDays;
      // Two-step decay: fresh → aging → stale
      if (age > 21)     { base *= 0.45; }
      else if (age > 7) { base *= 0.72; }
    }
    return base;
  }

  static double _strokeOpacity(H3Tile tile) {
    if (tile.isGlobal) return 0.0;
    final q = _qualityPct(tile);
    double base = q >= 75 ? 0.75 : q >= 50 ? 0.60 : 0.45;
    if (tile.lastUpdate != null) {
      final age = DateTime.now().difference(tile.lastUpdate!).inDays;
      if (age > 21)     { base *= 0.45; }
      else if (age > 7) { base *= 0.72; }
    }
    return base;
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
    _followMode = true;
    _ctrl!.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(widget.userLocation!.latitude, widget.userLocation!.longitude),
      ),
    );
  }

  void _onCameraMove(CameraPosition _) {}

  Future<void> _onStyleLoaded() async {
    final ctrl = _ctrl;
    if (ctrl == null) {
      debugPrint('MapLibre: style loaded before _ctrl ready — deferring');
      _pendingStyleLoad = true;
      return;
    }
    // _styleLoaded is set to true AFTER all layers are added so that any
    // didUpdateWidget calls during async layer setup return early from
    // _refreshAllSources instead of hitting LAYER_NOT_FOUND errors.
    debugPrint('MapLibre: style loaded OK, adding GeoJSON sources + layers...');

    // ── Add sources (empty, populated below) ──
    await Future.wait([
      ctrl.addGeoJsonSource(_kSourceGrid, _kEmptyFC),
      ctrl.addGeoJsonSource(_kSourceTiles, _kEmptyFC),
      ctrl.addGeoJsonSource(_kSourcePending, _kEmptyFC),
      ctrl.addGeoJsonSource(_kSourceLiveCell, _kEmptyFC),
      ctrl.addGeoJsonSource(_kSourceUserDot, _kEmptyFC),
      ctrl.addGeoJsonSource(_kSourceAccuracy, _kEmptyFC),
    ]);

    // ── Ghost grid fill — choropleth base layer ──
    // Empty cells get a tint so the entire viewport reads as a hex mosaic.
    // Added BEFORE the tiles fill layer in the call sequence — that's what
    // controls Z-order. Do NOT pass belowLayerId here because _kLayerTilesFill
    // doesn't exist yet at this point; MapLibre would silently drop this layer.
    // Grid fill and lines both start at zoom 11 — below that cells are
    // city-sized and a mosaic makes no visual sense (matching _gridRes logic).
    // Ghost grid starts at zoom 9 (neighbourhood scale) so the hex mosaic is
    // visible in a wider context — unclaimed cells read as "territory to fill",
    // not just empty map. Fog-of-war psychology kicks in earlier.
    await ctrl.addFillLayer(
      _kSourceGrid,
      _kLayerGridFill,
      const FillLayerProperties(
        fillColor: '#1a3a52',  // dark blue-teal, clearly distinct from #111927 base
        fillOpacity: 0.40,
      ),
      minzoom: 9.0,
    );

    await ctrl.addLineLayer(
      _kSourceGrid,
      _kLayerGridLines,
      const LineLayerProperties(
        lineColor: '#ffffff',
        lineOpacity: 0.06,
        lineWidth: 0.5,
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

    // ── Pending cells — session tiles not yet confirmed by backend ──
    // Slightly lower opacity than confirmed tiles; dashed border signals "in-flight".
    await ctrl.addFillLayer(
      _kSourcePending,
      _kLayerPendingFill,
      const FillLayerProperties(
        fillColor: AppColors.primaryHex,
        fillOpacity: 0.18,
      ),
      minzoom: 9.0,
    );
    await ctrl.addLineLayer(
      _kSourcePending,
      _kLayerPendingLine,
      const LineLayerProperties(
        lineColor: AppColors.primaryHex,
        lineOpacity: 0.55,
        lineWidth: 1.5,
        lineDasharray: [3.0, 2.0],
      ),
      minzoom: 9.0,
    );

    // ── Live cell — primary green fill + glow halo + sharp inner outline ──
    // Color matches the user dot (primaryHex) so the current cell reads as "yours"
    // not as a quality signal. Two outline layers: wide+faint = halo, thin+solid = edge.
    await ctrl.addFillLayer(
      _kSourceLiveCell,
      _kLayerLiveFill,
      const FillLayerProperties(
        fillColor: AppColors.primaryHex,
        fillOpacity: 0.22,
      ),
    );
    // Outer glow — wide, translucent, blurs into the hex shape
    await ctrl.addLineLayer(
      _kSourceLiveCell,
      _kLayerLiveGlow,
      const LineLayerProperties(
        lineColor: AppColors.primaryHex,
        lineOpacity: 0.40,
        lineWidth: 8.0,
        lineBlur: 5.0,
      ),
    );
    // Inner edge — crisp 2px border to anchor the glow
    await ctrl.addLineLayer(
      _kSourceLiveCell,
      _kLayerLiveLine,
      const LineLayerProperties(
        lineColor: AppColors.primaryHex,
        lineOpacity: 1.0,
        lineWidth: 2.0,
      ),
    );

    // ── GPS accuracy ring — faint fill shows fix quality in real-world metres ──
    await ctrl.addFillLayer(
      _kSourceAccuracy,
      _kLayerAccuracyRing,
      const FillLayerProperties(
        fillColor: AppColors.primaryHex,
        fillOpacity: 0.08,
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
    _startHaloPulse();

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

    // ── Hex quality % labels — native MapLibre symbol layer ──────────────
    // Uses Protomaps-hosted Noto Sans Regular (confirmed available).
    // Symbol layers are rendered natively — they track map coordinates perfectly.
    await ctrl.addGeoJsonSource('gg-labels', _kEmptyFC);
    await ctrl.addSymbolLayer(
      'gg-labels',
      'gg-labels-sym',
      SymbolLayerProperties(
        textField: ['get', 'label'],
        textFont: ['Noto Sans Regular'],
        // Zoom-responsive size: small at z11, comfortable at z14+
        textSize: ['interpolate', ['linear'], ['zoom'], 11.0, 9.0, 13.0, 12.0, 15.0, 14.0],
        // Color matches tile fill — reads as part of the hex, not overlaid text
        textColor: ['get', 'color'],
        // Dark map bg as halo — soft separation without harsh black ring
        textHaloColor: '#111927',
        textHaloWidth: 1.2,
        textOpacity: ['get', 'labelOpacity'],
        textAllowOverlap: true,
        textIgnorePlacement: true,
        textAnchor: 'center',
        textLetterSpacing: 0.02,
      ),
      minzoom: 11.0,
    );

    debugPrint('MapLibre: all layers added — populating sources...');
    _styleLoaded = true;
    await _refreshAllSources();
    await Future<void>.delayed(AppDurations.medium);
    await _refreshGrid();
    debugPrint('MapLibre: initial grid + sources populated');
  }

  Future<void> _refreshAllSources() async {
    final ctrl = _ctrl;
    if (!_styleLoaded || ctrl == null) return;

    // Live cell dims when paused but stays visible so user sees their position.
    final liveFillOpacity = widget.isTracking ? 0.12 : 0.05;
    final liveGlowOpacity = widget.isTracking ? 0.30 : 0.10;
    final liveLineOpacity = widget.isTracking ? 0.90 : 0.30;

    await Future.wait([
      ctrl.setGeoJsonSource(_kSourceTiles, _tilesToGeoJson()),
      ctrl.setGeoJsonSource('gg-labels', _labelsGeoJson()),
      ctrl.setGeoJsonSource(_kSourcePending, _pendingCellsGeoJson()),
      ctrl.setGeoJsonSource(_kSourceLiveCell, _liveCellGeoJson()),
      ctrl.setGeoJsonSource(_kSourceUserDot, _userDotGeoJson()),
      ctrl.setGeoJsonSource(_kSourceAccuracy, _accuracyRingGeoJson()),
      ctrl.setLayerProperties(_kLayerLiveFill, FillLayerProperties(fillOpacity: liveFillOpacity)),
      ctrl.setLayerProperties(_kLayerLiveGlow, LineLayerProperties(lineOpacity: liveGlowOpacity)),
      ctrl.setLayerProperties(_kLayerLiveLine, LineLayerProperties(lineOpacity: liveLineOpacity)),
    ]);

    // If we have tiles but no GPS fix yet, fit camera to tile bounds once.
    if (!_hasFitTiles && !_hasCenteredOnUser && widget.userLocation == null) {
      _fitToTiles(ctrl);
    }
  }

  /// Fit the camera to all personal tiles so they're always visible on cold start.
  void _fitToTiles(MapLibreMapController ctrl) {
    final personal = widget.tiles.where((t) => !t.isGlobal && t.boundary != null && t.boundary!.isNotEmpty).toList();
    if (personal.isEmpty) return;
    _hasFitTiles = true;

    // Compute bounding box of all tile centroids (fast, no h3 FFI needed)
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final tile in personal) {
      for (final pt in tile.boundary!) {
        if (pt.latitude < minLat) minLat = pt.latitude;
        if (pt.latitude > maxLat) maxLat = pt.latitude;
        if (pt.longitude < minLng) minLng = pt.longitude;
        if (pt.longitude > maxLng) maxLng = pt.longitude;
      }
    }

    // Add ~20% padding around the bounding box
    final latPad = (maxLat - minLat) * 0.3 + 0.005;
    final lngPad = (maxLng - minLng) * 0.3 + 0.005;
    ctrl.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - latPad, minLng - lngPad),
          northeast: LatLng(maxLat + latPad, maxLng + lngPad),
        ),
        left: 32, top: 32, right: 32, bottom: 32,
      ),
    );
    debugPrint('MapLibre: fit to ${personal.length} personal tiles');
  }

  Future<void> _refreshGrid() async {
    final ctrl = _ctrl;
    if (!_styleLoaded || ctrl == null) return;

    final zoom = ctrl.cameraPosition?.zoom ?? 13.0;
    final res = _gridRes(zoom);
    if (res == null) return; // below neighborhood scale — clear grid and skip

    final center = ctrl.cameraPosition?.target;
    if (center == null) return;
    final zoomInt = zoom.floor();

    // Cheap center-cell dedup — gridDisk is centered on the center cell, so if
    // the center hasn't moved to a new H3 cell and zoom hasn't changed, the
    // computed disk is identical — skip the FFI call and GeoJSON rebuild.
    final centerCell = _h3.geoToCell(
      h3f.GeoCoord(lat: center.latitude, lon: center.longitude),
      res,
    );
    final cellStr = centerCell.toRadixString(16);
    if (cellStr == _lastGridCenterCell && zoomInt == _lastGridZoom) return;
    _lastGridCenterCell = cellStr;
    _lastGridZoom = zoomInt;

    // Get the viewport bounds to compute the disk radius (k).
    // 30% padding ensures edge cells are always included — gridDisk slightly
    // overshoots the screen edges which is fine (clipped by the device).
    LatLngBounds region;
    try {
      region = await ctrl.getVisibleRegion();
    } catch (_) {
      return;
    }

    final latPad = (region.northeast.latitude  - region.southwest.latitude)  * 0.30;
    final lngPad = (region.northeast.longitude - region.southwest.longitude) * 0.30;

    final gen = ++_gridGeneration;

    Map<String, dynamic> geojson;
    try {
      geojson = await compute(_buildGrid, (
        minLat: region.southwest.latitude  - latPad,
        maxLat: region.northeast.latitude  + latPad,
        minLng: region.southwest.longitude - lngPad,
        maxLng: region.northeast.longitude + lngPad,
        resolution: res,
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

  void _onCameraIdle() {
    _scheduleGridRefresh();
  }

  void _scheduleGridRefresh() {
    _gridTimer?.cancel();
    _gridTimer = Timer(_kGridDebounce, _refreshGrid);
  }


  void _startHaloPulse() {
    _haloTimer?.cancel();
    // 60ms tick ≈ 16fps — sufficient for a slow breathing halo, avoids GL spam
    _haloTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!_styleLoaded || _ctrl == null || !mounted) return;
      _haloPhase = (_haloPhase + 0.07) % (2 * pi);
      final t = (sin(_haloPhase) + 1) / 2; // 0..1
      // User dot halo
      final radius = 13.0 + t * 11.0;      // 13→24
      final opacity = 0.08 + t * 0.16;     // 0.08→0.24
      _ctrl!.setLayerProperties(
        _kLayerUserHalo,
        CircleLayerProperties(circleRadius: radius, circleOpacity: opacity),
      );
      // Live cell glow — breathes in sync with user dot
      if (widget.isTracking) {
        _ctrl!.setLayerProperties(
          _kLayerLiveGlow,
          LineLayerProperties(
            lineOpacity: 0.22 + t * 0.28,  // 0.22→0.50
            lineWidth: 6.0 + t * 6.0,      // 6→12
          ),
        );
      }
    });
  }

  void _onMapTap(Point<double> point, LatLng coords) async {
    // Suppress tap if it follows a long press — MapLibre fires onMapClick when
    // the finger lifts after a long press, which would open a duplicate sheet.
    if (DateTime.now().millisecondsSinceEpoch - _lastLongPressMs < 600) return;
    final tile = await _hitTestTile(point);
    if (tile != null) {
      _dismissMapHint();
      widget.onTileTap?.call(tile);
    }
  }

  void _dismissMapHint() {
    if (!_showMapHint) return;
    setState(() => _showMapHint = false);
    AppPreferences.instance.dismissTip('map_tap_hint');
  }

  void _onMapLongPress(Point<double> point, LatLng coords) async {
    _lastLongPressMs = DateTime.now().millisecondsSinceEpoch;
    final tile = await _hitTestTile(point);
    if (tile != null) {
      _dismissMapHint();
      HapticFeedback.mediumImpact();
      (widget.onTileLongPress ?? widget.onTileTap)?.call(tile);
    }
  }

  /// Hit-test the tile fill layer at [point] and return the matching [H3Tile].
  Future<H3Tile?> _hitTestTile(Point<double> point) async {
    final ctrl = _ctrl;
    if (ctrl == null) return null;
    final features =
        await ctrl.queryRenderedFeatures(point, [_kLayerTilesFill], null);
    if (features.isEmpty) return null;
    final props = (features.first as Map<Object?, Object?>?)
        ?['properties'] as Map<Object?, Object?>?;
    final h3Index = props?['h3Index'] as String?;
    return h3Index != null ? _tileById[h3Index] : null;
  }

  // ── Widget lifecycle ────────────────────────────────────────────────────────

  @override
  @override
  void initState() {
    super.initState();
    _showMapHint = !AppPreferences.instance.isTipDismissed('map_tap_hint');
  }

  @override
  void didUpdateWidget(CoverageMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recenterTrigger != widget.recenterTrigger) {
      oldWidget.recenterTrigger?.removeListener(_onRecenter);
      widget.recenterTrigger?.addListener(_onRecenter);
    }
    if (!_styleLoaded) return;

    final tilesChanged = !identical(oldWidget.tiles, widget.tiles);
    final locationChanged = oldWidget.userLocation != widget.userLocation;
    final liveChanged = !identical(
          oldWidget.currentH3Boundary,
          widget.currentH3Boundary,
        ) ||
        oldWidget.isTracking != widget.isTracking;

    if (tilesChanged || locationChanged || liveChanged) {
      _refreshAllSources();
    }
    // Tracking just started → enable follow mode so the map feels alive.
    // Must be deferred — didUpdateWidget runs during build, and setting the
    // ValueNotifier here would trigger markNeedsBuild on another widget mid-frame.
    if (!oldWidget.isTracking && widget.isTracking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _followMode = true;
      });
    }

    // First GPS fix after map init — auto-center once, silently.
    // initialCameraPosition is frozen at build time so if location wasn't
    // available yet (common on cold start) we move the camera here instead.
    if (!_hasCenteredOnUser &&
        oldWidget.userLocation == null &&
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
      return;
    }

    // Follow mode — smooth camera pan on each GPS update while tracking.
    if (_followMode &&
        locationChanged &&
        widget.userLocation != null &&
        _ctrl != null) {
      _ctrl!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(widget.userLocation!.latitude, widget.userLocation!.longitude),
        ),
      );
    }
  }

  @override
  void dispose() {
    _gridTimer?.cancel();
    _haloTimer?.cancel();
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
    return const LatLng(48.86, 2.35); // Paris — shown only before GPS fix or tiles load
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
      onCameraIdle: _onCameraIdle,
      onCameraMove: _onCameraMove,
      onMapClick: widget.showControls ? _onMapTap : null,
      onMapLongClick: widget.showControls ? _onMapLongPress : null,
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
      // No annotation manager symbols — we use custom GeoJSON symbol layers.
      // Without this, MapLibre creates a default symbol layer that can interfere.
      annotationOrder: const [],
    );

    // Touch on the map surface exits follow mode immediately — no timing hacks.
    final mapWithGesture = Listener(
      onPointerDown: (_) {
        if (_followMode) _followMode = false;
      },
      child: mapWidget,
    );

    final mapStack = Stack(
      children: [
        mapWithGesture,

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
                color: AppColors.surface(isDark).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.border(isDark)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined,
                      size: AppIconSizes.xl, color: AppColors.textSecondary(isDark)),
                  const SizedBox(height: AppTheme.spaceSm),
                  Text(
                    context.l10n.noCoverageYet,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeMd,
                      color: AppColors.textPrimary(isDark),
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXxs),
                  Text(
                    context.l10n.startTrackingToMap,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── First-time tap hint (fill-screen + has tiles) ────────────────
        if (widget.fillScreen && _showMapHint && widget.tiles.isNotEmpty)
          _MapTapHint(onDismiss: _dismissMapHint),

        // ── Tile count badge (card mode) ──────────────────────────────────
        if (!widget.fillScreen && widget.tiles.isNotEmpty)
          Positioned(
            top: AppTheme.spaceSm,
            right: AppTheme.spaceSm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
              decoration: BoxDecoration(
                color: AppColors.surface(isDark).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppColors.border(isDark)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined, size: AppIconSizes.xs, color: AppColors.primary),
                  const SizedBox(width: AppTheme.spaceXs - 2),
                  Text(
                    context.l10n.tilesCount(widget.tiles.length),
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeXs,
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
        border: Border.all(color: AppColors.border(isDark), width: AppBorderWidths.thin),
        boxShadow: isDark
            ? AppColors.elevationDark(active: false)
            : AppColors.elevationLight(active: false),
      ),
      clipBehavior: Clip.antiAlias,
      child: mapStack,
    );
  }
}

// ── First-time map hint ───────────────────────────────────────────────────────

class _MapTapHint extends StatefulWidget {
  const _MapTapHint({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  State<_MapTapHint> createState() => _MapTapHintState();
}

class _MapTapHintState extends State<_MapTapHint> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Delay so it appears after the map finishes loading
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 72,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 400),
        child: Center(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs),
                  decoration: AppColors.glassDecoration(
                      isDark: true, backgroundAlpha: 0.60, borderAlpha: 0.18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: AppIconSizes.xs, color: AppColors.primary),
                      const SizedBox(width: AppTheme.spaceXs),
                      Text(
                        AppLocalizations.of(context)!.mapTapHint,
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          color: AppColors.darkTextPrimary,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Map legend ────────────────────────────────────────────────────────────────

/// Compact inline legend — three quality dots + optional community dot.
/// Tap to open an explanation sheet.
class MapHeatmapLegend extends StatelessWidget {
  const MapHeatmapLegend({super.key, required this.hasCommunityTiles});
  final bool hasCommunityTiles;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _LegendInfoSheet(hasCommunityTiles: hasCommunityTiles),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppTheme.glassBlurSigma,
              sigmaY: AppTheme.glassBlurSigma),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceXs, vertical: AppTheme.spaceTiny + 1),
            decoration: AppColors.glassDecoration(
                isDark: true, backgroundAlpha: 0.50, borderAlpha: 0.12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendDot(color: AppColors.quality),
                const SizedBox(width: AppTheme.spaceTiny),
                _LegendDot(color: AppColors.light),
                const SizedBox(width: AppTheme.spaceTiny),
                _LegendDot(color: AppColors.heatmapHot),
                if (hasCommunityTiles) ...[
                  Container(
                      width: AppBorderWidths.hairline + 0.5,
                      height: AppTheme.spaceXs,
                      color: AppColors.shadowLight(0.24),
                      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs - 2)),
                  _LegendDot(
                      color: AppColors.community.withValues(alpha: 0.7)),
                ],
                const SizedBox(width: AppTheme.spaceTiny),
                Icon(Icons.info_outline,
                    size: AppIconSizes.xxs,
                    color: AppColors.shadowLight(0.38)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppTheme.dotSizeLg,
      height: AppTheme.dotSizeLg,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Bottom sheet explaining what the legend colors mean.
class _LegendInfoSheet extends StatelessWidget {
  const _LegendInfoSheet({required this.hasCommunityTiles});
  final bool hasCommunityTiles;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTheme.dragHandle(isDark),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceSm),
              child: Text(l10n.infoTileQualityTitle,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeMd,
                    fontWeight: AppFontWeights.semibold,
                    color: AppColors.textPrimary(isDark),
                    letterSpacing: -0.2,
                  )),
            ),
            _LegendRow(
                color: AppColors.quality,
                label: l10n.legendHighLabel,
                sub: l10n.legendHighSub,
                isDark: isDark),
            _LegendRow(
                color: AppColors.light,
                label: l10n.legendMidLabel,
                sub: l10n.legendMidSub,
                isDark: isDark),
            _LegendRow(
                color: AppColors.heatmapHot,
                label: l10n.legendLowLabel,
                sub: l10n.legendLowSub,
                isDark: isDark),
            if (hasCommunityTiles)
              _LegendRow(
                  color: AppColors.community.withValues(alpha: 0.8),
                  label: l10n.tileInfoCommunity,
                  sub: l10n.legendCommunitySub,
                  isDark: isDark),
            const SizedBox(height: AppTheme.spaceMd),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(
      {required this.color,
      required this.label,
      required this.sub,
      required this.isDark});
  final Color color;
  final String label;
  final String sub;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceSm),
      child: Row(
        children: [
          Container(
            width: AppTheme.spaceXs + 2,
            height: AppTheme.spaceXs + 2,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppTheme.fontSizeSm,
                        fontWeight: AppFontWeights.semibold,
                        color: AppColors.textPrimary(isDark))),
                Text(sub,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppTheme.fontSizeXs,
                        color: AppColors.textSecondary(isDark))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile info bottom sheet ────────────────────────────────────────────────────

/// Bottom sheet shown when user taps a coverage tile.
/// [isDark] and [l10n] are passed explicitly from the calling context because
/// the modal route's BuildContext may not inherit AppLocalizations, causing
/// `context.l10n` to throw and the sheet to render blank.
class TileInfoSheet extends StatefulWidget {
  const TileInfoSheet({super.key, required this.tile, required this.isDark, required this.l10n});
  final H3Tile tile;
  final bool isDark;
  final AppLocalizations l10n;

  @override
  State<TileInfoSheet> createState() => _TileInfoSheetState();
}

class _TileInfoSheetState extends State<TileInfoSheet> {
  DateTime? _firstMappedAt;

  @override
  void initState() {
    super.initState();
    if (!widget.tile.isGlobal && widget.tile.centroid != null) {
      _loadFirstMappedDate();
    }
  }

  Future<void> _loadFirstMappedDate() async {
    final centroid = widget.tile.centroid!;
    // Compute 7-char geohash from centroid to query local DB
    final geohash = GeoHasher().encode(centroid.longitude, centroid.latitude, precision: 7);
    final date = await DatabaseHelper.instance.getFirstContributionNearGeohash(geohash);
    if (mounted && date != null) {
      setState(() => _firstMappedAt = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersonal = !widget.tile.isGlobal;
    final tile = widget.tile;
    final isDark = widget.isDark;
    final l10n = widget.l10n;

    final ageDays = tile.lastUpdate != null
        ? DateTime.now().difference(tile.lastUpdate!).inDays
        : null;
    final isStaling = ageDays != null && ageDays > 21;
    final isAging  = ageDays != null && ageDays > 7 && !isStaling;

    // Priority: personal quality ratio (weighted composite) > global quality score > confidence
    final qualityPct = tile.qualityRatio != null
        ? (tile.qualityRatio! * 100).round()
        : tile.qualityScore != null
            ? (tile.qualityScore! * 100).round()
            : (tile.confidence * 100).round();
    final qualityColor = isStaling
        ? AppColors.warning
        : qualityPct >= 75
            ? AppColors.quality
            : qualityPct >= 50
                ? AppColors.light
                : AppColors.error;
    final qualityLabel = isStaling
        ? l10n.tileQualityStaling
        : qualityPct >= 75
            ? l10n.tileQualityExcellent
            : qualityPct >= 50
                ? l10n.tileQualityGood
                : l10n.tileQualityFair;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quality color accent strip
              Container(height: AppTheme.spaceTiny, color: qualityColor),
              AppTheme.dragHandle(isDark),
              // Header row: title + quality badge
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceSm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPersonal ? l10n.tileInfoPersonal : l10n.tileInfoCommunity,
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeMd,
                              color: AppColors.textPrimary(isDark),
                              fontWeight: AppFontWeights.semibold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (isPersonal && _firstMappedAt != null) ...[
                            const SizedBox(height: AppTheme.spaceXxxs),
                            Text(
                              l10n.tileFirstMapped(DateFormat('MMM d, yyyy', Localizations.localeOf(context).toString()).format(_firstMappedAt!)),
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeBody,
                                color: AppColors.primary.withValues(alpha: 0.85),
                                fontWeight: AppFontWeights.medium,
                              ),
                            ),
                          ] else if (tile.lastUpdate != null) ...[
                            const SizedBox(height: AppTheme.spaceXxxs),
                            _TimeAgoLine(timestamp: tile.lastUpdate!, isDark: isDark),
                          ],
                          if (isPersonal && tile.deviceCount == 1) ...[
                            const SizedBox(height: AppTheme.spaceXs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spaceXs, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              ),
                              child: Text(
                                l10n.tileOnlyYouMapped,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: AppTheme.fontSizeXs,
                                  fontWeight: AppFontWeights.semibold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    // Quality badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXxxs),
                      decoration: BoxDecoration(
                        color: qualityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isStaling ? Icons.warning_amber_rounded : Icons.circle,
                            size: AppTheme.dotSize + (isStaling ? 2 : 0),
                            color: qualityColor,
                          ),
                          const SizedBox(width: AppTheme.spaceXxs),
                          Text(
                            qualityLabel,
                            style: TextStyle(
                              color: qualityColor,
                              fontSize: AppTheme.fontSizeSm,
                              fontWeight: AppFontWeights.semibold,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Quality progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.tileInfoQualityLabel,
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            color: AppColors.textSecondary(isDark),
                            fontWeight: AppFontWeights.medium,
                          ),
                        ),
                        Text(
                          '$qualityPct%',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeSm,
                            color: qualityColor,
                            fontWeight: AppFontWeights.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceXxxs + 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: qualityPct / 100),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (_, value, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: AppTheme.spaceXxs + 1,
                          backgroundColor: AppColors.border(isDark),
                          valueColor: AlwaysStoppedAnimation<Color>(qualityColor),
                        ),
                      ),
                    ),
                    if (isStaling) ...[
                      const SizedBox(height: AppTheme.spaceXs),
                      Text(
                        l10n.tileDecayWarning(ageDays),
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeXs,
                          color: AppColors.warning,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                    ] else if (isAging) ...[
                      const SizedBox(height: AppTheme.spaceXs),
                      Text(
                        l10n.tileDecayHint(ageDays),
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeXs,
                          color: AppColors.textTertiary(isDark),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Sensor cards — data-driven, handles 1–N sensors gracefully
              Builder(builder: (context) {
                final cards = <({IconData icon, Color color, String title, String label, String raw})>[
                  if (tile.avgLux != null)
                    (icon: Icons.light_mode_rounded, color: AppColors.light, title: l10n.sensorLight, label: _luxContext(tile.avgLux!, l10n), raw: '${tile.avgLux} ${l10n.sensorUnitLux}'),
                  if (tile.avgHpa != null)
                    (icon: Icons.compress_rounded, color: AppColors.pressure, title: l10n.sensorAirPressure, label: _hpaContext(tile.avgHpa!, l10n), raw: '${tile.avgHpa!.toStringAsFixed(0)} ${l10n.sensorUnitHpa}'),
                  if (tile.avgMovement != null)
                    (icon: Icons.directions_walk_rounded, color: AppColors.movement, title: l10n.sensorMovement, label: _movementContext(tile.avgMovement!, l10n), raw: '${tile.avgMovement!.toStringAsFixed(1)} ${l10n.sensorUnitMovement}'),
                  if (tile.avgVibration != null)
                    (icon: Icons.vibration_rounded, color: AppColors.movement.withValues(alpha: 0.75), title: l10n.sensorAcceleration, label: _vibrationContext(tile.avgVibration!, l10n), raw: '${(tile.avgVibration! * 100).round()}${l10n.sensorUnitVibration}'),
                ];
                if (cards.isEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(height: 1, thickness: AppBorderWidths.thin, color: AppColors.border(isDark)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                        child: Row(
                          children: [
                            Icon(Icons.sensors_off_rounded,
                                size: AppIconSizes.xs, color: AppColors.textTertiary(isDark)),
                            const SizedBox(width: AppTheme.spaceXs),
                            Expanded(
                              child: Text(
                                l10n.tileInfoNoSensorData,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(height: 1, thickness: 1, color: AppColors.border(isDark)),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceMd),
                      child: Row(
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: AppTheme.spaceXs),
                            Expanded(
                              child: _SensorCard(
                                icon: cards[i].icon,
                                color: cards[i].color,
                                title: cards[i].title,
                                label: cards[i].label,
                                rawValue: cards[i].raw,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }),
              // Compact condition line — what is this place normally like
              Builder(builder: (context) {
                final isNight = DateTime.now().hour < 6 || DateTime.now().hour >= 20;
                final conditionLine = SensorInsights.tileConditionLine(
                  l10n,
                  isNight: isNight,
                  avgLux: tile.avgLux?.toDouble(),
                  avgMovement: tile.avgMovement,
                  avgVibration: tile.avgVibration,
                );
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceMd),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.eco_rounded,
                          size: AppIconSizes.xs, color: AppColors.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: AppTheme.spaceXs),
                      Expanded(
                        child: Text(
                          conditionLine,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(isDark),
                            height: AppLineHeights.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Divider
              Divider(height: 1, thickness: 1, color: AppColors.border(isDark)),
              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceMd),
                child: Row(
                  children: [
                    _StatItem(
                      icon: Icons.dataset_outlined,
                      value: _formatCount(tile.sampleCount),
                      label: l10n.tileInfoSamplesLabel,
                      isDark: isDark,
                    ),
                    _VerticalDivider(isDark: isDark),
                    _StatItem(
                      icon: Icons.devices_outlined,
                      value: '${tile.deviceCount}',
                      label: l10n.tileInfoDevicesLabel,
                      isDark: isDark,
                    ),
                    if (isPersonal) ...[
                      _VerticalDivider(isDark: isDark),
                      _StatItem(
                        icon: Icons.place_outlined,
                        value: '~${_areaMDisplay(tile)}',
                        label: l10n.tileInfoAreaLabel,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),

              // Community tile: subtle claim CTA
              if (!isPersonal) ...[
                Divider(height: 1, thickness: 1, color: AppColors.border(isDark)),
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceMd),
                    child: Row(
                      children: [
                        Icon(Icons.add_location_alt_outlined,
                            size: AppIconSizes.xs, color: AppColors.primary),
                        const SizedBox(width: AppTheme.spaceXs),
                        Expanded(
                          child: Text(
                            l10n.tileCommunityClaimCta,
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeBody,
                              color: AppColors.primary,
                              fontWeight: AppFontWeights.medium,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: AppIconSizes.xs, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  /// H3 res 9 cell area — fixed ≈ 0.1 km² per cell.
  static String _areaMDisplay(H3Tile tile) => '0.1 km²';

  static String _luxContext(int lux, AppLocalizations l10n) {
    if (lux < 50) return l10n.sensorLuxDark;
    if (lux < 500) return l10n.sensorLuxIndoor;
    if (lux < 10000) return l10n.sensorLuxBright;
    return l10n.sensorLuxDirect;
  }

  static String _hpaContext(double hpa, AppLocalizations l10n) {
    if (hpa > 1010) return l10n.sensorHpaLow;
    if (hpa > 990) return l10n.sensorHpaMid;
    return l10n.sensorHpaHigh;
  }

  static String _movementContext(double rms, AppLocalizations l10n) {
    if (rms < 0.5) return l10n.sensorMovementLow;
    if (rms < 2.0) return l10n.sensorMovementMid;
    if (rms < 5.0) return l10n.sensorMovementHigh;
    return l10n.sensorMovementIntense;
  }

  // vibration: normalized 0–1 (accel std-dev / 5 m/s²)
  static String _vibrationContext(double v, AppLocalizations l10n) {
    if (v < 0.15) return l10n.tileVibrationCalm;
    if (v < 0.40) return l10n.tileVibrationLight;
    if (v < 0.70) return l10n.tileVibrationActive;
    return l10n.tileVibrationHeavy;
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
  });
  final IconData icon;
  final String value;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSizes.xs, color: AppColors.textSecondary(isDark)),
          const SizedBox(height: AppTheme.spaceTiny),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTheme.fontSizeSm,
              color: AppColors.textPrimary(isDark),
              fontWeight: AppFontWeights.semibold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXxxs),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.fontSizeXs,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppBorderWidths.thin,
      height: AppTheme.iconBoxSm,
      color: AppColors.border(isDark),
    );
  }
}

/// "Last seen X ago" line — uses TimeAgoText for locale-aware, live-updating relative time.
class _TimeAgoLine extends StatelessWidget {
  const _TimeAgoLine({required this.timestamp, required this.isDark});
  final DateTime timestamp;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: AppIconSizes.xxs, color: AppColors.textSecondary(isDark)),
        const SizedBox(width: AppTheme.spaceTiny),
        TimeAgoText(
          timestamp: timestamp,
          style: TextStyle(
            fontSize: AppTheme.fontSizeXs,
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }
}

/// Tiny sensor icon pill used in TileInfoSheet to show which sensors contributed.
/// One sensor insight row: plain label PRIMARY · raw value small/secondary.
class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.isDark,
    this.title,
    this.rawValue,
  });
  final IconData icon;
  final Color color;
  final String label;
  final bool isDark;
  final String? title;
  final String? rawValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm, horizontal: AppTheme.spaceXs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSizes.sm, color: color),
          if (title != null) ...[
            const SizedBox(height: AppTheme.spaceTiny),
            Text(
              title!.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTheme.fontSizeXxs,
                color: color.withValues(alpha: 0.75),
                fontWeight: AppFontWeights.semibold,
                letterSpacing: 0.6,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spaceTiny),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTheme.fontSizeXs,
              color: AppColors.textPrimary(isDark),
              fontWeight: AppFontWeights.semibold,
              height: AppLineHeights.snug,
            ),
          ),
          if (rawValue != null) ...[
            const SizedBox(height: AppTheme.spaceXxxs),
            Text(
              rawValue!,
              textAlign: TextAlign.center,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTheme.fontSizeXxs,
                color: AppColors.textTertiary(isDark),
                height: AppLineHeights.snug,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

