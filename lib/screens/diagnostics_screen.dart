import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../services/location/foreground_location_service.dart';
import '../widgets/sensor_section.dart';
import '../widgets/sync_health_section.dart';

/// Sensor Diagnostics - "Stats for Nerds" style screen.
///
/// Accessible from Settings > Data > Sensor Diagnostics.
/// Shows live sensor readings without cluttering the home screen.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locationService = ForegroundLocationService.instance;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsDiagnostics)),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: [
          // Developer tooling, never product: the `if (kDebugMode)` is a compile-time constant,
          // so release builds contain neither the panel nor its spacing.
          if (kDebugMode) ...const [
            SyncHealthSection(),
            SizedBox(height: AppTheme.spaceLg),
          ],
          SensorSection(locationService: locationService),
          const SizedBox(height: AppTheme.spaceLg),
        ],
      ),
    );
  }
}
