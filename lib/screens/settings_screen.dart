import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../core/theme_controller.dart';
import '../core/language_controller.dart';
import '../core/app_preferences.dart';
import '../services/location/foreground_location_service.dart';
import 'diagnostics_screen.dart';
import 'webview_screen.dart';
import '../widgets/press_scale_detector.dart';

const _kPrivacyPolicyUrl    = 'https://greengains.eremat.org/legal/privacy-policy';
const _kTermsUrl            = 'https://greengains.eremat.org/legal/terms-of-service';
const _kDataTransparencyUrl = 'https://greengains.eremat.org/legal/data-transparency';
const _kDataDeletionUrl     = 'https://greengains.eremat.org/legal/data-deletion';
const _kSectionSpacing   = AppTheme.spaceSm;
const _kIconBoxSize      = 36.0; // icon container — between spaceXl(32) and minTouchTarget(48)

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = AppPreferences.instance;
  final _locationService = ForegroundLocationService.instance;
  final _themeController = ThemeController.instance;
  final _languageController = LanguageController.instance;
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
    });
  }

  Future<void> _signOut() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsSignOutConfirmTitle),
        content: Text(l10n.settingsSignOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.settingsSignOutCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.settingsSignOutConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: [
          // ── Display ──────────────────────────────────────────────────────
          _SectionCard(
            label: l10n.settingsDisplay,
            children: [
              ListenableBuilder(
                listenable: _themeController,
                builder: (context, _) {
                  final l = context.l10n;
                  return SegmentedButton<ThemeMode>(
                    style: SegmentedButton.styleFrom(
                      textStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: AppFontWeights.semibold),
                    ),
                    segments: [
                      ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined), label: Text(l.settingsThemeLight)),
                      ButtonSegment(value: ThemeMode.dark,  icon: const Icon(Icons.dark_mode_outlined),  label: Text(l.settingsThemeDark)),
                      ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.auto_mode_outlined), label: Text(l.settingsThemeAuto)),
                    ],
                    selected: {_themeController.mode},
                    onSelectionChanged: (s) => _themeController.setMode(s.first),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spaceMd),
              ListenableBuilder(
                listenable: _languageController,
                builder: (context, _) {
                  final l = context.l10n;
                  return SegmentedButton<String?>(
                    style: SegmentedButton.styleFrom(
                      textStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: AppFontWeights.semibold),
                    ),
                    segments: [
                      ButtonSegment(value: null,  icon: const Icon(Icons.auto_mode_outlined), label: Text(l.settingsLanguageSystem)),
                      ButtonSegment(value: 'en',  icon: const Icon(Icons.language_outlined),  label: Text(l.settingsLanguageEnglish)),
                      ButtonSegment(value: 'fr',  icon: const Icon(Icons.language_outlined),  label: Text(l.settingsLanguageFrench)),
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

          // ── Tracking ──────────────────────────────────────────────────────
          _SectionCard(
            label: l10n.settingsTracking,
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([_locationService.isRunning, _locationService.isPaused]),
                builder: (context, _) => _ToggleRow(
                  icon: Icons.map_outlined,
                  iconColor: AppColors.primary,
                  title: l10n.settingsTracking,
                  subtitle: l10n.settingsTrackingDesc,
                  value: _locationService.isRunning.value || _locationService.isPaused.value,
                  onChanged: (v) async {
                    if (v) {
                      await _locationService.start();
                    } else {
                      await _locationService.stop();
                      await _prefs.setShareLocation(false);
                    }
                  },
                ),
              ),
              _divider(isDark),
              _ToggleRow(
                icon: Icons.signal_cellular_alt_outlined,
                iconColor: AppColors.movement,
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
          const SizedBox(height: _kSectionSpacing),

          // ── Account ───────────────────────────────────────────────────────
          _SectionCard(
            label: l10n.settingsAccount,
            children: [
              _NavRow(
                icon: Icons.logout_rounded,
                iconColor: AppColors.error,
                title: l10n.settingsSignOut,
                subtitle: FirebaseAuth.instance.currentUser?.email ?? '',
                onTap: _signOut,
                danger: true,
              ),
              _divider(isDark),
              _NavRow(
                icon: Icons.delete_outline_rounded,
                iconColor: AppColors.error,
                title: l10n.settingsDataDeletion,
                onTap: () => _openWebView(context, _kDataDeletionUrl, l10n.settingsDataDeletion),
                danger: true,
              ),
            ],
          ),
          const SizedBox(height: _kSectionSpacing),

          // ── About ─────────────────────────────────────────────────────────
          _SectionCard(
            label: l10n.settingsAbout,
            children: [
              _NavRow(
                icon: Icons.sensors_outlined,
                iconColor: AppColors.light,
                title: l10n.settingsDiagnostics,
                subtitle: l10n.settingsDiagnosticsDesc,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // ── Legal + version footer ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceXl),
            child: Wrap(
              spacing: AppTheme.spaceSm,
              runSpacing: AppTheme.spaceXxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_version.isNotEmpty)
                  Text(
                    l10n.settingsVersion(_version),
                    style: TextStyle(fontSize: AppTheme.fontSizeXs, color: AppColors.textTertiary(isDark)),
                  ),
                if (_version.isNotEmpty)
                  Text('·', style: TextStyle(fontSize: AppTheme.fontSizeXs, color: AppColors.textTertiary(isDark))),
                _LegalLink(label: l10n.privacyPolicy, onTap: () => _openWebView(context, _kPrivacyPolicyUrl, l10n.privacyPolicy)),
                Text('·', style: TextStyle(fontSize: AppTheme.fontSizeXs, color: AppColors.textTertiary(isDark))),
                _LegalLink(label: l10n.termsOfService, onTap: () => _openWebView(context, _kTermsUrl, l10n.termsOfService)),
                Text('·', style: TextStyle(fontSize: AppTheme.fontSizeXs, color: AppColors.textTertiary(isDark))),
                _LegalLink(label: l10n.settingsDataTransparency, onTap: () => _openWebView(context, _kDataTransparencyUrl, l10n.settingsDataTransparency)),
              ],
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

}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.spaceXxs, bottom: AppTheme.spaceXs),
          child: Text(label.toUpperCase(), style: AppTheme.eyebrowLabel(isDark)),
        ),
        Container(
          decoration: AppTheme.contentCard(isDark: isDark),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}


// ── Legal footer link ─────────────────────────────────────────────────────────

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTheme.fontSizeXs,
          color: AppColors.textTertiary(isDark),
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textTertiary(isDark).withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ── Row variants ──────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disabled = onChanged == null;
    final color = disabled
        ? AppColors.textTertiary(isDark)
        : (iconColor ?? AppColors.primary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _IconBox(icon: icon, color: color),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: AppFontWeights.semibold,
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

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = danger ? AppColors.error : AppColors.textPrimary(isDark);
    return PressScaleDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
        child: Row(
          children: [
            _IconBox(icon: icon, color: iconColor ?? AppColors.textTertiary(isDark)),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFontWeights.semibold,
                    color: titleColor,
                  )),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(
                      color: danger ? AppColors.error.withValues(alpha: 0.6) : AppColors.textSecondary(isDark),
                    )),
                ],
              ),
            ),
            if (!danger)
              Icon(Icons.chevron_right, size: AppIconSizes.sm, color: AppColors.textTertiary(isDark)),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kIconBoxSize,
      height: _kIconBoxSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(icon, size: AppIconSizes.xs, color: color),
    );
  }
}
