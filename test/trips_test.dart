import 'package:flutter_test/flutter_test.dart';
import 'package:greengains/core/trips.dart';

void main() {
  const min = 60 * 1000;
  final t0 = DateTime(2026, 10, 5, 9).millisecondsSinceEpoch;

  test('splits two outings separated by a long pause', () {
    // Morning: 10 uploads 5 min apart; evening: 8 uploads 5 min apart, 8 h later.
    final pts = <(int, String?)>[
      for (var i = 0; i < 10; i++) (t0 + i * 5 * min, 'u0d${i % 3}'),
      for (var i = 0; i < 8; i++) (t0 + 8 * 60 * min + i * 5 * min, 'u0e$i'),
    ];
    final trips = buildTrips(pts);
    expect(trips.length, 2);
    expect(trips.first.uploads, 8); // newest first
    expect(trips.first.places, 8);
    expect(trips.last.uploads, 10);
    expect(trips.last.places, 3);
    expect(trips.last.duration, const Duration(minutes: 45));
  });

  test('irregular cadence inside one outing is not a break', () {
    final gaps = [5, 6, 4, 7, 5, 9, 5, 6, 4, 5];
    var t = t0;
    final pts = <(int, String?)>[(t, 'a')];
    for (final g in gaps) {
      t += g * min;
      pts.add((t, 'a'));
    }
    expect(buildTrips(pts).length, 1);
  });

  test('too few uploads to estimate a pause: one trip', () {
    final pts = <(int, String?)>[(t0, 'a'), (t0 + 600 * min, 'b'), (t0 + 601 * min, 'b')];
    expect(buildTrips(pts).length, 1);
  });

  test('empty input', () => expect(buildTrips(const []), isEmpty));
}
