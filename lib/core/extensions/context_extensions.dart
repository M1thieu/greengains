import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;
  bool get isDarkMode => theme.brightness == Brightness.dark;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;

  /// Shorthand for AppLocalizations.of(context)! — industry-standard pattern.
  /// Usage: `context.l10n.keyName` instead of `AppLocalizations.of(context)!.keyName`
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
