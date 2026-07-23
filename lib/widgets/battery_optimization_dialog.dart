import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_preferences.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_snackbars.dart';

class BatteryOptimizationDialog extends StatefulWidget {
  const BatteryOptimizationDialog({super.key});

  @override
  State<BatteryOptimizationDialog> createState() => _BatteryOptimizationDialogState();
}

class _BatteryOptimizationDialogState extends State<BatteryOptimizationDialog> {
  static const _platform = MethodChannel('greengains/foreground');

  String? _manufacturer;

  @override
  void initState() {
    super.initState();
    _loadManufacturer();
  }

  Future<void> _loadManufacturer() async {
    try {
      final m = await _platform.invokeMethod<String>('getDeviceManufacturer');
      if (mounted) setState(() => _manufacturer = m?.toLowerCase());
    } catch (_) {}
  }

  Future<void> _markPromptShown() async {
    await AppPreferences.instance.setBatteryOptimizationPromptLastShown(DateTime.now());
  }

  Future<void> _dismiss(BuildContext context, {bool permanently = false}) async {
    await _markPromptShown();
    if (permanently) {
      await AppPreferences.instance.setBatteryOptimizationPromptDismissed(true);
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _openSettings(BuildContext context) async {
    final errorMsg = context.l10n.batteryDialogError;
    try {
      await _markPromptShown();
      await _platform.invokeMethod('requestIgnoreBatteryOptimizations');
      if (context.mounted) Navigator.of(context).pop();
    } on PlatformException {
      if (context.mounted) AppSnackbars.showError(context, errorMsg);
    }
  }

  /// Returns OEM-specific extra guidance, or null for standard Android.
  String? _oemHint(AppLocalizations l10n) {
    final m = _manufacturer;
    if (m == null) return null;
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return l10n.batteryDialogOemXiaomiHint;
    }
    if (m.contains('huawei') || m.contains('honor')) {
      return l10n.batteryDialogOemHuaweiHint;
    }
    if (m.contains('samsung')) {
      return l10n.batteryDialogOemSamsungHint;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final oemHint = _oemHint(l10n);
    return AlertDialog(
      title: Text(l10n.batteryDialogTitle),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            Text(l10n.batteryDialogBody),
            const SizedBox(height: AppTheme.spaceXs + 2),
            Text(
              l10n.batteryDialogBodyBold,
              style: const TextStyle(fontWeight: AppFontWeights.bold),
            ),
            if (oemHint != null) ...[
              const SizedBox(height: AppTheme.spaceXs + 2),
              Text(
                oemHint,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _dismiss(context, permanently: true),
          child: Text(l10n.batteryDialogDismissForever),
        ),
        TextButton(
          onPressed: () => _dismiss(context),
          child: Text(l10n.batteryDialogLater),
        ),
        FilledButton(
          onPressed: () => _openSettings(context),
          child: Text(l10n.batteryDialogAllow),
        ),
      ],
    );
  }
}
