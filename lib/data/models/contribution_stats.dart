/// Simple model for contribution statistics
class ContributionStats {
  final int totalUploads;
  final int uploadsToday;
  final int currentStreak;
  final int coverageCells; // distinct H3 res-9 cells ever contributed (~174m hex)
  final DateTime? loadedAt; // When these stats were last fetched

  const ContributionStats({
    required this.totalUploads,
    required this.uploadsToday,
    required this.currentStreak,
    this.coverageCells = 0,
    this.loadedAt,
  });

  static final ContributionStats empty = ContributionStats(
    totalUploads: 0,
    uploadsToday: 0,
    currentStreak: 0,
    coverageCells: 0,
    loadedAt: DateTime.now(),
  );
}

class TileCoverageStats {
  final int dayTiles;
  final int nightTiles;

  const TileCoverageStats({
    required this.dayTiles,
    required this.nightTiles,
  });

  int get totalTiles => dayTiles + nightTiles;

  static const TileCoverageStats empty = TileCoverageStats(
    dayTiles: 0,
    nightTiles: 0,
  );
}
