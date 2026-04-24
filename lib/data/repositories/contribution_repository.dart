import '../local/database_helper.dart';
import '../models/contribution_stats.dart';

/// Repository for contribution statistics
class ContributionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Get current statistics
  Future<ContributionStats> getStats() async {
    final results = await Future.wait([
      _db.getTotalCount(),
      _db.getTodayCount(),
      _db.getWeekCount(),
      _db.getStreak(),
      _db.getFirstContributionDate(),
    ]);

    return ContributionStats(
      totalUploads: results[0] as int,
      uploadsToday: results[1] as int,
      uploadsThisWeek: results[2] as int,
      currentStreak: results[3] as int,
      firstContributionAt: results[4] as DateTime?,
      loadedAt: DateTime.now(),
    );
  }

}
