import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../core/theme_controller.dart';
import '../core/language_controller.dart';
import '../core/app_preferences.dart';
import '../services/auth/auth_service.dart';
import '../services/network/backend_client.dart';
import '../utils/app_snackbars.dart';
import 'diagnostics_screen.dart';
import 'webview_screen.dart';
import '../l10n/app_localizations.dart';
import '../widgets/press_scale_detector.dart';

const _kPrivacyPolicyUrl    = 'https://greengains.eremat.org/legal/privacy-policy';
const _kTermsUrl            = 'https://greengains.eremat.org/legal/terms-of-service';
const _kDataTransparencyUrl = 'https://greengains.eremat.org/legal/data-transparency';
const _kDataDeletionUrl     = 'https://greengains.eremat.org/legal/data-deletion';
const _kSectionSpacing   = AppTheme.spaceSm;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _fgChannel = MethodChannel('greengains/foreground');
  final _prefs = AppPreferences.instance;
  final _themeController = ThemeController.instance;
  final _languageController = LanguageController.instance;
  String _version = '';
  bool _exportBusy = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: l10n.settingsSignOut,
            onPressed: _signOut,
          ),
        ],
      ),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: [
          _Group(
            children: [
              ListenableBuilder(
                listenable: _themeController,
                builder: (context, _) {
                  final l = context.l10n;
                  return SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      textStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: AppFontWeights.semibold),
                    ),
                    segments: [
                      ButtonSegment(value: ThemeMode.light, label: Text(l.settingsThemeLight)),
                      ButtonSegment(value: ThemeMode.dark, label: Text(l.settingsThemeDark)),
                      ButtonSegment(value: ThemeMode.system, label: Text(l.settingsThemeAuto)),
                    ],
                    selected: {_themeController.mode},
                    onSelectionChanged: (s) => _themeController.setMode(s.first),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spaceSm),
              ListenableBuilder(
                listenable: _languageController,
                builder: (context, _) {
                  final l = context.l10n;
                  return SegmentedButton<String?>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      textStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: AppFontWeights.semibold),
                    ),
                    segments: [
                      ButtonSegment(value: null, label: Text(l.settingsLanguageSystem)),
                      ButtonSegment(value: 'en', label: Text(l.settingsLanguageEnglish)),
                      ButtonSegment(value: 'fr', label: Text(l.settingsLanguageFrench)),
                    ],
                    selected: {_languageController.locale?.languageCode},
                    onSelectionChanged: (s) {
                      final code = s.first;
                      _languageController.setLocale(code != null ? Locale(code) : null);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: _kSectionSpacing),

          _Group(
            children: [
              // Android's guidance: notification preferences live in the system
              // settings (one entry per channel); the app only links there.
              _LinkRow(
                title: l10n.settingsNotifications,
                onTap: () => _fgChannel.invokeMethod('openNotificationSettings'),
              ),
              _divider(isDark),
              _ToggleRow(
                title: l10n.settingsMobileData,
                subtitle: l10n.settingsMobileDataDescription,
                value: _prefs.useMobileUploads,
                onChanged: (v) async {
                  await _prefs.setUseMobileUploads(v);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),

          // Sensor diagnostics are a developer tool, not a user setting.
          if (kDebugMode) ...[
            const SizedBox(height: _kSectionSpacing),
            _Group(
              children: [
                _LinkRow(
                  title: l10n.settingsDiagnostics,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppTheme.spaceXl),

          // ── Footer: legal (app info such as the version lives in that sheet,
          // not among the settings, per Material's settings pattern) ─────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceXl),
              child: _LegalLink(
                label: l10n.settingsLegal,
                isDark: isDark,
                onTap: () => _showLegalSheet(context, l10n, isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
        height: AppTheme.spaceLg,
        thickness: 0.5,
        color: AppColors.divider(isDark),
      );

  void _openWebView(BuildContext context, String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebViewScreen(url: url, title: title)),
    );
  }

  void _showLegalSheet(BuildContext context, AppLocalizations l10n, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) {
        final bottomPad = MediaQuery.paddingOf(context).bottom + AppTheme.spaceLg;
        return Padding(
          padding: EdgeInsets.fromLTRB(AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceLg, bottomPad),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppTheme.dragHandle(isDark),
            const SizedBox(height: AppTheme.spaceMd),
            _legalItem(context, l10n.privacyPolicy, _kPrivacyPolicyUrl, isDark),
            Divider(height: AppTheme.spaceLg, thickness: 0.5, color: AppColors.divider(isDark)),
            _legalItem(context, l10n.termsOfService, _kTermsUrl, isDark),
            Divider(height: AppTheme.spaceLg, thickness: 0.5, color: AppColors.divider(isDark)),
            _legalItem(context, l10n.settingsDataTransparency, _kDataTransparencyUrl, isDark),
            Divider(height: AppTheme.spaceLg, thickness: 0.5, color: AppColors.divider(isDark)),
            _legalItem(context, l10n.settingsDataDeletion, _kDataDeletionUrl, isDark),
            Divider(height: AppTheme.spaceLg, thickness: 0.5, color: AppColors.divider(isDark)),
            _exportDataItem(context, l10n, isDark),
            if (_version.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceLg),
              Text(
                l10n.settingsVersion(_version),
                style: TextStyle(fontSize: AppTheme.fontSizeNavLabel, color: AppColors.textTertiary(isDark)),
              ),
            ],
          ]),
        );
      },
    );
  }

  Widget _exportDataItem(BuildContext sheetContext, AppLocalizations l10n, bool isDark) {
    final theme = Theme.of(sheetContext);
    return PressScaleDetector(
      onTap: () {
        Navigator.of(sheetContext).pop();
        // Use the screen's own context — the sheet's is unmounted right after pop.
        if (!mounted) return;
        AppSnackbars.show(context, message: l10n.settingsExportDataPreparing, type: AppSnackbarType.info);
        unawaited(_exportMyData(context, l10n));
      },
      child: Row(children: [
        Expanded(child: Text(l10n.settingsExportData, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary(isDark),
        ))),
        Icon(Icons.ios_share_rounded, size: AppIconSizes.sm, color: AppColors.textTertiary(isDark)),
      ]),
    );
  }

  Widget _legalItem(BuildContext context, String title, String url, bool isDark) {
    final theme = Theme.of(context);
    return PressScaleDetector(
      onTap: () {
        Navigator.of(context).pop();
        _openWebView(context, url, title);
      },
      child: Row(children: [
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary(isDark),
        ))),
        Icon(Icons.chevron_right, size: AppIconSizes.sm, color: AppColors.textTertiary(isDark)),
      ]),
    );
  }

  /// Signs out immediately. Settings is a pushed route that would otherwise
  /// stay on top after OnboardingWrapper swaps the shell for onboarding, so
  /// pop back to the root first.
  Future<void> _signOut() async {
    HapticFeedback.lightImpact();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await AuthService.signOut();
  }

  /// Personal data export — a right, not a paid feature, so it hits
  /// GET /api/user/export directly rather than the org-tier-gated dashboard
  /// endpoint. Fetches JSON, writes it to a temp file, then hands off to the
  /// OS share sheet so the user picks where it goes (email, Drive, Files…).
  Future<void> _exportMyData(BuildContext context, AppLocalizations l10n) async {
    if (_exportBusy) return;
    setState(() => _exportBusy = true);
    try {
      final data = await BackendClient.get('/api/user/export?format=json');
      final pretty = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/greengains-my-data-${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(pretty);

      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (context.mounted) {
        AppSnackbars.show(context, message: l10n.settingsExportDataFailed, type: AppSnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

}

/// A plain group of settings rows on one card. No section label: each group
/// holds two or three self-explanatory rows.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: AppTheme.contentCard(isDark: isDark),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disabled = onChanged == null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: disabled ? AppColors.textSecondary(isDark) : AppColors.textPrimary(isDark),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppTheme.spaceXxs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spaceXs),
        Switch(
          value: value,
          onChanged: onChanged == null ? null : (v) {
            HapticFeedback.lightImpact();
            onChanged!(v);
          },
        ),
      ],
    );
  }
}

/// Row that navigates somewhere else: title + chevron, whole row tappable.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return PressScaleDetector(
      onTap: onTap,
      child: SizedBox(
        height: AppTheme.minTouchTarget,
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary(isDark),
              )),
            ),
            Icon(Icons.chevron_right, size: AppIconSizes.sm, color: AppColors.textTertiary(isDark)),
          ],
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap, required this.isDark});
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PressScaleDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTheme.fontSizeXs,
          color: AppColors.textSecondary(isDark),
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textSecondary(isDark).withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
