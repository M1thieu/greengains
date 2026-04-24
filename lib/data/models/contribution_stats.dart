/// Simple model for contribution statistics
class ContributionStats {
  final int totalUploads;
  final int uploadsToday;
  final int uploadsThisWeek;
  final int currentStreak;
  final int coverageCells; // distinct H3 res-9 cells ever contributed (~174m hex)
  final DateTime? loadedAt; // When these stats were last fetched
  final DateTime? firstContributionAt; // When the user first contributed — archive anchor

  const ContributionStats({
    required this.totalUploads,
    required this.uploadsToday,
    required this.uploadsThisWeek,
    required this.currentStreak,
    this.coverageCells = 0,
    this.loadedAt,
    this.firstContributionAt,
  });

  static final ContributionStats empty = ContributionStats(
    totalUploads: 0,
    uploadsToday: 0,
    uploadsThisWeek: 0,
    currentStreak: 0,
    coverageCells: 0,
    loadedAt: DateTime.now(),
  );
}

