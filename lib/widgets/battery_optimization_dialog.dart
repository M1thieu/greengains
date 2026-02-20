import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_preferences.dart';
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
    try {
      await _markPromptShown();
      await platform.invokeMethod('requestIgnoreBatteryOptimizations');
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } on PlatformException {
      if (context.mounted) {
        AppSnackbars.showError(context, 'Unable to open battery settings');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Maximize Your Earnings'),
      content: const SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(
              'To earn 24/7, GreenGains needs to run in the background without being killed by the system.',
            ),
            SizedBox(height: 10),
            Text(
              'Please disable "Battery Optimization" for GreenGains in the next screen.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => _dismissPrompt(context, permanently: true),
          child: const Text('Don\'t show again'),
        ),
        TextButton(
          onPressed: () => _dismissPrompt(context),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => _openSettings(context),
          child: const Text('Allow Background Run'),
        ),
      ],
    );
  }
}
