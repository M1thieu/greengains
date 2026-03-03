import 'package:flutter/material.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../services/location/foreground_location_service.dart';
import '../widgets/sensor_section.dart';

/// Sensor Diagnostics — "Stats for Nerds" style screen.
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
          SensorSection(locationService: locationService),
          const SizedBox(height: AppTheme.spaceLg),
        ],
      ),
    );
  }
}
