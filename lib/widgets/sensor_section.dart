import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/themes.dart';
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
  final List<StreamSubscription> _subs = [];

  bool get _allReady => _hasLight && _hasAccel && _hasGyro && _hasPressure;

  @override
  void initState() {
    super.initState();
    _hasLight = widget.locationService.lastLight != null;
    _hasAccel = widget.locationService.lastAccelerometer != null;
    _hasGyro = widget.locationService.lastGyroscope != null;
    _hasPressure = widget.locationService.lastPressure != null;

    _subs.add(widget.locationService.lightStream.listen((data) {
      if (data != null && !_hasLight && mounted) {
        setState(() => _hasLight = true);
      }
    }));
    _subs.add(widget.locationService.accelerometerStream.listen((data) {
      if (data != null && !_hasAccel && mounted) {
        setState(() => _hasAccel = true);
      }
    }));
    _subs.add(widget.locationService.gyroscopeStream.listen((data) {
      if (data != null && !_hasGyro && mounted) {
        setState(() => _hasGyro = true);
      }
    }));
    _subs.add(widget.locationService.pressureStream.listen((data) {
      if (data != null && !_hasPressure && mounted) {
        setState(() => _hasPressure = true);
      }
    }));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  String _getLightDescription(double lux) {
    if (lux < 10) return 'Dark';
    if (lux < 50) return 'Dim';
    if (lux < 500) return 'Normal';
    if (lux < 10000) return 'Bright';
    return 'Very Bright';
  }

  String _sensorStatus({
    required bool isRunning,
    required bool hasData,
  }) {
    if (!isRunning) return 'Paused';
    if (!hasData) return 'Connecting…';
    return 'Live';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              'Live readings',
              style: AppTheme.cardTitle(theme),
            ),
            subtitle: Text(
              'See what data you\'re contributing right now',
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              if (!isRunning)
                _buildInactiveState(
                  context,
                  isDark,
                  title: 'Sensors inactive',
                  subtitle: 'Start tracking above to begin collecting data',
                )
              else if (isPaused)
                _buildInactiveState(
                  context,
                  isDark,
                  title: 'Sensors paused',
                  subtitle: 'Resume tracking to continue collecting data',
                )
              else if (!_allReady)
                _buildReadyGate(context, isDark)
              else
                _buildSensorList(context, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReadyGate(BuildContext context, bool isDark) {
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
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                'Collecting first readings…',
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: AppTheme.surfaceContainer(
              isDark: isDark,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.sensors_off,
                  size: 48,
                  color: AppColors.textSecondary(isDark),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  title,
                  style: AppTheme.cardTitle(theme),
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorList(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

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
            'Around You',
            style: AppTheme.sectionHeader(theme, isDark),
          ),
          const SizedBox(height: AppTheme.spaceXs),

          // Light Sensor
          StreamBuilder<LightData>(
            stream: widget.locationService.lightStream,
            initialData: widget.locationService.lastLight,
            builder: (context, snapshot) {
              final light = snapshot.data;
              final isTracking = widget.locationService.isRunning.value &&
                  !widget.locationService.isPaused.value;
              return SensorDataCard(
                icon: Icons.light_mode,
                title: 'Light',
                value: light != null
                    ? '${light.lux.toStringAsFixed(0)} lux'
                    : null,
                unit: light != null ? _getLightDescription(light.lux) : 'lux',
                enabled: isTracking,
                statusLabel: _sensorStatus(
                  isRunning: isTracking,
                  hasData: light != null,
                ),
                updatedAt: light?.dateTime,
              );
            },
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Motion Section
          Text(
            'Movement',
            style: AppTheme.sectionHeader(theme, isDark),
          ),
          const SizedBox(height: AppTheme.spaceXs),

          // Accelerometer
          StreamBuilder<AccelerometerData>(
            stream: widget.locationService.accelerometerStream,
            initialData: widget.locationService.lastAccelerometer,
            builder: (context, snapshot) {
              final accel = snapshot.data;
              final isTracking = widget.locationService.isRunning.value &&
                  !widget.locationService.isPaused.value;
              return SensorDataCard(
                icon: Icons.vibration,
                title: 'Movement',
                value: accel != null
                    ? '${accel.magnitude.toStringAsFixed(1)} m/s²'
                    : null,
                unit: 'Acceleration intensity',
                enabled: isTracking,
                statusLabel: _sensorStatus(
                  isRunning: isTracking,
                  hasData: accel != null,
                ),
                updatedAt: accel?.dateTime,
              );
            },
          ),

          // Gyroscope
          StreamBuilder<GyroscopeData>(
            stream: widget.locationService.gyroscopeStream,
            initialData: widget.locationService.lastGyroscope,
            builder: (context, snapshot) {
              final gyro = snapshot.data;
              final isTracking = widget.locationService.isRunning.value &&
                  !widget.locationService.isPaused.value;
              return SensorDataCard(
                icon: Icons.screen_rotation,
                title: 'Orientation',
                value: gyro != null
                    ? '${gyro.magnitude.toStringAsFixed(2)} °/s'
                    : null,
                unit: 'Rotation speed',
                enabled: isTracking,
                statusLabel: _sensorStatus(
                  isRunning: isTracking,
                  hasData: gyro != null,
                ),
                updatedAt: gyro?.dateTime,
              );
            },
          ),

          // Barometer
          StreamBuilder<PressureData>(
            stream: widget.locationService.pressureStream,
            initialData: widget.locationService.lastPressure,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final isTracking = widget.locationService.isRunning.value &&
                  !widget.locationService.isPaused.value;
              return SensorDataCard(
                icon: Icons.compress,
                title: 'Air Pressure',
                value: data != null
                    ? '${data.hPa.toStringAsFixed(1)} hPa'
                    : null,
                unit: 'Atmospheric pressure',
                enabled: isTracking,
                statusLabel: _sensorStatus(
                  isRunning: isTracking,
                  hasData: data != null,
                ),
                updatedAt: data?.dateTime,
              );
            },
          ),
        ],
      ),
    );
  }
}
