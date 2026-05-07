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
