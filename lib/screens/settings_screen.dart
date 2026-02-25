import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import '../core/theme_controller.dart';
import '../core/language_controller.dart';
import '../core/app_preferences.dart';
import 'webview_screen.dart';

/// Settings screen for Data & Privacy, Themes, and Legal
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = AppPreferences.instance;
  final _themeController = ThemeController.instance;
  final _languageController = LanguageController.instance;
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: [
          _SettingsSectionContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsSectionTitle(text: l10n.settingsTheme),
                ListenableBuilder(
                  listenable: _themeController,
                  builder: (context, _) {
                    final l = context.l10n;
                    return SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: const Icon(Icons.light_mode),
                          label: Text(l.settingsThemeLight),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: const Icon(Icons.dark_mode),
                          label: Text(l.settingsThemeDark),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: const Icon(Icons.auto_mode),
                          label: Text(l.settingsThemeAuto),
                        ),
                      ],
                      selected: {_themeController.mode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        HapticFeedback.selectionClick();
                        _themeController.setMode(newSelection.first);
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spaceLg),

          _SettingsSectionContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsSectionTitle(text: l10n.settingsLanguage),
                ListenableBuilder(
                  listenable: _languageController,
                  builder: (context, _) {
                    final l = context.l10n;
                    return SegmentedButton<String?>(
                      segments: [
                        ButtonSegment(
                          value: null,
                          icon: const Icon(Icons.auto_mode),
                          label: Text(l.settingsLanguageSystem),
                        ),
                        ButtonSegment(
                          value: 'en',
                          icon: const Icon(Icons.language),
                          label: Text(l.settingsLanguageEnglish),
                        ),
                        ButtonSegment(
                          value: 'fr',
                          icon: const Icon(Icons.language),
                          label: Text(l.settingsLanguageFrench),
                        ),
                      ],
                      selected: {_languageController.locale?.languageCode},
                      onSelectionChanged: (Set<String?> newSelection) {
                        HapticFeedback.selectionClick();
                        final code = newSelection.first;
                        _languageController.setLocale(
                          code != null ? Locale(code) : null,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spaceLg),

          _SettingsSectionContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsSectionTitle(text: l10n.settingsPrivacy),
                _SettingsToggleRow(
                  icon: Icons.location_on_outlined,
                  title: l10n.settingsLocationSharing,
                  subtitle: l10n.settingsLocationDescription,
                  value: _prefs.shareLocation,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _prefs.setShareLocation(value);
                    });
                  },
                ),
                const SizedBox(height: AppTheme.spaceSm),
                _SettingsToggleRow(
                  icon: Icons.podcasts_outlined,
                  title: l10n.settingsMobileData,
                  subtitle: l10n.settingsMobileDataDescription,
                  value: _prefs.useMobileUploads,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _prefs.setUseMobileUploads(value);
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spaceLg),

          // Legal footer — minimal text links, no card (industry standard: Stripe, Linear, Notion)
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                _legalLink(context, l10n.privacyPolicy, 'https://greengains.eremat.org/privacy-policy', theme),
                Text(' · ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                _legalLink(context, l10n.termsOfService, 'https://greengains.eremat.org/terms-of-service', theme),
                Text(' · ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                _legalLink(context, l10n.settingsDataDeletion, 'https://greengains.eremat.org/data-deletion-request', theme),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spaceSm),

          Center(
            child: Text(
              l10n.settingsVersion(_version),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openWebView(BuildContext context, String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          url: url,
          title: title,
        ),
      ),
    );
  }

  Widget _legalLink(BuildContext context, String label, String url, ThemeData theme) {
    return GestureDetector(
      onTap: () => _openWebView(context, url, label),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Text(
        text,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: AppFontWeights.bold,
        ),
      ),
    );
  }
}

class _SettingsSectionContainer extends StatelessWidget {
  const _SettingsSectionContainer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLg),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.surfaceContainer(isDark: isDark),
      child: child,
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSm),
          decoration: AppTheme.iconContainer(isDark: isDark, active: value),
          child: Icon(
            icon,
            color: value ? AppColors.primary : AppColors.textTertiary(isDark),
          ),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXxs),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SettingsNavRow extends StatelessWidget {
  const _SettingsNavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceSm),
            decoration: AppTheme.iconContainer(isDark: isDark, active: true),
            child: Icon(
              icon,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXxs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          const ExcludeSemantics(child: Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}
