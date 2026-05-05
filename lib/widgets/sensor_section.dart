import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
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
    required bool isLive,
    required bool isPaused,
    required bool hasData,
    required AppLocalizations l10n,
  }) {
    if (!isLive && hasData) return l10n.sensorStatusLastReading;
    if (!isLive) return l10n.sensorStatusNoData;
    if (isPaused && hasData) return l10n.chipPaused; // "Paused" — consistent with chip
    if (isPaused) return l10n.chipPaused;
    if (hasData) return l10n.sensorStatusLive;
    return l10n.sensorStatusConnecting;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Card(
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) widget.onExpansionChanged?.call();
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
          ListenableBuilder(
            listenable: Listenable.merge([
              widget.locationService.isRunning,
              widget.locationService.isPaused,
            ]),
            builder: (context, _) => _buildSensorList(context, isDark, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorList(BuildContext context, bool isDark, AppLocalizations l10n) {
    final theme = Theme.of(context);
    // Sensors keep streaming even when paused — only stop when service is fully stopped.
    final isLive = widget.locationService.isRunning.value;
    final isPaused = widget.locationService.isPaused.value;

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
                enabled: isLive,
                statusLabel: _sensorStatus(
                  isLive: isLive,
                  isPaused: isPaused,
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
                enabled: isLive,
                statusLabel: _sensorStatus(
                  isLive: isLive,
                  isPaused: isPaused,
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
                enabled: isLive,
                statusLabel: _sensorStatus(
                  isLive: isLive,
                  isPaused: isPaused,
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
                enabled: isLive,
                statusLabel: _sensorStatus(
                  isLive: isLive,
                  isPaused: isPaused,
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
                enabled: isLive,
                statusLabel: _sensorStatus(
                  isLive: isLive,
                  isPaused: isPaused,
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
