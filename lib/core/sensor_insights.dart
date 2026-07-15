import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Translates raw sensor values into human-readable environmental insights.
///
/// All thresholds are calibrated against real-world data:
/// - Lux: outdoor daylight 10k-100k, overcast 1k, indoor 100-500, night street 1-50
/// - Pressure: sea level ~1013 hPa, varies ±30 hPa with weather
/// - Vibration score: 0=glass surface, 0.3=normal pavement, 0.6=degraded, 1.0=potholes
/// - Movement score: 0=stationary, 0.3=slow walk, 0.7=active walk, 1.0=running/vehicle
class SensorInsights {
  SensorInsights._();

  // ── Light / luminosity ────────────────────────────────────────────────────

  /// Returns a 0–4 light pollution level for a given lux reading taken at night.
  /// Only meaningful when collected after civil twilight (sun below -6°).
  static LightPollutionLevel lightPollutionLevel(double lux) {
    if (lux < 0.5)  return LightPollutionLevel.pristine;   // true dark sky
    if (lux < 5)    return LightPollutionLevel.low;         // rural edge
    if (lux < 25)   return LightPollutionLevel.moderate;    // suburban
    if (lux < 100)  return LightPollutionLevel.high;        // urban
    return           LightPollutionLevel.severe;             // city core / stadium
  }

  /// Returns a 0–3 sunlight exposure level for daytime lux readings.
  static SunlightLevel sunlightLevel(double lux) {
    if (lux < 300)    return SunlightLevel.shaded;    // deep shadow / indoor
    if (lux < 2000)   return SunlightLevel.partial;   // overcast / covered
    if (lux < 15000)  return SunlightLevel.bright;    // normal outdoor
    return             SunlightLevel.intense;          // direct sun / heat risk
  }

  // ── Surface quality ───────────────────────────────────────────────────────

  /// Vibration score 0–1 → surface quality label.
  static SurfaceQuality surfaceQuality(double vibrationScore) {
    if (vibrationScore < 0.15) return SurfaceQuality.smooth;
    if (vibrationScore < 0.35) return SurfaceQuality.normal;
    if (vibrationScore < 0.60) return SurfaceQuality.rough;
    return                      SurfaceQuality.poor;
  }

  // ── Urban heat proxy ──────────────────────────────────────────────────────

  /// Combines lux (daytime radiance) + pressure deviation to estimate
  /// relative urban heat exposure. Returns a 0–3 heat index.
  /// Baseline pressure 1013 hPa — lower = higher altitude or storm, higher = heat dome.
  static HeatLevel heatLevel(double lux, double hPa) {
    final pressureDeviation = (hPa - 1013.0).clamp(-30.0, 30.0);
    // High lux + high pressure → heat dome conditions
    final score = (lux / 20000.0).clamp(0.0, 1.0) +
                  (pressureDeviation / 60.0).clamp(-0.5, 0.5);
    if (score < 0.2)  return HeatLevel.cool;
    if (score < 0.5)  return HeatLevel.neutral;
    if (score < 0.75) return HeatLevel.warm;
    return             HeatLevel.hot;
  }

  // ── Insight sentence builders ─────────────────────────────────────────────

  /// One-sentence environmental summary for a tile — shown in tile info sheet
  /// and session summary. Only surfaces readings that are anomalous or exceptional.
  /// Normal conditions return [insightNormal] rather than calling out every reading.
  static String tileInsight(
    AppLocalizations l10n, {
    required bool isNight,
    double? avgLux,
    double? avgHpa,
    double? avgVibration,
  }) {
    final hasData = avgLux != null || avgHpa != null || avgVibration != null;
    if (!hasData) return l10n.insightNoData;

    // Night: light pollution is the primary signal.
    // Pristine/low = exceptionally good → show it.
    // Moderate+ = anomalous → show it.
    // Nothing is "unremarkable" at night for light.
    if (isNight && avgLux != null) {
      return _lightPollutionSentence(l10n, avgLux);
    }

    // Day: flag heat only when warm or hot (neutral/cool = normal, skip).
    if (!isNight && avgLux != null && avgHpa != null) {
      final heat = heatLevel(avgLux, avgHpa);
      if (heat == HeatLevel.hot || heat == HeatLevel.warm) {
        return l10n.insightHeatExposed;
      }
    }

    // Surface: flag only rough or poor (smooth/normal = expected, skip).
    if (avgVibration != null) {
      final quality = surfaceQuality(avgVibration);
      if (quality == SurfaceQuality.rough || quality == SurfaceQuality.poor) {
        return _surfaceSentence(l10n, avgVibration);
      }
    }

    // Day sunlight: flag only intense (shaded/partial/bright = normal, skip).
    if (!isNight && avgLux != null) {
      if (sunlightLevel(avgLux) == SunlightLevel.intense) {
        return _sunlightSentence(l10n, avgLux);
      }
    }

    // Everything within normal range.
    return l10n.insightNormal;
  }

  /// Mapper role based on lifetime coverage cells — used on profile + session summary.
  static MapperRole mapperRole(int coverageCells) {
    if (coverageCells >= 1000) return MapperRole.urbanScientist;
    if (coverageCells >= 500)  return MapperRole.cityMapper;
    if (coverageCells >= 100)  return MapperRole.cartographer;
    if (coverageCells >= 25)   return MapperRole.explorer;
    if (coverageCells >= 5)    return MapperRole.pioneer;
    return MapperRole.contributor;
  }

  static String mapperRoleLabel(AppLocalizations l10n, MapperRole role) {
    switch (role) {
      case MapperRole.urbanScientist: return l10n.mapperRoleUrbanScientist;
      case MapperRole.cityMapper:     return l10n.mapperRoleCityMapper;
      case MapperRole.cartographer:   return l10n.mapperRoleCartographer;
      case MapperRole.explorer:       return l10n.mapperRoleExplorer;
      case MapperRole.pioneer:        return l10n.mapperRolePioneer;
      case MapperRole.contributor:    return l10n.mapperRoleContributor;
    }
  }

  /// Returns the dominant character of a session — used for the dynamic route label.
  static SessionCharacter sessionCharacter({
    required bool isNight,
    double? avgLux,
    double? avgHpa,
    double? avgVibration,
  }) {
    if (isNight && avgLux != null) {
      final level = lightPollutionLevel(avgLux);
      if (level == LightPollutionLevel.pristine || level == LightPollutionLevel.low) {
        return SessionCharacter.darkSky;
      }
      if (level == LightPollutionLevel.high || level == LightPollutionLevel.severe) {
        return SessionCharacter.brightCity;
      }
    }
    if (!isNight && avgLux != null && avgHpa != null) {
      final heat = heatLevel(avgLux, avgHpa);
      if (heat == HeatLevel.hot || heat == HeatLevel.warm) return SessionCharacter.hotRoute;
    }
    if (avgVibration != null) {
      final sq = surfaceQuality(avgVibration);
      if (sq == SurfaceQuality.rough || sq == SurfaceQuality.poor) return SessionCharacter.roughRoad;
    }
    if (!isNight && avgLux != null && sunlightLevel(avgLux) == SunlightLevel.intense) {
      return SessionCharacter.sunExposed;
    }
    return SessionCharacter.quiet;
  }

  /// All-caps label for the session character — shown as the insight card header.
  static String sessionCharacterLabel(AppLocalizations l10n, SessionCharacter c) {
    switch (c) {
      case SessionCharacter.darkSky:    return l10n.sessionCharacterDarkSky;
      case SessionCharacter.brightCity: return l10n.sessionCharacterBrightCity;
      case SessionCharacter.hotRoute:   return l10n.sessionCharacterHotRoute;
      case SessionCharacter.roughRoad:  return l10n.sessionCharacterRoughRoad;
      case SessionCharacter.sunExposed: return l10n.sessionCharacterSunExposed;
      case SessionCharacter.quiet:      return l10n.insightRouteHeader;
    }
  }

  /// Compact bullet-separated condition line for the tile popup.
  /// Returns "dark · quiet · rough road" — each component lowercase.
  static String tileConditionLine(
    AppLocalizations l10n, {
    required bool isNight,
    double? avgLux,
    double? avgMovement,
    double? avgVibration,
  }) {
    final parts = <String>[];
    if (avgLux != null) {
      if (isNight) {
        switch (lightPollutionLevel(avgLux)) {
          case LightPollutionLevel.pristine:
          case LightPollutionLevel.low:
            parts.add(l10n.tileCondLightDark);
          case LightPollutionLevel.moderate:
            parts.add(l10n.tileCondLightDim);
          case LightPollutionLevel.high:
          case LightPollutionLevel.severe:
            parts.add(l10n.tileCondLightBright);
        }
      } else {
        switch (sunlightLevel(avgLux)) {
          case SunlightLevel.shaded:  parts.add(l10n.tileCondLightShaded);
          case SunlightLevel.partial: parts.add(l10n.tileCondLightPartial);
          case SunlightLevel.bright:  parts.add(l10n.tileCondLightBright);
          case SunlightLevel.intense: parts.add(l10n.tileCondLightIntense);
        }
      }
    }
    if (avgMovement != null) {
      if (avgMovement < 0.25) {
        parts.add(l10n.tileCondActivityCalm);
      } else if (avgMovement < 0.55) {
        parts.add(l10n.tileCondActivityModerate);
      } else if (avgMovement < 0.80) {
        parts.add(l10n.tileCondActivityActive);
      } else {
        parts.add(l10n.tileCondActivityBusy);
      }
    }
    if (avgVibration != null) {
      switch (surfaceQuality(avgVibration)) {
        case SurfaceQuality.smooth: parts.add(l10n.tileSurfaceSmooth);
        case SurfaceQuality.rough:  parts.add(l10n.tileSurfaceRough);
        case SurfaceQuality.poor:   parts.add(l10n.tileSurfaceHeavy);
        case SurfaceQuality.normal: break;
      }
    }
    if (parts.isEmpty) return l10n.insightNormal;
    return parts.join(' · ');
  }

  /// Session-level summary — what was the dominant environmental character
  /// of this session. Compares against a population baseline (0–100 percentile).
  static String sessionInsight(
    AppLocalizations l10n, {
    required bool isNight,
    double? avgLux,
    double? avgHpa,
    double? avgVibration,
    double? lightPercentile,
    double? vibrationPercentile,
  }) {
    final hasData = avgLux != null || avgHpa != null || avgVibration != null;
    if (!hasData) return l10n.insightNoData;

    // Night: all light levels are informative (good or bad)
    if (isNight && avgLux != null) {
      final level = lightPollutionLevel(avgLux);
      if (level == LightPollutionLevel.pristine || level == LightPollutionLevel.low) {
        return l10n.insightSessionDarkSky;
      }
      if (level == LightPollutionLevel.severe || level == LightPollutionLevel.high) {
        return l10n.insightSessionBrightCity;
      }
      return _lightPollutionSentence(l10n, avgLux);
    }
    // Day: flag only notable heat
    if (avgLux != null && avgHpa != null) {
      final heat = heatLevel(avgLux, avgHpa);
      if (heat == HeatLevel.hot || heat == HeatLevel.warm) return l10n.insightSessionHotRoute;
    }
    // Surface: flag only rough/poor
    if (avgVibration != null) {
      final quality = surfaceQuality(avgVibration);
      if (quality == SurfaceQuality.rough || quality == SurfaceQuality.poor) {
        return l10n.insightSessionRoughRoute;
      }
    }
    return l10n.insightNormal;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static String _lightPollutionSentence(AppLocalizations l10n, double lux) {
    switch (lightPollutionLevel(lux)) {
      case LightPollutionLevel.pristine:  return l10n.insightLightPristine;
      case LightPollutionLevel.low:       return l10n.insightLightLow;
      case LightPollutionLevel.moderate:  return l10n.insightLightModerate;
      case LightPollutionLevel.high:      return l10n.insightLightHigh;
      case LightPollutionLevel.severe:    return l10n.insightLightSevere;
    }
  }

  static String _sunlightSentence(AppLocalizations l10n, double lux) {
    switch (sunlightLevel(lux)) {
      case SunlightLevel.shaded:   return l10n.insightSunShaded;
      case SunlightLevel.partial:  return l10n.insightSunPartial;
      case SunlightLevel.bright:   return l10n.insightSunBright;
      case SunlightLevel.intense:  return l10n.insightSunIntense;
    }
  }

  static String _surfaceSentence(AppLocalizations l10n, double vibration) {
    switch (surfaceQuality(vibration)) {
      case SurfaceQuality.smooth: return l10n.insightSurfaceSmooth;
      case SurfaceQuality.normal: return l10n.insightSurfaceNormal;
      case SurfaceQuality.rough:  return l10n.insightSurfaceRough;
      case SurfaceQuality.poor:   return l10n.insightSurfacePoor;
    }
  }
}

// ── Enums ─────────────────────────────────────────────────────────────────────

enum LightPollutionLevel { pristine, low, moderate, high, severe }
enum SunlightLevel       { shaded, partial, bright, intense }
enum SurfaceQuality      { smooth, normal, rough, poor }
enum HeatLevel           { cool, neutral, warm, hot }
enum SessionCharacter    { darkSky, brightCity, hotRoute, roughRoad, sunExposed, quiet }
enum MapperRole          { contributor, pioneer, explorer, cartographer, cityMapper, urbanScientist }

// ── Color mapping (for map tiles and badges) ──────────────────────────────────

extension LightPollutionLevelX on LightPollutionLevel {
  Color get color {
    switch (this) {
      case LightPollutionLevel.pristine:  return const Color(0xFF1E3A5F); // deep navy
      case LightPollutionLevel.low:       return const Color(0xFF2E6B9E); // blue
      case LightPollutionLevel.moderate:  return const Color(0xFFF59E0B); // amber
      case LightPollutionLevel.high:      return const Color(0xFFF97316); // orange
      case LightPollutionLevel.severe:    return const Color(0xFFEF4444); // red
    }
  }

  /// Percentage of natural darkness lost (0–100).
  int get darknessPct {
    switch (this) {
      case LightPollutionLevel.pristine: return 0;
      case LightPollutionLevel.low:      return 20;
      case LightPollutionLevel.moderate: return 55;
      case LightPollutionLevel.high:     return 80;
      case LightPollutionLevel.severe:   return 97;
    }
  }
}

extension SunlightLevelX on SunlightLevel {
  Color get color {
    switch (this) {
      case SunlightLevel.shaded:   return const Color(0xFF6EE7B7); // muted green
      case SunlightLevel.partial:  return const Color(0xFF10B981); // green
      case SunlightLevel.bright:   return const Color(0xFFF59E0B); // amber
      case SunlightLevel.intense:  return const Color(0xFFEF4444); // red
    }
  }
}

extension SurfaceQualityX on SurfaceQuality {
  Color get color {
    switch (this) {
      case SurfaceQuality.smooth: return const Color(0xFF10B981); // green
      case SurfaceQuality.normal: return const Color(0xFF6EE7B7); // light green
      case SurfaceQuality.rough:  return const Color(0xFFF59E0B); // amber
      case SurfaceQuality.poor:   return const Color(0xFFEF4444); // red
    }
  }
}

extension HeatLevelX on HeatLevel {
  Color get color {
    switch (this) {
      case HeatLevel.cool:    return const Color(0xFF3B82F6); // blue
      case HeatLevel.neutral: return const Color(0xFF10B981); // green
      case HeatLevel.warm:    return const Color(0xFFF59E0B); // amber
      case HeatLevel.hot:     return const Color(0xFFEF4444); // red
    }
  }
}
