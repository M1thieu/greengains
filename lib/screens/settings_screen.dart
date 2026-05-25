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
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: AppTheme.spaceXxs, bottom: AppTheme.spaceXs),
                  child: Text(l10n.settingsAccount.toUpperCase(), style: AppTheme.eyebrowLabel(isDark)),
                ),
              ),
              IconButton(
                icon: Icon(Icons.logout_rounded, size: AppIconSizes.sm, color: AppColors.textTertiary(isDark)),
                onPressed: _signOut,
                tooltip: l10n.settingsSignOut,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          _UserIdentityRow(isDark: isDark),
          const SizedBox(height: _kSectionSpacing * 2),

          // ── About ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: AppTheme.spaceXxs, bottom: AppTheme.spaceXs),
            child: Text(l10n.settingsAbout.toUpperCase(), style: AppTheme.eyebrowLabel(isDark)),
          ),
          PressScaleDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.settingsDiagnostics, style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: AppFontWeights.semibold,
                          color: AppColors.textPrimary(isDark),
                        )),
                        Text(l10n.settingsDiagnosticsDesc, style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(isDark),
                        )),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: AppIconSizes.sm, color: AppColors.textTertiary(isDark)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceXl),

          // ── Footer: version + legal ───────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceXl),
              child: Column(
                children: [
                  if (_version.isNotEmpty)
                    Text(
                      l10n.settingsVersion(_version),
                      style: TextStyle(fontSize: AppTheme.fontSizeNavLabel, color: AppColors.textTertiary(isDark)),
                    ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegalLink(
                        label: l10n.settingsLegal,
                        isDark: isDark,
                        onTap: () => _showLegalSheet(context, l10n, isDark),
                      ),
                    ],
                  ),
                ],
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
          ]),
        );
      },
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

class _UserIdentityRow extends StatelessWidget {
  const _UserIdentityRow({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName;
    final email = user?.email ?? '';
    final initials = name != null && name.isNotEmpty
        ? name.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase()
        : email.isNotEmpty ? email[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
      child: Row(
        children: [
          Container(
            width: AppTheme.iconBoxMd,
            height: AppTheme.iconBoxMd,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeMd,
                  fontWeight: AppFontWeights.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name != null && name.isNotEmpty) ...[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: AppFontWeights.semibold,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXxxs),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ] else
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: AppFontWeights.semibold,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppTheme.iconBoxSm,
      height: AppTheme.iconBoxSm,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(icon, size: AppIconSizes.xs, color: color),
    );
  }
}
