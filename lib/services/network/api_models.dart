import '../../data/models/h3_tile.dart';

export '../../data/models/h3_tile.dart';

// ── Tile responses ──────────────────────────────────────────────────────────

class UserTilesResponse {
  final List<H3Tile> tiles;
  const UserTilesResponse(this.tiles);

  factory UserTilesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['tiles'] as List<dynamic>? ?? [];
    return UserTilesResponse(
      raw.map((t) => H3Tile.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}

class GlobalTilesResponse {
  final List<H3Tile> tiles;
  const GlobalTilesResponse(this.tiles);

  factory GlobalTilesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['tiles'] as List<dynamic>? ?? [];
    return GlobalTilesResponse(
      raw.map((t) => H3Tile.fromJson(t as Map<String, dynamic>, isGlobal: true)).toList(),
    );
  }
}

// ── Profile response ────────────────────────────────────────────────────────

class UserProfileResponse {
  final int totalUploads;
  final int uploadsToday;
  final int daysActive;
  final int currentStreak;
  final int longestStreak;
  final int coverageCells;
  final int deviceCount;
  final List<int> weekly;
  final int? qualityPct;
  final int? bestDayCount;
  final double? avgPerDay;
  final int? prevWeekTotal;

  const UserProfileResponse({
    required this.totalUploads,
    required this.uploadsToday,
    required this.daysActive,
    required this.currentStreak,
    required this.longestStreak,
    required this.coverageCells,
    required this.deviceCount,
    required this.weekly,
    this.qualityPct,
    this.bestDayCount,
    this.avgPerDay,
    this.prevWeekTotal,
  });

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) {
    final s = json['stats'] as Map<String, dynamic>? ?? {};
    final raw = s['weekly'] as List<dynamic>? ?? [];
    return UserProfileResponse(
      totalUploads:  (s['totalUploads']  as num?)?.toInt() ?? 0,
      uploadsToday:  (s['uploadsToday']  as num?)?.toInt() ?? 0,
      daysActive:    (s['daysActive']    as num?)?.toInt() ?? 0,
      currentStreak: (s['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (s['longestStreak'] as num?)?.toInt() ?? 0,
      coverageCells: (s['coverageCells'] as num?)?.toInt() ?? 0,
      deviceCount:   (s['deviceCount']   as num?)?.toInt() ?? 0,
      weekly: raw.map((e) => e is num ? e.toInt() : 0).toList(),
      qualityPct:    (s['qualityPct']    as num?)?.toInt(),
      bestDayCount:  (s['bestDayCount']  as num?)?.toInt(),
      avgPerDay:     (s['avgPerDay']     as num?)?.toDouble(),
      prevWeekTotal: (s['prevWeekTotal'] as num?)?.toInt(),
    );
  }
}

// ── Referral responses ──────────────────────────────────────────────────────

class ReferralCodeResponse {
  final String referralCode;
  const ReferralCodeResponse(this.referralCode);

  factory ReferralCodeResponse.fromJson(Map<String, dynamic> json) =>
      ReferralCodeResponse(json['referralCode']?.toString() ?? '');
}

class ReferralStatsResponse {
  final int invitesShared;
  final int conversions;
  const ReferralStatsResponse({required this.invitesShared, required this.conversions});

  factory ReferralStatsResponse.fromJson(Map<String, dynamic> json) =>
      ReferralStatsResponse(
        invitesShared: (json['invitesShared'] as num?)?.toInt() ?? 0,
        conversions:   (json['conversions']   as num?)?.toInt() ?? 0,
      );
}

// ── Weekly target ───────────────────────────────────────────────────────────

class WeeklyTargetResponse {
  final String weekStart;
  final String weekEnd;
  final int newCellsThisWeek;
  final int target;
  final double pctComplete;

  const WeeklyTargetResponse({
    required this.weekStart,
    required this.weekEnd,
    required this.newCellsThisWeek,
    required this.target,
    required this.pctComplete,
  });

  factory WeeklyTargetResponse.fromJson(Map<String, dynamic> json) =>
      WeeklyTargetResponse(
        weekStart:        json['week_start']?.toString() ?? '',
        weekEnd:          json['week_end']?.toString() ?? '',
        newCellsThisWeek: (json['new_cells_this_week'] as num?)?.toInt() ?? 0,
        target:           (json['target'] as num?)?.toInt() ?? 5,
        pctComplete:      (json['pct_complete'] as num?)?.toDouble() ?? 0.0,
      );
}

// ── Local rank ("Local Legend") ───────────────────────────────────────────────

class LocalRankResponse {
  final bool hasActivity;
  final int rank;
  final int totalMappers;
  final bool isLeader;
  final int ownCellCount;
  final int leaderCellCount;
  final int cellsToLead;

  const LocalRankResponse({
    required this.hasActivity,
    this.rank = 0,
    this.totalMappers = 0,
    this.isLeader = false,
    this.ownCellCount = 0,
    this.leaderCellCount = 0,
    this.cellsToLead = 0,
  });

  factory LocalRankResponse.fromJson(Map<String, dynamic> json) =>
      LocalRankResponse(
        hasActivity:     json['hasActivity'] as bool? ?? false,
        rank:            (json['rank'] as num?)?.toInt() ?? 0,
        totalMappers:    (json['totalMappers'] as num?)?.toInt() ?? 0,
        isLeader:        json['isLeader'] as bool? ?? false,
        ownCellCount:    (json['ownCellCount'] as num?)?.toInt() ?? 0,
        leaderCellCount: (json['leaderCellCount'] as num?)?.toInt() ?? 0,
        cellsToLead:     (json['cellsToLead'] as num?)?.toInt() ?? 0,
      );
}

// ── Impact ("only you've ever mapped this") ───────────────────────────────────

class ImpactResponse {
  final bool hasActivity;
  final int totalCells;
  final int soloCells;

  const ImpactResponse({
    required this.hasActivity,
    this.totalCells = 0,
    this.soloCells = 0,
  });

  factory ImpactResponse.fromJson(Map<String, dynamic> json) =>
      ImpactResponse(
        hasActivity: json['hasActivity'] as bool? ?? false,
        totalCells:  (json['totalCells'] as num?)?.toInt() ?? 0,
        soloCells:   (json['soloCells'] as num?)?.toInt() ?? 0,
      );
}

// ── Weekly insight ("what your city is doing to you this week") ───────────────

class WeeklyInsightResponse {
  final bool hasActivity;
  final int newZonesThisWeek;
  final int totalZones;
  final int soloZones;
  final String? roughestStreet;
  final double? roughestVibration;
  final int? roughestPercentile;
  final String? brightestStreet;
  final double? brightestLux;
  final String weekStart;
  final String weekEnd;

  const WeeklyInsightResponse({
    required this.hasActivity,
    this.newZonesThisWeek = 0,
    this.totalZones = 0,
    this.soloZones = 0,
    this.roughestStreet,
    this.roughestVibration,
    this.roughestPercentile,
    this.brightestStreet,
    this.brightestLux,
    this.weekStart = '',
    this.weekEnd = '',
  });

  factory WeeklyInsightResponse.fromJson(Map<String, dynamic> json) =>
      WeeklyInsightResponse(
        hasActivity:        json['hasActivity'] as bool? ?? false,
        newZonesThisWeek:   (json['newZonesThisWeek'] as num?)?.toInt() ?? 0,
        totalZones:         (json['totalZones'] as num?)?.toInt() ?? 0,
        soloZones:          (json['soloZones'] as num?)?.toInt() ?? 0,
        roughestStreet:     json['roughestStreet'] as String?,
        roughestVibration:  (json['roughestVibration'] as num?)?.toDouble(),
        roughestPercentile: (json['roughestPercentile'] as num?)?.toInt(),
        brightestStreet:    json['brightestStreet'] as String?,
        brightestLux:       (json['brightestLux'] as num?)?.toDouble(),
        weekStart:          json['weekStart'] as String? ?? '',
        weekEnd:            json['weekEnd'] as String? ?? '',
      );
}

// ── Community stats ─────────────────────────────────────────────────────────

class GlobalStatsResponse {
  final int activeMappers;
  final int totalZones;
  const GlobalStatsResponse({required this.activeMappers, required this.totalZones});

  factory GlobalStatsResponse.fromJson(Map<String, dynamic> json) =>
      GlobalStatsResponse(
        activeMappers: (json['activeMappers'] as num?)?.toInt() ?? 0,
        totalZones:    (json['totalZones']    as num?)?.toInt() ?? 0,
      );
}
