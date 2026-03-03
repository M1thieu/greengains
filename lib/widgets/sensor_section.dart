import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../services/location/foreground_location_service.dart';
import '../models/sensor_models.dart';
import 'sensor_data_card.dart';

/// Collapsible sensor readings section
/// Extracted from home_screen.dart to reduce complexity and improve reusability
/// Shows technical sensor data for users who want to verify tracking
///
/// Usage:
/// ```dart
/// SensorSection(
///   locationService: ForegroundLocationService.instance,
/// )
/// ```
class SensorSection extends StatefulWidget {
  final ForegroundLocationService locationService;
  final VoidCallback? onExpansionChanged;

  const SensorSection({
    super.key,
    required this.locationService,
    this.onExpansionChanged,
  });

  @override
  State<SensorSection> createState() => _SensorSectionState();
}

class _SensorSectionState extends State<SensorSection> {
  late bool _hasLight;
  late bool _hasAccel;
  late bool _hasGyro;
  late bool _hasPressure;
  // Magnetic is optional — not every device has a magnetometer.
  // We never gate _allReady on it; the card shows "Connecting…" if unavailable.
  final List<StreamSubscription> _subs = [];

  bool get _allReady => _hasLight && _hasAccel && _hasGyro && _hasPressure;

  @override
  void initState() {
    super.initState();
    _hasLight = widget.locationService.lastLight != null;
    _hasAccel = widget.locationService.lastAccelerometer != null;
    _hasGyro = widget.locationService.lastGyroscope != null;
    _hasPressure = widget.locationService.lastPressure != null;

    _subs.add(widget.locationService.lightStream.listen((_) {
      if (!_hasLight && mounted) setState(() => _hasLight = true);
    }));
    _subs.add(widget.locationService.accelerometerStream.listen((_) {
      if (!_hasAccel && mounted) setState(() => _hasAccel = true);
    }));
    _subs.add(widget.locationService.gyroscopeStream.listen((_) {
      if (!_hasGyro && mounted) setState(() => _hasGyro = true);
    }));
    _subs.add(widget.locationService.pressureStream.listen((_) {
      if (!_hasPressure && mounted) setState(() => _hasPressure = true);
    }));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  String _getLightDescription(double lux, AppLocalizations l10n) {
    if (lux < 10) return l10n.lightDark;
    if (lux < 50) return l10n.lightDim;
    if (lux < 500) return l10n.lightNormal;
    if (lux < 10000) return l10n.lightBright;
    return l10n.lightVeryBright;
  }

  String _getMagneticDescription(double microtesla, AppLocalizations l10n) {
    if (microtesla < 25) return l10n.magnetVeryLow;
    if (microtesla < 65) return l10n.magnetNormal;
    if (microtesla < 100) return l10n.magnetElevated;
    return l10n.magnetHighNearMetal;
  }

  String _sensorStatus({
    required bool isRunning,
    required bool hasData,
    required AppLocalizations l10n,
  }) {
    if (!isRunning) return l10n.sensorStatusPaused;
    if (!hasData) return l10n.sensorStatusConnecting;
    return l10n.sensorStatusLive;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.locationService.isRunning,
        widget.locationService.isPaused,
      ]),
      builder: (context, _) {
        final isRunning = widget.locationService.isRunning.value;
        final isPaused = widget.locationService.isPaused.value;

        return Card(
          child: ExpansionTile(
            onExpansionChanged: (expanded) {
              if (expanded) {
                HapticFeedback.lightImpact();
                widget.onExpansionChanged?.call();
              }
            },
            title: Text(
              l10n.sensorLiveReadings,
              style: AppTheme.cardTitle(theme),
            ),
            subtitle: Text(
              l10n.sensorLiveSubtitle,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              if (!isRunning)
                _buildInactiveState(
                  context,
                  isDark,
                  title: l10n.sensorInactiveTitle,
                  subtitle: l10n.sensorInactiveSubtitle,
                )
              else if (isPaused)
                _buildInactiveState(
                  context,
                  isDark,
                  title: l10n.sensorPausedTitle,
                  subtitle: l10n.sensorPausedSubtitle,
                )
              else if (!_allReady)
                _buildReadyGate(context, isDark, l10n)
              else
                _buildSensorList(context, isDark, l10n),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReadyGate(BuildContext context, bool isDark, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: AppTheme.surfaceContainer(isDark: isDark),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXs),
              decoration: BoxDecoration(
                color: AppColors.primaryAlpha(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(
                Icons.sensors,
                size: AppIconSizes.sm,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                l10n.sensorCollectingFirst,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary(isDark),
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveState(
    BuildContext context,
    bool isDark, {
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: AppTheme.surfaceContainer(isDark: isDark),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceXs),
              decoration: BoxDecoration(
                color: AppColors.textSecondary(isDark).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(Icons.sensors_off, size: AppIconSizes.sm, color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFontWeights.semibold,
                    color: AppColors.textPrimary(isDark),
                  )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorList(BuildContext context, bool isDark, AppLocalizations l10n) {
    final theme = Theme.of(context);
    // Safe to hoist: _buildSensorList is only called from a ListenableBuilder
    // that already listens to isRunning + isPaused, so this value is fresh.
    final isTracking = widget.locationService.isRunning.value &&
        !widget.locationService.isPaused.value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMd,
        0,
        AppTheme.spaceMd,
        AppTheme.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Environment Section
          Text(
            l10n.sensorAroundYou,
            style: AppTheme.sectionHeader(theme, isDark),
          ),
          const SizedBox(height: AppTheme.spaceXs),

          // Light Sensor
          StreamBuilder<LightData>(
            stream: widget.locationService.lightStream,
            initialData: widget.locationService.lastLight,
            builder: (context, snapshot) {
              final light = snapshot.data;
              return SensorDataCard(
                icon: Icons.light_mode,
                title: l10n.sensorLight,
                value: light != null
                    ? '${light.lux.toStringAsFixed(0)} lux'
                    : null,
                unit: light != null ? _getLightDescription(light.lux, l10n) : 'lux',
                enabled: isTracking,
                statusLabel: _sensorStatus(
                  isRunning: isTracking,
                  hasData: light != null,
                  l10n: l10n,
                ),
                updatedAt: light?.dateTime,
                accentColor: AppColors.light,
              );
            },
          ),

          // Magnetic Field
          StreamBuilder<MagneticFieldData>(
            stream: widget.locationService.magneticFieldStream,
            initialData: widget.locationService.lastMagneticField,
            builder: (context, snapshot) {
              final mag = snapshot.data;
              return SensorDataCard(
                icon: Icons.explore,
                title: l10n.sensorMagneticField,
                value: mag != null
                    ? '${mag.magnitude.toStringAsFixed(1)} µT'
                    : null,
                unit: mag != null
                    ? _getMagneticDescription(mag.magnitude, l10n)
                    : 'microtesla',
                enabled: isTracking,
                statusLabel: _sensorStatus(
                  isRunning: isTracking,
                  hasData: mag != null,
                  l10n: l10n,
                ),
                updatedAt: mag?.dateTime,
                accentColor: AppColors.accentPurple,
              );
            },
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Movement Section
          Text(
            l10n.sensorMovement,
            style: AppTheme.sectionHeader(theme, isDark),
          ),
          const SizedBox(height: AppTheme.spaceXs),

          // Accelerometer
          StreamBuilder<AccelerometerData>(
            stream: widget.locationService.accelerometerStream,
            initialData: widget.locationService.lastAccelerometer,
            builder: (context, snapshot) {
              final accel = snapshot.data;
              return SensorDataCard(
                icon: Icons.vibration,
                title: l10n.sensorAcceleration,
                value: accel != null
                    ? '${accel.magnitude.toStringAsFixed(1)} m/s²'
                    : null,
                unit: l10n.sensorAccelerationIntensity,
                enabled: isTracking,
                statusLabel: _sensorStatus(
                  isRunning: isTracking,
                  hasData: accel != null,
                  l10n: l10n,
                ),
                updatedAt: accel?.dateTime,
                accentColor: AppColors.movement,
              );
            },
          ),

          // Gyroscope
          StreamBuilder<GyroscopeData>(
            stream: widget.locationService.gyroscopeStream,
            initialData: widget.locationService.lastGyroscope,
            builder: (context, snapshot) {
              final gyro = snapshot.data;
              return SensorDataCard(
                icon: Icons.screen_rotation,
                title: l10n.sensorOrientation,
                value: gyro != null
                    ? '${gyro.magnitude.toStringAsFixed(2)} °/s'
                    : null,
                unit: l10n.sensorRotationSpeed,
                enabled: isTracking,
                statusLabel: _sensorStatus(
                  isRunning: isTracking,
                  hasData: gyro != null,
                  l10n: l10n,
                ),
                updatedAt: gyro?.dateTime,
                accentColor: AppColors.movement,
              );
            },
          ),

          // Barometer
          StreamBuilder<PressureData>(
            stream: widget.locationService.pressureStream,
            initialData: widget.locationService.lastPressure,
            builder: (context, snapshot) {
              final data = snapshot.data;
              return SensorDataCard(
                icon: Icons.compress,
                title: l10n.sensorAirPressure,
                value: data != null
                    ? '${data.hPa.toStringAsFixed(1)} hPa'
                    : null,
                unit: l10n.sensorAtmosphericPressure,
                enabled: isTracking,
                statusLabel: _sensorStatus(
                  isRunning: isTracking,
                  hasData: data != null,
                  l10n: l10n,
                ),
                updatedAt: data?.dateTime,
                accentColor: AppColors.pressure,
              );
            },
          ),
        ],
      ),
    );
  }
}
