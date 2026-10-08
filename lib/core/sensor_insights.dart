import '../l10n/app_localizations.dart';

/// Labels derived from the user's own contribution count. Environmental
/// "insights" (heat, surface, sky, crowd, weather) were removed: the phone's
/// sensors do not measure them (see tmp/papers/reports/Capteurs telephone
/// mesure environnement.md).
class SensorInsights {
  SensorInsights._();

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

  /// Mapper role based on lifetime coverage cells.
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
}

enum MapperRole { contributor, pioneer, explorer, cartographer, cityMapper, urbanScientist }
