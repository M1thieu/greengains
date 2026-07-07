import 'package:flutter/foundation.dart';
import '../network/backend_client.dart';
import '../../core/constants.dart';

export '../network/api_models.dart' show UserProfileResponse, GlobalStatsResponse, WeeklyTargetResponse, LocalRankResponse, ImpactResponse, WeeklyInsightResponse;

/// Centralizes all backend calls related to user stats and weekly targets.
/// Screens should call this instead of BackendClient directly.
class StatsService {
  StatsService._();
  static final StatsService instance = StatsService._();

  /// Fetches user profile + global community stats in parallel.
  Future<({UserProfileResponse profile, GlobalStatsResponse global})> fetchProfileAndGlobal() async {
    final results = await Future.wait([
      BackendClient.get(kApiUserProfile),
      BackendClient.get(kApiStatsGlobal).catchError((_) => <String, dynamic>{}),
    ]);
    return (
      profile: UserProfileResponse.fromJson(results[0]),
      global: GlobalStatsResponse.fromJson(results[1]),
    );
  }

  Future<WeeklyTargetResponse?> fetchWeeklyTarget() async {
    try {
      final data = await BackendClient.get(kApiWeeklyTarget);
      return WeeklyTargetResponse.fromJson(data);
    } catch (e) {
      debugPrint('Weekly target fetch failed: $e');
      return null;
    }
  }

  Future<LocalRankResponse?> fetchLocalRank() async {
    try {
      final data = await BackendClient.get(kApiLocalRank);
      return LocalRankResponse.fromJson(data);
    } catch (e) {
      debugPrint('Local rank fetch failed: $e');
      return null;
    }
  }

  Future<ImpactResponse?> fetchImpact() async {
    try {
      final data = await BackendClient.get(kApiImpact);
      return ImpactResponse.fromJson(data);
    } catch (e) {
      debugPrint('Impact fetch failed: $e');
      return null;
    }
  }

  /// Fetches the weekly street-level insight — roughest route, new zones,
  /// brightest street, solo territory. Powers the civic intelligence card.
  Future<WeeklyInsightResponse?> fetchWeeklyInsight() async {
    try {
      final data = await BackendClient.get(kApiWeeklyInsight);
      return WeeklyInsightResponse.fromJson(data);
    } catch (e) {
      debugPrint('Weekly insight fetch failed: $e');
      return null;
    }
  }
}
