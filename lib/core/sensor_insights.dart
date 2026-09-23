import 'dart:math' show pow;
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

  // ── ISA constants (International Standard Atmosphere) ────────────────────
  // All pressure-derived calculations use these rather than inline magic numbers.
  static const double _kP0 = 1013.25; // sea-level pressure, hPa
  static const double _kT0 = 288.15;  // sea-level temperature, K
  static const double _kL  = 0.0065;  // temperature lapse rate, K/m
  // Derived: R*L/(g*M) = 8.31446*0.0065 / (9.80665*0.028964)
  static const double _kBaroExp = 0.19029;
  // Derived: T0/L
  static const double _kBaroScale = _kT0 / _kL; // ≈ 44330 m

  /// ODE 4: Barometric altitude (m) from measured pressure.
  /// Closed-form solution of the hydrostatic ODE dp/dz = -rho*g
  /// combined with the ideal gas law (rho = p*M / (R*T)):
  ///   z = (T0/L) * [1 - (p/p0)^(R*L/(g*M))]
  /// Valid for the troposphere (0–11 km). Returns metres above sea level.
  static double baroAltitudeM(double hPa) =>
      _kBaroScale * (1.0 - pow(hPa / _kP0, _kBaroExp));

  // ── Light / luminosity ────────────────────────────────────────────────────
  // Night thresholds approximate Bortle sky-brightness classes; day thresholds
  // are standard illuminance references (overcast ≈ 1–2k lux, full daylight
  // ≈ 10–25k lux). Empirical perceptual scales, not derivable from an ODE —
  // a luminance classification has no governing differential equation.
  static const double _kLuxPristine  = 0.5;    // true dark sky
  static const double _kLuxRural     = 5.0;    // rural edge
  static const double _kLuxSuburban  = 25.0;   // suburban
  static const double _kLuxUrban     = 100.0;  // city core / stadium above this
  static const double _kLuxShaded    = 300.0;  // deep shadow / indoor
  static const double _kLuxOvercast  = 2000.0; // overcast / covered
  static const double _kLuxDaylight  = 15000.0; // direct sun above this

  /// Returns a 0–4 light pollution level for a given lux reading taken at night.
  /// Only meaningful when collected after civil twilight (sun below -6°).
  static LightPollutionLevel lightPollutionLevel(double lux) {
    if (lux < _kLuxPristine) return LightPollutionLevel.pristine;
    if (lux < _kLuxRural)    return LightPollutionLevel.low;
    if (lux < _kLuxSuburban) return LightPollutionLevel.moderate;
    if (lux < _kLuxUrban)    return LightPollutionLevel.high;
    return                          LightPollutionLevel.severe;
  }

  /// Returns a 0–3 sunlight exposure level for daytime lux readings.
  static SunlightLevel sunlightLevel(double lux) {
    if (lux < _kLuxShaded)   return SunlightLevel.shaded;
    if (lux < _kLuxOvercast) return SunlightLevel.partial;
    if (lux < _kLuxDaylight) return SunlightLevel.bright;
    return                          SunlightLevel.intense;
  }

  // ── Surface quality ───────────────────────────────────────────────────────
  // UNVALIDATED: these cut a normalised 0–1 vibration score into four labels,
  // but the cut points were chosen by hand, not fitted to observed data. They
  // cannot come from an ODE (a classification boundary is not a dynamical
  // quantity) — the principled replacement is percentiles of the real
  // distribution of vibration_score in sensor_aggregates_5m.
  static const double _kSurfaceSmooth = 0.15;
  static const double _kSurfaceNormal = 0.35;
  static const double _kSurfaceRough  = 0.60;

  // Same caveat as the surface cut points: hand-picked boundaries on a
  // normalised 0–1 movement score, not fitted to observed data.
  static const double _kMovementCalm     = 0.25;
  static const double _kMovementModerate = 0.55;
  static const double _kMovementActive   = 0.80;

  /// Vibration score 0–1 → surface quality label.
  static SurfaceQuality surfaceQuality(double vibrationScore) {
    if (vibrationScore < _kSurfaceSmooth) return SurfaceQuality.smooth;
    if (vibrationScore < _kSurfaceNormal) return SurfaceQuality.normal;
    if (vibrationScore < _kSurfaceRough)  return SurfaceQuality.rough;
    return SurfaceQuality.poor;
  }

  // ── Urban heat proxy ──────────────────────────────────────────────────────
  // WEAKEST MODEL IN THIS FILE. Pressure does not drive temperature; this
  // linear lux+pressure blend is a stand-in for a measurement we did not have
  // when it was written. It is not a surface energy balance and should not be
  // mistaken for one. Now that the backend fetches real weather
  // (utils/weatherService.ts), the principled fix is to read actual air
  // temperature rather than infer heat from a barometer.
  static const double _kHeatLuxScale      = 20000.0; // lux → 0–1 radiance term
  static const double _kHeatPressureClamp = 30.0;    // hPa, typical weather swing
  static const double _kHeatPressureScale = 60.0;    // hPa → ±0.5 term
  static const double _kHeatCool          = 0.2;
  static const double _kHeatNeutral       = 0.5;
  static const double _kHeatWarm          = 0.75;

  /// Combines lux (daytime radiance) + pressure deviation to estimate
  /// relative urban heat exposure. Returns a 0–3 heat index.
  static HeatLevel heatLevel(double lux, double hPa) {
    final pressureDeviation =
        (hPa - _kP0).clamp(-_kHeatPressureClamp, _kHeatPressureClamp);
    final score = (lux / _kHeatLuxScale).clamp(0.0, 1.0) +
                  (pressureDeviation / _kHeatPressureScale).clamp(-0.5, 0.5);
    if (score < _kHeatCool)    return HeatLevel.cool;
    if (score < _kHeatNeutral) return HeatLevel.neutral;
    if (score < _kHeatWarm)    return HeatLevel.warm;
    return                            HeatLevel.hot;
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

  // Role tiers in lifetime coverage cells. Deliberately arbitrary: these are a
  // product decision about when a label changes, not a measurement, so there is
  // nothing to derive them from. Roughly log-spaced so each tier takes
  // meaningfully longer than the last.
  static const List<(int, MapperRole)> _kRoleTiers = [
    (1000, MapperRole.urbanScientist),
    (500,  MapperRole.cityMapper),
    (100,  MapperRole.cartographer),
    (25,   MapperRole.explorer),
    (5,    MapperRole.pioneer),
  ];

  /// Mapper role based on lifetime coverage cells — used on profile + session summary.
  static MapperRole mapperRole(int coverageCells) {
    for (final (threshold, role) in _kRoleTiers) {
      if (coverageCells >= threshold) return role;
    }
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
      if (avgMovement < _kMovementCalm) {
        parts.add(l10n.tileCondActivityCalm);
      } else if (avgMovement < _kMovementModerate) {
        parts.add(l10n.tileCondActivityModerate);
      } else if (avgMovement < _kMovementActive) {
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
