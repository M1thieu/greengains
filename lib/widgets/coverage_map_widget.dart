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
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../data/models/h3_tile.dart';
import '../core/app_preferences.dart';
import '../l10n/app_localizations.dart';
import 'time_ago_text.dart';

export '../data/models/h3_tile.dart';

/// What colours the data tiles: overall quality, or one sensor.
// No pressure layer: absolute pressure per cell depends on altitude and on each
// phone's 1-2 hPa offset, so colouring cells by it would not be a measurement.
enum MapLayer { quality, light, movement }

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
const _kSourceNewCells   = 'gg-new';
const _kLayerNewCells    = 'gg-new-line';

/// How long newly confirmed cells stay outlined. A redraw of the whole layer
/// hides which cells changed (Rensink, O'Regan & Clark 1997); a local trace
/// fixes it (Baudisch et al. 2006, where 2 s traces were disliked), and
/// ~1 s transitions are recommended (Heer & Robertson 2007).
const _kNewCellGlow = Duration(seconds: 1);
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
  Timer? _newCellTimer;
  /// Personal cell ids last shown; null until the first tile list arrives so
  /// the initial load is not outlined as "new".
  Set<String>? _knownCellIds;
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
          'h3Index': '', // no single tile behind it: taps summarise the cell instead
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
      MapLayer.light => AppColors.lightHex,
      _ => AppColors.movementHex,
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

  /// One hue per category (own readings vs community); quality is carried by
  /// transparency in [_fillOpacity], not by a green/amber/red hue, which
  /// readers misjudge for uncertainty (MacEachren et al. 2012; Kinkeldey et
  /// al. 2014 review of 44 studies) and which breaks hue-as-category (Brewer).
  static String _colorHex(H3Tile tile) =>
      tile.isGlobal ? '#059669' /* emerald-600, muted */ : AppColors.primaryHex;

  /// Community tiles new since last session: full emerald so they stand out.
  static String _newColorHex(H3Tile tile) => AppColors.primaryHex;

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
      ctrl.addGeoJsonSource(_kSourceNewCells, _kEmptyFC),
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

    // Zoomed out past the data bands, density reads better than hexagons a few
    // pixels wide: a heatmap takes over, cross-fading at the coarsest data band.
    // Radius is zoom-only (2 px at zoom 0 to 20 px at zoom 9), not data-driven —
    // the exact interpolation WeatherXM's own app ships (ExplorerViewModel.kt,
    // heatmapRadius). The maplibre_gl Android plugin has no case for HeatmapLayer
    // in its layer#setProperties switch (MapLibreMapController.java), so any
    // later property change needs removeLayer+addHeatmapLayer, which flashes the
    // layer blank for a frame — a fixed expression means that never has to
    // happen: the layer is created exactly once, here, and only its GeoJSON
    // source data is ever touched again (_refreshHeatmap), which does not flash.
    await ctrl.addHeatmapLayer(
      _kSourceHeat,
      _kLayerHeat,
      HeatmapLayerProperties(
        heatmapRadius: [
          'interpolate', ['linear'], ['zoom'],
          0, 2,
          9, 20,
        ],
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

    // ── Newly confirmed cells — brief outline so the change is seen ──
    await ctrl.addLineLayer(
      _kSourceNewCells,
      _kLayerNewCells,
      const LineLayerProperties(
        lineColor: AppColors.primaryHex,
        lineOpacity: 0.9,
        lineWidth: 3.0,
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
    if (widget.tiles.isNotEmpty) {
      _knownCellIds ??= {for (final t in widget.tiles) if (!t.isGlobal) t.h3Index};
    }
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

  /// Heatmap source data: the mapped cells' centroids. The layer itself (radius,
  /// colour, opacity) is created once at style load and never touched again —
  /// see the comment there for why. Only the point data changes here, a plain
  /// GeoJSON source update, which does not flash.
  Future<void> _refreshHeatmap(MapLibreMapController ctrl) {
    final features = [
      for (final t in widget.tiles)
        if (t.centroid != null)
          {
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': {'type': 'Point', 'coordinates': [t.centroid!.longitude, t.centroid!.latitude]},
          },
    ];
    return ctrl.setGeoJsonSource(_kSourceHeat, {'type': 'FeatureCollection', 'features': features});
  }

  /// Rebuilds every band's data tiles (cheap: aggregation of the tile list).
  List<Future<void>> _refreshTileSources(MapLibreMapController ctrl) {
    _tileById.clear();
    _rebuildLayerRanks();
    return [
      for (final r in _kDataBands) ctrl.setGeoJsonSource(_tileSource(r), _tilesToGeoJson(r)),
      _refreshHeatmap(ctrl),
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

    // Only the band shown at this zoom and its two neighbours. Building every
    // band sent ~17k off-screen polygons per rebuild at low zoom (measured:
    // 2,791 cells x 6 bands at zoom 2.4). One H3 step is ~1.4 zoom levels
    // (edge ratio sqrt 7), so neighbours cover a pinch until the next idle.
    final current = _kBandRes.indexWhere((r) {
      final range = _bandRanges[r]!;
      return zoom >= range.from && zoom < range.to;
    });
    if (current < 0) return;
    final bands = <(int, int)>[];
    for (var i = max(0, current - 1); i <= min(_kBandRes.length - 1, current + 1); i++) {
      final r = _kBandRes[i];
      // Rebuild only when the view would leave the disk already on screen:
      // every rebuild swaps the GeoJSON source, which MapLibre redraws visibly.
      final cover = _gridCover[r];
      if (cover != null) {
        final dLat = (center.latitude - cover.lat) * 111000;
        final dLng = (center.longitude - cover.lng) * 111000 * cos(center.latitude * pi / 180);
        if (sqrt(dLat * dLat + dLng * dLng) + halfDiagonalM / 2 < cover.radiusM) continue;
      }
      final k = _diskK(halfDiagonalM, r);
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

  /// Outlines personal cells that were not in the previous tile list for
  /// [_kNewCellGlow], then clears them.
  void _outlineNewCells() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final personal = [
      for (final t in widget.tiles)
        if (!t.isGlobal && t.boundary != null && t.boundary!.isNotEmpty) t,
    ];
    final known = _knownCellIds;
    _knownCellIds = {for (final t in personal) t.h3Index};
    if (known == null) return;
    final fresh = [for (final t in personal) if (!known.contains(t.h3Index)) t];
    if (fresh.isEmpty) return;
    ctrl.setGeoJsonSource(_kSourceNewCells, {
      'type': 'FeatureCollection',
      'features': [
        for (final t in fresh)
          {
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  for (final p in t.boundary!) [p.longitude, p.latitude],
                  [t.boundary!.first.longitude, t.boundary!.first.latitude],
                ],
              ],
            },
          },
      ],
    });
    _newCellTimer?.cancel();
    _newCellTimer = Timer(_kNewCellGlow, () {
      if (mounted && _styleLoaded) _ctrl?.setGeoJsonSource(_kSourceNewCells, _kEmptyFC);
    });
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

  /// Tap and hold give the same answer (same gesture, same kind of result):
  /// what is known about the cell under the finger at the scale drawn.
  /// Zooming stays on pinch and double-tap.
  void _onMapTap(Point<double> point, LatLng coords) async {
    // Suppress tap if it follows a long press — MapLibre fires onMapClick when
    // the finger lifts after a long press, which would open a duplicate sheet.
    if (DateTime.now().millisecondsSinceEpoch - _lastLongPressMs < 600) return;
    final tile = await _cellInfoAt(point, coords);
    if (tile == null) return;
    _dismissMapHint();
    widget.onTileTap?.call(tile);
  }

  void _dismissMapHint() {
    if (!_showMapHint) return;
    setState(() => _showMapHint = false);
    AppPreferences.instance.dismissTip('map_tap_hint');
  }

  void _onMapLongPress(Point<double> point, LatLng coords) async {
    _lastLongPressMs = DateTime.now().millisecondsSinceEpoch;
    final tile = await _cellInfoAt(point, coords);
    if (tile == null) return;
    _dismissMapHint();
    HapticFeedback.mediumImpact();
    (widget.onTileLongPress ?? widget.onTileTap)?.call(tile);
  }

  /// The mapped cell under [point] at the band drawn now: the tile itself at
  /// the finest band, otherwise a summary of the cells it contains, so
  /// information is reachable at every zoom.
  Future<H3Tile?> _cellInfoAt(Point<double> point, LatLng coords) async {
    final ctrl = _ctrl;
    if (ctrl == null) return null;
    final camera = await ctrl.queryCameraPosition();
    final res = camera == null ? _kBandRes.first : _bandResAt(camera.zoom);
    if (res >= _kBandRes.first) return _hitTestTile(point);
    return _aggregateCell(
        _h3.geoToCell(h3f.GeoCoord(lat: coords.latitude, lon: coords.longitude), res), res);
  }

  /// Resolution of the band drawn at [zoom].
  int _bandResAt(double zoom) {
    for (final r in _kBandRes) {
      final range = _bandRanges[r];
      if (range != null && zoom >= range.from && zoom < range.to) return r;
    }
    return _kBandRes.first;
  }

  /// Summary of every mapped cell inside [cell]: counts summed, sensor means
  /// weighted by sample count (as the backend weights personal tiles) so a
  /// sparse cell does not dilute a dense one. Community tiles already covered
  /// by the user's own cells are skipped, as on the map, to avoid counting the
  /// user's readings twice. Null when nothing was mapped there.
  H3Tile? _aggregateCell(BigInt cell, int res) {
    BigInt? within(H3Tile t) {
      final idx = BigInt.tryParse(t.h3Index, radix: 16);
      if (idx == null) return null;
      final r = _h3.getResolution(idx);
      if (r < res) return null;
      return (r == res ? idx : _h3.cellToParent(idx, res)) == cell ? idx : null;
    }

    final personal = <H3Tile>[];
    final personalRes8 = <BigInt>{};
    for (final t in widget.tiles) {
      if (t.isGlobal) continue;
      final idx = within(t);
      if (idx == null) continue;
      personal.add(t);
      if (_h3.getResolution(idx) >= 8) personalRes8.add(_h3.cellToParent(idx, 8));
    }
    final children = [
      ...personal,
      for (final t in widget.tiles)
        if (t.isGlobal && within(t) != null && !personalRes8.contains(within(t))) t,
    ];
    if (children.isEmpty) return null;

    double? mean(num? Function(H3Tile) value) {
      var sum = 0.0, weight = 0.0;
      for (final t in children) {
        final v = value(t);
        if (v == null) continue;
        final w = max(t.sampleCount, 1).toDouble();
        sum += v * w;
        weight += w;
      }
      return weight == 0 ? null : sum / weight;
    }

    final centre = _h3.cellToGeo(cell);
    final lux = mean((t) => t.avgLux);
    return H3Tile(
      h3Index: cell.toRadixString(16),
      confidence: mean((t) => t.confidence) ?? 0,
      qualityScore: mean((t) => t.qualityScore),
      sampleCount: children.fold(0, (s, t) => s + t.sampleCount),
      deviceCount: children.fold(0, (m, t) => max(m, t.deviceCount)),
      boundary: [for (final c in _h3.cellToBoundary(cell)) ll.LatLng(c.lat, c.lon)],
      lastUpdate: children
          .map((t) => t.lastUpdate)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a),
      centroid: ll.LatLng(centre.lat, centre.lon),
      isGlobal: personal.isEmpty,
      avgLux: lux?.round(),
      avgHpa: mean((t) => t.avgHpa),
      avgMovement: mean((t) => t.avgMovement),
      avgVibration: mean((t) => t.avgVibration),
      qualityRatio: mean((t) => t.qualityRatio),
      placeCount: children.length,
    );
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
    if (!identical(oldWidget.tiles, widget.tiles)) _outlineNewCells();
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
    _newCellTimer?.cancel();
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
                          // Freshness, not a first-mapped date: how recent the
                          // readings are is what tells how far to trust them.
                          if (tile.lastUpdate != null) ...[
                            const SizedBox(height: AppTheme.spaceXxxs),
                            _TimeAgoLine(timestamp: tile.lastUpdate!, isDark: isDark, stale: isStaling),
                          ],
                          // Who and how much is behind this cell (WeatherXM's cell
                          // screen lists its stations the same way).
                          const SizedBox(height: AppTheme.spaceXxs),
                          // A summarised cell names its place count instead: the
                          // distinct contributors across places are not known.
                          Text(
                            tile.placeCount != null
                                ? '${l10n.statsTerritoryZones(tile.placeCount!)} · ${l10n.tileMeasurements(tile.sampleCount)}'
                                : isPersonal && tile.deviceCount <= 1
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
                  ],
                ),
              ),
              // Sensor cards — data-driven, handles 1–N sensors gracefully
              Builder(builder: (context) {
                // Only what a place-level average can honestly say. Absolute
                // pressure per cell depends on altitude and each phone's offset,
                // and at ~5 Hz the vibration score repeats the movement one, so
                // neither is shown (tmp/papers/reports/Capteurs telephone mesure
                // environnement.md).
                final cards = <({IconData icon, Color color, String label})>[
                  if (tile.avgLux != null)
                    (icon: Icons.light_mode_rounded, color: AppColors.light, label: _luxContext(tile.avgLux!, l10n)),
                  if (tile.avgMovement != null)
                    (icon: Icons.directions_walk_rounded, color: AppColors.movement, label: _movementContext(tile.avgMovement!, l10n)),
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
                                label: cards[i].label,
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
              // No separate condition-line sentence: the sensor cards above
              // already say the same thing (e.g. "Dark" for light) — one
              // representation per fact, not a prose restatement of it.
            ],
          ),
        ),
      ),
    );
  }



  static String _luxContext(int lux, AppLocalizations l10n) {
    if (lux < 50) return l10n.sensorLuxDark;
    if (lux < 500) return l10n.sensorLuxIndoor;
    if (lux < 10000) return l10n.sensorLuxBright;
    return l10n.sensorLuxDirect;
  }


  static String _movementContext(double rms, AppLocalizations l10n) {
    if (rms < 0.5) return l10n.sensorMovementLow;
    if (rms < 2.0) return l10n.sensorMovementMid;
    if (rms < 5.0) return l10n.sensorMovementHigh;
    return l10n.sensorMovementIntense;
  }

}



/// "Last seen X ago" line — uses TimeAgoText for locale-aware, live-updating relative time.
class _TimeAgoLine extends StatelessWidget {
  const _TimeAgoLine({required this.timestamp, required this.isDark, this.stale = false});
  final DateTime timestamp;
  final bool isDark;
  /// Old enough that the readings may no longer describe the place.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final color = stale ? AppColors.warning : AppColors.textSecondary(isDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: AppIconSizes.xxs, color: color),
        const SizedBox(width: AppTheme.spaceTiny),
        TimeAgoText(
          timestamp: timestamp,
          style: TextStyle(fontSize: AppTheme.fontSizeXs, color: color),
        ),
      ],
    );
  }
}

/// Tiny sensor card in TileInfoSheet: icon (colour identifies the sensor,
/// same colour used everywhere else in the app) + one plain-language line.
class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.isDark,
  });
  final IconData icon;
  final Color color;
  final String label;
  final bool isDark;

  @override
  // No tinted box per reading: spacing alone groups the row (Han, Humphreys
  // & Chen 1999), and extra containers lower apparent usability (Tractinsky 1997).
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm, horizontal: AppTheme.spaceXs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSizes.sm, color: color),
          const SizedBox(height: AppTheme.spaceTiny),
          // One line, the plain-language state (e.g. "Dark") — the icon's
          // colour already identifies which sensor, matching that colour
          // everywhere else in the app (map layer picker, Settings). No caps
          // title, no raw unit value: one fact, one line.
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
        ],
      ),
    );
  }
}

