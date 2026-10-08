import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../extensions/context_extensions.dart';

/// Area rounded so the shown figure stays within 5% of the true value
/// (Hullman et al. 2018): whole hectares below 1 km², one decimal below
/// 10 km², whole km² above. Hectares also avoid a leading "0," that reads
/// as nothing (left-digit effect, Thomas & Morwitz 2005).
({String value, String unit}) formatArea(BuildContext context, double km2) {
  final locale = Localizations.localeOf(context).toString();
  final l10n = context.l10n;
  if (km2 < 1.0) {
    return (value: NumberFormat.decimalPattern(locale).format((km2 * 100).round()), unit: l10n.statsHaUnit);
  }
  final pattern = km2 < 10.0 ? '#,##0.0' : '#,##0';
  return (value: NumberFormat(pattern, locale).format(km2), unit: l10n.statsKm2Unit);
}

/// [formatArea] as one string ("11 ha"), non-breaking space before the unit.
String formatAreaText(BuildContext context, double km2) {
  final a = formatArea(context, km2);
  return '${a.value} ${a.unit}';
}

/// [formatAreaText] for a count of H3 res-9 cells.
String formatCellArea(BuildContext context, int cells) =>
    formatAreaText(context, cells * kKm2PerCell);
