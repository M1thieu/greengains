import 'package:flutter/material.dart';

import '../core/themes.dart';

enum AppSnackbarType { success, error, info }

class AppSnackbars {
  const AppSnackbars._();

  static void show(
    BuildContext context, {
    required String message,
    AppSnackbarType type = AppSnackbarType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color background;
    final Color textColor;
    IconData resolvedIcon;

    switch (type) {
      case AppSnackbarType.success:
        background = AppColors.success;
        textColor = Colors.white;
        resolvedIcon = icon ?? Icons.check_circle;
        break;
      case AppSnackbarType.error:
        background = AppColors.error;
        textColor = Colors.white;
        resolvedIcon = icon ?? Icons.error_outline;
        break;
      case AppSnackbarType.info:
        background = AppColors.surfaceElevated(isDark);
        textColor = AppColors.textPrimary(isDark);
        resolvedIcon = icon ?? Icons.info_outline;
        break;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(resolvedIcon, color: textColor),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      duration: duration,
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static void showSuccess(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
    show(
      context,
      message: message,
      type: AppSnackbarType.success,
      duration: duration,
    );
  }

  static void showError(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    show(
      context,
      message: message,
      type: AppSnackbarType.error,
      duration: duration,
    );
  }

  static void showInfo(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
    show(
      context,
      message: message,
      type: AppSnackbarType.info,
      duration: duration,
    );
  }
}
