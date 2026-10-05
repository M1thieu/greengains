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

/// What colours the data tiles: overall quality, or one sensor.
enum MapLayer { quality, light, pressure, movement }

// ── Background isolate grid computation ──────────────────────────────────────

typedef _GridInput = ({
  double centerLat,
  double centerLng,
  /// (resolution, gridDisk radius) per band to build.
  List<(int, int)> bands,
});

/// Top-level function so compute() can spawn it in a background isolate.
/// Builds one hexagon disk per requested band around the viewport centre.
///
/// gridDisk(k) rather than polygonToCells: the disk is a solid hexagon that
/// fully covers the padded viewport when k comes from its diagonal, with no
/// ragged edge where cell centres fall just outside the polygon.
///
/// h3_flutter uses DynamicLibrary.process() — safe in compute() isolates.
Map<int, Map<String, dynamic>> _buildGrids(_GridInput input) {
  final h3 = const h3f.H3Factory().load();
  final out = <int, Map<String, dynamic>>{};
  for (final (res, k) in input.bands) {
    List<BigInt> cells;
    try {
      final centre = h3.geoToCell(h3f.GeoCoord(lat: input.centerLat, lon: input.centerLng), res);
      cells = h3.gridDisk(centre, k);
    } catch (_) {
      continue;
    }
    out[res] = {
      'type': 'FeatureCollection',
      'features': [
        for (final cell in cells)
          {
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                () {
                  final b = h3.cellToBoundary(cell);
                  var ring = [...b.map((c) => [c.lon, c.lat]), [b.first.lon, b.first.lat]];
                  // A cell crossing the antimeridian would be drawn across the whole
                  // map: shift its western vertices by 360° so the ring stays compact.
                  final lons = ring.map((p) => p[0]);
                  if (lons.reduce(max) - lons.reduce(min) > 180) {
                    ring = [for (final p in ring) [p[0] < 0 ? p[0] + 360 : p[0], p[1]]];
                  }
                  return ring;
                }(),
              ],
            },
          },
      ],
    };
  }
  return out;
}

// ── Timing constants ──────────────────────────────────────────────────────────
/// Camera-idle debounce before recomputing the ghost grid (react-h3-map uses 120 ms).
/// Short is fine: each band is a few hundred cells and the zoom transitions
/// themselves are handled per frame by the map's own opacity expressions.
const _kGridDebounce = Duration(milliseconds: 150);

// ── Layer / source ID constants ───────────────────────────────────────────────
const _kSourceLiveCell  = 'gg-live';
const _kSourcePending   = 'gg-pending';
const _kSourceUserDot   = 'gg-user';
const _kLayerLiveFill   = 'gg-live-fill';
const _kLayerLiveGlow   = 'gg-live-glow';   // wide translucent ring — hex halo effect
const _kLayerLiveLine   = 'gg-live-line';
const _kLayerPendingFill = 'gg-pending-fill';
const _kLayerPendingLine = 'gg-pending-line';
const _kLayerUserHalo    = 'gg-user-halo';
const _kLayerUserDot     = 'gg-user-dot';
const _kSourceAccuracy   = 'gg-accuracy';
const _kLayerAccuracyRing = 'gg-accuracy-ring';

/// Average H3 hexagon edge length in metres per resolution (H3 resolution table).
const _kH3EdgeM = <int, double>{
  0: 1107712.6, 1: 418676.0, 2: 158244.7, 3: 59810.9, 4: 22606.4, 5: 8544.4,
  6: 3229.5, 7: 1220.6, 8: 461.4, 9: 174.4,
};

/// Max gridDisk radius drawn: 3k(k+1)+1 cells, so 30 gives 2,791 hexagons.
const int _kGridMaxK = 30;

/// Resolution bands, finest first. 9 is the personal tile resolution.
const _kBandRes = [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]; // down to res 0: the whole world

/// On-screen hexagon edge each band is centred on, in map pixels. react-h3-map
/// picks the resolution the same way (default 40 px), so cells keep the same
/// apparent size at every zoom instead of shrinking to noise or blowing up.
const double _kTargetEdgePx = 40.0;

/// Zoom span over which one band cross-fades into the next.
const double _kBandFade = 0.35;

/// Zoom at which a resolution's hexagon edge is [_kTargetEdgePx] on screen.
/// metres per pixel = 40075016.686 · cos(lat) / (512 · 2^zoom), 512 being the
/// MapLibre tile size at zoom 0.
double _bandCentreZoom(int res, double latitude) =>
    log(40075016.686 * cos(latitude * pi / 180) * _kTargetEdgePx / (512 * _kH3EdgeM[res]!)) / ln2;

/// Zoom range [from, to] in which a band is the one shown; neighbouring bands
/// meet halfway between their centre zooms. Open-ended at both extremes.
({double from, double to}) _bandRange(int res, double latitude) {
  final i = _kBandRes.indexOf(res);
  final c = _bandCentreZoom(res, latitude);
  final finer = i > 0 ? (c + _bandCentreZoom(_kBandRes[i - 1], latitude)) / 2 : double.infinity;
  final coarser = i < _kBandRes.length - 1
      ? (c + _bandCentreZoom(_kBandRes[i + 1], latitude)) / 2
      : double.negativeInfinity;
  return (from: coarser, to: finer);
}

/// MapLibre expression: [full] inside the band's zoom range, fading linearly to
/// 0 across [_kBandFade] at each boundary, so two bands cross-fade frame by frame
/// as the user zooms (the way Helium and WeatherXM fade their layers by zoom)
/// instead of one grid being swapped for another after the camera stops.
/// [full] may itself be a data expression (['get', ...]).
dynamic _bandOpacity(({double from, double to}) range, dynamic full) {
  const h = _kBandFade / 2;
  final stops = <dynamic>[];
  if (range.from.isFinite) {
    stops..addAll([range.from - h, 0.0])..addAll([range.from + h, full]);
  }
  if (range.to.isFinite) {
    stops..addAll([range.to - h, full])..addAll([range.to + h, 0.0]);
  }
  // interpolate clamps outside its stops, so an open-ended side stays at full.
  if (stops.isEmpty) return full;
  return ['interpolate', ['linear'], ['zoom'], ...stops];
}

/// gridDisk radius needed for a viewport of half-diagonal [halfDiagonalM] at
/// [res]. A k-ring disk is hexagon-shaped; its inner radius is about 1.5·k
/// edges (centre spacing sqrt(3)·edge times cos 30°).
int _diskK(double halfDiagonalM, int res) =>
    ((halfDiagonalM / (1.5 * _kH3EdgeM[res]!)).ceil() + 1).clamp(1, _kGridMaxK);

/// Coarsest band still drawn as data hexagons; below it the heatmap takes over
/// (WeatherXM shows a heatmap below zoom 10 for the same reason).
const int _kDataMinRes = 6;
final List<int> _kDataBands = _kBandRes.where((r) => r >= _kDataMinRes).toList();
const _kSourceHeat = 'gg-heat';
const _kLayerHeat = 'gg-heat-layer';

String _gridSource(int res) => 'gg-grid-$res';
String _gridFillLayer(int res) => 'gg-grid-fill-$res';
String _gridLineLayer(int res) => 'gg-grid-line-$res';
String _tileSource(int res) => 'gg-tiles-$res';
String _tileFillLayer(int res) => 'gg-tiles-fill-$res';
String _tileLineLayer(int res) => 'gg-tiles-line-$res';

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
  /// Which value colours the data tiles (WeatherXM-style layer picker).
  final MapLayer mapLayer;

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
    this.mapLayer = MapLayer.quality,
  });

  @override
  CoverageMapWidgetState createState() => CoverageMapWidgetState();
}

class CoverageMapWidgetState extends State<CoverageMapWidget> with WidgetsBindingObserver {
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
  /// Zoom range of each resolution band (set when the style loads).
  Map<int, ({double from, double to})> _bandRanges = const {};
  /// Centre cell of the last grid built per band, to skip identical rebuilds.
  /// Centre and covered radius (m) of the last grid built per band.
  final Map<int, ({double lat, double lng, double radiusM})> _gridCover = {};
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

  /// Data tiles for one resolution band: tiles finer than [res] are drawn as their
  /// parent at [res] (styled like the best-sampled child), so data stays on the
  /// map at every zoom.
  Map<String, dynamic> _tilesToGeoJson(int res) {
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

    final aggregated = <BigInt, H3Tile>{};

    for (final tile in widget.tiles) {
      if (tile.boundary == null || tile.boundary!.isEmpty) continue;
      // Skip global tile if the user already has personal coverage in that cell.
      if (tile.isGlobal && tile.h3Index.isNotEmpty) {
        try {
          final idx = BigInt.parse(tile.h3Index, radix: 16);
          if (personalParents.contains(idx)) continue;
        } catch (_) {}
      }
      if (tile.h3Index.isNotEmpty) {
        final idx = BigInt.tryParse(tile.h3Index, radix: 16);
        if (idx != null && _h3.getResolution(idx) > res) {
          final parent = _h3.cellToParent(idx, res);
          final best = aggregated[parent];
          if (best == null || tile.sampleCount > best.sampleCount) aggregated[parent] = tile;
          continue;
        }
      }
      _tileById[tile.h3Index] = tile;
      final isNew = _isNewSince(tile);
      final sensor = widget.mapLayer == MapLayer.quality ? null : _layerStyle(tile);
      final color = sensor?.color ?? (isNew ? _newColorHex(tile) : _colorHex(tile));
      final fillOpacity = sensor?.fill ?? (isNew ? 0.32 : _fillOpacity(tile));
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
          'borderOpacity': sensor?.stroke ?? _strokeOpacity(tile),
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

    for (final MapEntry(key: parent, value: tile) in aggregated.entries) {
      final agg = widget.mapLayer == MapLayer.quality ? null : _layerStyle(tile);
      final ring = _h3.cellToBoundary(parent).map((c) => [c.lon, c.lat]).toList();
      features.add({
        'type': 'Feature',
        'properties': {
          'h3Index': '', // no single tile behind it: a tap zooms in instead
          'parent': parent.toRadixString(16),
          'color': agg?.color ?? _colorHex(tile),
          'fillOpacity': agg?.fill ?? _fillOpacity(tile),
          'borderOpacity': agg?.stroke ?? _strokeOpacity(tile),
          'borderWidth': tile.isGlobal ? 0.0 : 1.2,
          'label': '',
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [[...ring, ring.first]],
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Separate point GeoJSON for hex labels — MapLibre symbol layers need Point geometry.
  /// Labels belong to the finest band (the layer's minzoom matches it).
  Map<String, dynamic> _labelsGeoJson() {
    final features = <Map<String, dynamic>>[];
    for (final tile in widget.tiles) {
      // Contributor count, only when more than one (Helium hides the label at 1):
      // it says the cell is shared; the quality detail lives in the cell sheet.
      if (tile.deviceCount <= 1 || tile.boundary == null || tile.boundary!.isEmpty) continue;
      final lats = tile.boundary!.map((p) => p.latitude);
      final lngs = tile.boundary!.map((p) => p.longitude);
      final cLat = lats.reduce((a, b) => a + b) / tile.boundary!.length;
      final cLng = lngs.reduce((a, b) => a + b) / tile.boundary!.length;
      final opacity = _fillOpacity(tile);
      final labelText = '${tile.deviceCount}';
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

  /// Value a tile contributes to the current [MapLayer], or null if it has none.
  /// Light uses log10(lux + 1): perceived brightness is roughly logarithmic and
  /// lux spans five orders of magnitude, so a linear rank would lump night together.
  double? _layerValue(H3Tile tile) => switch (widget.mapLayer) {
        MapLayer.quality => null,
        MapLayer.light => tile.avgLux == null ? null : log(tile.avgLux! + 1) / ln10,
        MapLayer.pressure => tile.avgHpa,
        MapLayer.movement => tile.avgMovement,
      };

  /// Sorted layer values of the current tiles: intensity is a tile's rank among
  /// them (its empirical CDF), so no threshold is hand-set and the scale adapts
  /// to wherever the user maps.
  List<double> _layerSorted = const [];

  void _rebuildLayerRanks() {
    _layerSorted = widget.tiles.map(_layerValue).whereType<double>().toList()..sort();
  }

  /// Colour, fill and border for a tile under a sensor layer.
  ({String color, double fill, double stroke}) _layerStyle(H3Tile tile) {
    final v = _layerValue(tile);
    final hex = switch (widget.mapLayer) {
      MapLayer.light => '#fbbf24',
      MapLayer.pressure => '#0ea5e9',
      _ => '#14b8a6',
    };
    if (v == null || _layerSorted.isEmpty) return (color: '#64748b', fill: 0.06, stroke: 0.0);
    var lo = 0, hi = _layerSorted.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_layerSorted[mid] < v) { lo = mid + 1; } else { hi = mid; }
    }
    final rank = _layerSorted.length == 1 ? 1.0 : lo / (_layerSorted.length - 1);
    final f = _freshnessFactor(tile);
    return (color: hex, fill: (0.12 + 0.5 * rank) * f, stroke: (0.3 + 0.5 * rank) * f);
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

  /// Continuous exponential freshness decay — the time term of a
  /// spatiotemporal covariance kernel (Gneiting/Cressie-Huang class), used
  /// here instead of a stepped multiplier so opacity never visibly "jumps"
  /// between app opens (a sudden jump reads as a glitch). Floors at
  /// [_kFreshnessFloor] so a tile recedes but never fades to invisible —
  /// full fade would read as lost data, not a design signal.
  static const _kFreshnessHalfLifeDays = 45.0;
  static const _kFreshnessFloor = 0.35;

  static double _freshnessFactor(H3Tile tile) {
    if (tile.lastUpdate == null) return 1.0;
    final ageDays = DateTime.now().difference(tile.lastUpdate!).inHours / 24.0;
    final decay = exp(-ln2 * ageDays / _kFreshnessHalfLifeDays);
    return _kFreshnessFloor + (1 - _kFreshnessFloor) * decay;
  }

  static double _fillOpacity(H3Tile tile) {
    if (tile.isGlobal) return 0.18;
    final q = _qualityPct(tile);
    final base = q >= 75 ? 0.45 : q >= 50 ? 0.36 : 0.28;
    return base * _freshnessFactor(tile);
  }

  static double _strokeOpacity(H3Tile tile) {
    if (tile.isGlobal) return 0.0;
    final q = _qualityPct(tile);
    final base = q >= 75 ? 0.75 : q >= 50 ? 0.60 : 0.45;
    return base * _freshnessFactor(tile);
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

    // Band zoom ranges depend on latitude (Mercator scale); the area a user maps
    // spans far less than a degree, so the latitude at load time is enough.
    final lat = ctrl.cameraPosition?.target.latitude ?? _initialCenter.latitude;
    _bandRanges = {for (final r in _kBandRes) r: _bandRange(r, lat)};
    debugPrint('MapLibre: bands ${_bandRanges.entries.map((e) => 'r${e.key} ${e.value.from.toStringAsFixed(1)}..${e.value.to.toStringAsFixed(1)}').join(', ')}');

    // ── Add sources (empty, populated below) ──
    await Future.wait([
      for (final r in _kBandRes) ctrl.addGeoJsonSource(_gridSource(r), _kEmptyFC),
      for (final r in _kDataBands) ctrl.addGeoJsonSource(_tileSource(r), _kEmptyFC),
      ctrl.addGeoJsonSource(_kSourceHeat, _kEmptyFC),
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
    // One grid and one data layer pair per resolution band. Each band's opacity
    // is a zoom expression, so the map engine cross-fades bands every frame
    // while zooming; nothing is swapped in after the camera stops.
    for (final r in _kBandRes) {
      final range = _bandRanges[r]!;
      await ctrl.addFillLayer(
        _gridSource(r),
        _gridFillLayer(r),
        FillLayerProperties(
          fillColor: '#1a3a52', // dark blue-teal, clearly distinct from #111927 base
          fillOpacity: _bandOpacity(range, 0.40),
        ),
      );
      await ctrl.addLineLayer(
        _gridSource(r),
        _gridLineLayer(r),
        LineLayerProperties(
          lineColor: '#ffffff',
          lineOpacity: _bandOpacity(range, 0.06),
          lineWidth: 0.5,
        ),
      );
    }
    // The heatmap layer is added by _refreshHeatmap once its radius is known
    // (it depends on the data, and the plugin cannot update heatmap properties).
    for (final r in _kDataBands) {
      final range = _bandRanges[r]!;
      await ctrl.addFillLayer(
        _tileSource(r),
        _tileFillLayer(r),
        FillLayerProperties(
          fillColor: ['get', 'color'],
          fillOpacity: _bandOpacity(range, ['get', 'fillOpacity']),
        ),
        enableInteraction: true,
      );
      await ctrl.addLineLayer(
        _tileSource(r),
        _tileLineLayer(r),
        LineLayerProperties(
          lineColor: ['get', 'color'],
          lineOpacity: _bandOpacity(range, ['get', 'borderOpacity']),
          lineWidth: ['get', 'borderWidth'],
        ),
      );
    }

    // ── Pending cells — session tiles not yet confirmed by backend ──
    // Slightly lower opacity than confirmed tiles; dashed border signals "in-flight".
    await ctrl.addFillLayer(
      _kSourcePending,
      _kLayerPendingFill,
      const FillLayerProperties(
        fillColor: AppColors.primaryHex,
        fillOpacity: 0.18,
      ),
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
      minzoom: _bandRanges[9]!.from,
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
      ..._refreshTileSources(ctrl),
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

  /// Heatmap of the mapped cells. A Gaussian kernel density is the solution of
  /// the diffusion (heat) equation started from the cell centres, with
  /// bandwidth h² = 2Dt; h is not hand-set but estimated from the data with
  /// Silverman's rule, h = 1.06·σ·n^(-1/5). The on-screen radius is the larger
  /// of 3h (Gaussian support) and WeatherXM's display radius (2 px at zoom 0 to
  /// 20 px at zoom 9), so a dense but tiny cluster still shows at world zoom.
  List<Future<void>> _refreshHeatmap(MapLibreMapController ctrl) {
    final pts = <(double, double)>[
      for (final t in widget.tiles)
        if (t.centroid != null) (t.centroid!.latitude, t.centroid!.longitude),
    ];
    final features = [
      for (final (lat, lng) in pts)
        {'type': 'Feature', 'properties': <String, dynamic>{}, 'geometry': {'type': 'Point', 'coordinates': [lng, lat]}},
    ];
    double hM = _kH3EdgeM[9]!; // one personal cell when there is too little data
    double lat0 = _initialCenter.latitude;
    if (pts.length >= 2) {
      lat0 = pts.map((p) => p.$1).reduce((a, b) => a + b) / pts.length;
      final lng0 = pts.map((p) => p.$2).reduce((a, b) => a + b) / pts.length;
      final k = 111000 * cos(lat0 * pi / 180);
      final vx = pts.map((p) => pow((p.$2 - lng0) * k, 2)).reduce((a, b) => a + b) / (pts.length - 1);
      final vy = pts.map((p) => pow((p.$1 - lat0) * 111000, 2)).reduce((a, b) => a + b) / (pts.length - 1);
      final sigma = sqrt((vx + vy) / 2);
      if (sigma > 0) hM = 1.06 * sigma * pow(pts.length, -0.2);
    }
    final mpp0 = 40075016.686 * cos(lat0 * pi / 180) / 512; // metres per pixel at zoom 0
    final stops = <dynamic>[];
    for (var z = 0; z <= 12; z++) {
      final kernelPx = 3 * hM * pow(2, z) / mpp0;
      final displayPx = 2 + 18 * min(z, 9) / 9;
      stops..add(z.toDouble())..add(max(kernelPx, displayPx));
    }
    return [
      ctrl.setGeoJsonSource(_kSourceHeat, {'type': 'FeatureCollection', 'features': features}),
      _placeHeatmapLayer(ctrl, stops),
    ];
  }

  /// Radius stops the heatmap layer was last created with.
  String? _heatStopsKey;

  /// The maplibre_gl plugin cannot set heatmap properties after creation
  /// (UNSUPPORTED_LAYER_TYPE on Android), so the layer is recreated, under the
  /// data layers, whenever the data-derived radius changes.
  Future<void> _placeHeatmapLayer(MapLibreMapController ctrl, List<dynamic> stops) async {
    final key = stops.map((s) => (s as num).toStringAsFixed(2)).join(',');
    if (key == _heatStopsKey) return;
    if (_heatStopsKey != null) {
      try {
        await ctrl.removeLayer(_kLayerHeat);
      } catch (_) {}
    }
    _heatStopsKey = key;
    // Zoomed out past the data bands, density reads better than hexagons a few
    // pixels wide: the heatmap takes over, cross-fading at the coarsest data band.
    await ctrl.addHeatmapLayer(
      _kSourceHeat,
      _kLayerHeat,
      HeatmapLayerProperties(
        heatmapRadius: ['interpolate', ['linear'], ['zoom'], ...stops],
        heatmapColor: [
          'interpolate', ['linear'], ['heatmap-density'],
          0, 'rgba(16,185,129,0)',
          0.3, 'rgba(16,185,129,0.35)',
          1, 'rgba(16,185,129,0.85)',
        ],
        heatmapOpacity: _bandOpacity((from: double.negativeInfinity, to: _bandRanges[_kDataMinRes]!.from), 1.0),
      ),
      belowLayerId: _tileFillLayer(_kDataMinRes),
    );
  }

  /// Rebuilds every band's data tiles (cheap: aggregation of the tile list).
  List<Future<void>> _refreshTileSources(MapLibreMapController ctrl) {
    _tileById.clear();
    _rebuildLayerRanks();
    return [
      for (final r in _kDataBands) ctrl.setGeoJsonSource(_tileSource(r), _tilesToGeoJson(r)),
      ..._refreshHeatmap(ctrl),
      ctrl.setGeoJsonSource('gg-labels', _labelsGeoJson()),
    ];
  }

  /// Rebuilds the grid of the band shown at the current zoom and of the bands
  /// next to it, so zooming in or out cross-fades into a grid that is already
  /// there. Each band is a disk sized to the padded viewport: a few hundred cells.
  Future<void> _refreshGrid() async {
    final ctrl = _ctrl;
    if (!_styleLoaded || ctrl == null || _bandRanges.isEmpty) return;

    // ctrl.cameraPosition is only kept current when trackCameraPosition is on
    // (it is off), so it stayed at the start position: query the live camera.
    final camera = await ctrl.queryCameraPosition();
    if (camera == null) return;
    final center = camera.target;
    final zoom = camera.zoom;

    LatLngBounds region;
    try {
      region = await ctrl.getVisibleRegion();
    } catch (_) {
      return;
    }

    // 50% padding: a pan of half a screen stays covered until the next refresh.
    final latHalfM = (region.northeast.latitude - region.southwest.latitude) * 1.0 * 111000;
    final lngHalfM = (region.northeast.longitude - region.southwest.longitude) * 1.0 *
        111000 * cos(center.latitude * pi / 180);
    final halfDiagonalM = sqrt(latHalfM * latHalfM + lngHalfM * lngHalfM);

    // Bands within one zoom step of the current zoom. A finer band is reached by
    // zooming in (view about halved), a coarser one by zooming out (about doubled).
    final bands = <(int, int)>[];
    for (final r in _kBandRes) {
      final range = _bandRanges[r]!;
      if (zoom < range.from - 1.0 || zoom > range.to + 1.0) continue;
      final scale = zoom < range.from ? 0.5 : (zoom > range.to ? 2.0 : 1.0);
      // Rebuild only when the view would leave the disk already on screen:
      // every rebuild swaps the GeoJSON source, which MapLibre redraws visibly.
      // The view's own half-diagonal is half the padded one computed above.
      final cover = _gridCover[r];
      if (cover != null) {
        final dLat = (center.latitude - cover.lat) * 111000;
        final dLng = (center.longitude - cover.lng) * 111000 * cos(center.latitude * pi / 180);
        if (sqrt(dLat * dLat + dLng * dLng) + halfDiagonalM * scale / 2 < cover.radiusM) continue;
      }
      final k = _diskK(halfDiagonalM * scale, r);
      _gridCover[r] = (lat: center.latitude, lng: center.longitude, radiusM: 1.5 * k * _kH3EdgeM[r]!);
      bands.add((r, k));
    }
    if (bands.isEmpty) return;

    final gen = ++_gridGeneration;
    Map<int, Map<String, dynamic>> grids;
    try {
      grids = await compute(_buildGrids, (
        centerLat: center.latitude,
        centerLng: center.longitude,
        bands: bands,
      ));
    } catch (e) {
      debugPrint('MapLibre: grid compute error: $e');
      return;
    }

    // A newer refresh superseded this one: forget its centres so it rebuilds.
    if (gen != _gridGeneration || !_styleLoaded || _ctrl == null) {
      for (final (r, _) in bands) {
        _gridCover.remove(r);
      }
      return;
    }
    await Future.wait([
      for (final MapEntry(key: r, value: fc) in grids.entries)
        ctrl.setGeoJsonSource(_gridSource(r), fc),
    ]);
    debugPrint('MapLibre: grid zoom ${zoom.toStringAsFixed(2)} built '
        '${grids.entries.map((e) => 'r${e.key}:${(e.value['features'] as List).length}').join(' ')}');
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
      return;
    }
    // An aggregated hexagon stands for several finer tiles: zoom into it, the
    // way Helium and WeatherXM expand a cluster, until the tiles are tappable.
    final parent = await _hitTestParent(point);
    final ctrl = _ctrl;
    if (parent == null || ctrl == null) return;
    final res = _h3.getResolution(parent);
    final finer = _kBandRes.contains(res + 1) ? _bandRanges[res + 1] : null;
    final c = _h3.cellToGeo(parent);
    await ctrl.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(c.lat, c.lon),
      finer != null ? finer.from + 0.6 : 14.0,
    ));
  }

  /// H3 index of an aggregated parent hexagon at [point], if any.
  Future<BigInt?> _hitTestParent(Point<double> point) async {
    final ctrl = _ctrl;
    if (ctrl == null) return null;
    final features = await ctrl.queryRenderedFeatures(
        point, [for (final r in _kDataBands) _tileFillLayer(r)], null);
    for (final f in features) {
      final props = (f as Map<Object?, Object?>?)?['properties'] as Map<Object?, Object?>?;
      final p = props?['parent'] as String?;
      if (p != null && p.isNotEmpty) return BigInt.tryParse(p, radix: 16);
    }
    return null;
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
        await ctrl.queryRenderedFeatures(point, [for (final r in _kDataBands) _tileFillLayer(r)], null);
    if (features.isEmpty) return null;
    final props = (features.first as Map<Object?, Object?>?)
        ?['properties'] as Map<Object?, Object?>?;
    final h3Index = props?['h3Index'] as String?;
    return h3Index != null ? _tileById[h3Index] : null;
  }

  // ── Widget lifecycle ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _showMapHint = !AppPreferences.instance.isTipDismissed('map_tap_hint');
    WidgetsBinding.instance.addObserver(this);
  }

  /// The halo pulse is a purely decorative 16fps loop (`_startHaloPulse`). Nothing
  /// stopped it while the app was backgrounded or the screen was off — a foreground
  /// service keeps the process (and the Dart isolate's timers) alive well past
  /// screen-off, so it kept firing forever: measured ~19% sustained CPU with the
  /// screen off and locked, most of it this timer repeatedly failing to apply its
  /// own style properties (the native layer only accepts them while the map surface
  /// is actually visible). Pausing it here and restarting on resume is the standard
  /// Flutter pattern for exactly this (WidgetsBindingObserver.didChangeAppLifecycleState).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_styleLoaded && mounted) _startHaloPulse();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _haloTimer?.cancel();
    }
  }

  @override
  void didUpdateWidget(CoverageMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recenterTrigger != widget.recenterTrigger) {
      oldWidget.recenterTrigger?.removeListener(_onRecenter);
      widget.recenterTrigger?.addListener(_onRecenter);
    }
    if (!_styleLoaded) return;

    final tilesChanged = !identical(oldWidget.tiles, widget.tiles) ||
        oldWidget.mapLayer != widget.mapLayer;
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
    WidgetsBinding.instance.removeObserver(this);
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
                          // Who and how much is behind this cell (WeatherXM's cell
                          // screen lists its stations the same way).
                          const SizedBox(height: AppTheme.spaceXxs),
                          Text(
                            isPersonal && tile.deviceCount <= 1
                                ? '${l10n.tileOnlyYouMapped} · ${l10n.tileMeasurements(tile.sampleCount)}'
                                : '${l10n.tileContributors(tile.deviceCount)} · ${l10n.tileMeasurements(tile.sampleCount)}',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeXs,
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
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

