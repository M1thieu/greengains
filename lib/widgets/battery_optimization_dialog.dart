import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_preferences.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../utils/app_snackbars.dart';

class BatteryOptimizationDialog extends StatelessWidget {
  const BatteryOptimizationDialog({super.key});

  static const platform = MethodChannel('greengains/foreground');

  Future<void> _markPromptShown() async {
    await AppPreferences.instance.setBatteryOptimizationPromptLastShown(DateTime.now());
  }

  Future<void> _dismissPrompt(BuildContext context, {bool permanently = false}) async {
    await _markPromptShown();
    if (permanently) {
      await AppPreferences.instance.setBatteryOptimizationPromptDismissed(true);
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    // Capture l10n string before async gap (context unsafe after await)
    final errorMsg = context.l10n.batteryDialogError;
    try {
      await _markPromptShown();
      await platform.invokeMethod('requestIgnoreBatteryOptimizations');
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } on PlatformException {
      if (context.mounted) {
        AppSnackbars.showError(context, errorMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.batteryDialogTitle),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(l10n.batteryDialogBody),
            const SizedBox(height: AppTheme.spaceXs + 2),
            Text(
              l10n.batteryDialogBodyBold,
              style: const TextStyle(fontWeight: AppFontWeights.bold),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => _dismissPrompt(context, permanently: true),
          child: Text(l10n.batteryDialogDismissForever),
        ),
        TextButton(
          onPressed: () => _dismissPrompt(context),
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
