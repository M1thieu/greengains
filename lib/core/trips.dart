/// Groups successful uploads into trips, the way dawarich splits a location
/// history into trips at long pauses.
///
/// No pause length is hand-set: while tracking, uploads follow each other at the
/// batch cadence, so the gaps between consecutive uploads form one population
/// and the pauses between outings are its outliers. A gap is a trip break when
/// it lies beyond Tukey's "far out" fence, Q3 + 3·IQR, of all gaps (Tukey,
/// Exploratory Data Analysis, 1977).
library;

class Trip {
  const Trip({
    required this.start,
    required this.end,
    required this.uploads,
    required this.places,
  });

  final DateTime start;
  final DateTime end;
  final int uploads;

  /// Distinct stored geohash cells visited during the trip.
  final int places;

  Duration get duration => end.difference(start);
}

/// Minimum number of gaps for quartiles to mean anything; below it there is
/// no evidence of a pause, so everything is one trip.
const int _kMinGapsForFence = 4;

/// [points] are (epoch ms, geohash) of successful uploads, in any order.
/// Returns trips newest first.
List<Trip> buildTrips(List<(int, String?)> points) {
  if (points.isEmpty) return const [];
  final sorted = [...points]..sort((a, b) => a.$1.compareTo(b.$1));

  final gaps = [for (var i = 1; i < sorted.length; i++) sorted[i].$1 - sorted[i - 1].$1];
  final fence = gaps.length >= _kMinGapsForFence ? _tukeyFarOutFence(gaps) : double.infinity;

  final trips = <Trip>[];
  var startIdx = 0;
  for (var i = 1; i <= sorted.length; i++) {
    final isBreak = i == sorted.length || (sorted[i].$1 - sorted[i - 1].$1) > fence;
    if (!isBreak) continue;
    final slice = sorted.sublist(startIdx, i);
    trips.add(Trip(
      start: DateTime.fromMillisecondsSinceEpoch(slice.first.$1),
      end: DateTime.fromMillisecondsSinceEpoch(slice.last.$1),
      uploads: slice.length,
      places: slice.map((p) => p.$2).whereType<String>().toSet().length,
    ));
    startIdx = i;
  }
  return trips.reversed.toList();
}

double _tukeyFarOutFence(List<int> values) {
  final v = [...values]..sort();
  double quantile(double q) {
    final pos = q * (v.length - 1);
    final lo = pos.floor();
    final hi = pos.ceil();
    return v[lo] + (v[hi] - v[lo]) * (pos - lo);
  }

  final q1 = quantile(0.25);
  final q3 = quantile(0.75);
  return q3 + 3 * (q3 - q1);
}
