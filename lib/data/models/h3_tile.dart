import 'package:latlong2/latlong.dart';

/// H3 hexagon tile model — represents a single coverage cell.
class H3Tile {
  final String h3Index;
  final double confidence; // 0.0–1.0
  /// Composite data quality score: sampleConfidence × quality_valid_ratio.
  /// Only populated for global tiles (null for personal tiles which lack
  /// aggregated quality_valid_ratio). Range 0.0–1.0.
  final double? qualityScore;
  final int sampleCount;
  final int deviceCount;
  final List<LatLng>? boundary;
  /// When this tile was last contributed to — shown in TileInfoSheet.
  final DateTime? lastUpdate;

  /// True for community/global tiles (other users); false for personal tiles.
  final bool isGlobal;

  const H3Tile({
    required this.h3Index,
    required this.confidence,
    this.qualityScore,
    required this.sampleCount,
    required this.deviceCount,
    this.boundary,
    this.lastUpdate,
    this.isGlobal = false,
  });

  /// Parses a tile from the backend API JSON.
  /// API returns boundary as [[lng, lat], ...] (GeoJSON order) — flipped to LatLng(lat, lng).
  factory H3Tile.fromJson(Map<String, dynamic> json, {bool isGlobal = false}) {
    final hexIndex = json['h3Index'] as String? ?? '';
    List<LatLng>? boundary;
    final rawBoundary = json['boundary'] as List<dynamic>?;
    if (rawBoundary != null && rawBoundary.isNotEmpty) {
      try {
        boundary = rawBoundary.map((pt) {
          final pair = pt as List<dynamic>;
          return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
        }).toList();
      } catch (_) {}
    }
    DateTime? lastUpdate;
    final rawLastUpdate = json['lastUpdate'] as String?;
    if (rawLastUpdate != null) {
      lastUpdate = DateTime.tryParse(rawLastUpdate);
    }
    return H3Tile(
      h3Index: hexIndex,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      qualityScore: (json['qualityScore'] as num?)?.toDouble(),
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      deviceCount: (json['deviceCount'] as num?)?.toInt() ?? 1,
      boundary: boundary,
      lastUpdate: lastUpdate,
      isGlobal: isGlobal,
    );
  }
}
