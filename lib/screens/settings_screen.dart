import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/themes.dart';
import '../core/theme_controller.dart';
import '../core/language_controller.dart';
import '../core/app_preferences.dart';
import '../l10n/app_localizations.dart';
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

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: [
          _SettingsSectionContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsSectionTitle(text: 'Theme'),
                ListenableBuilder(
                  listenable: _themeController,
                  builder: (context, _) {
                    return SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Dark'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.auto_mode),
                          label: Text('Auto'),
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
                _SettingsSectionTitle(text: AppLocalizations.of(context)!.settingsLanguage),
                ListenableBuilder(
                  listenable: _languageController,
                  builder: (context, _) {
                    final l10n = AppLocalizations.of(context)!;
                    return SegmentedButton<String?>(
                      segments: [
                        ButtonSegment(
                          value: null,
                          icon: const Icon(Icons.auto_mode),
                          label: Text(l10n.settingsLanguageSystem),
                        ),
                        ButtonSegment(
                          value: 'en',
                          icon: const Icon(Icons.language),
                          label: Text(l10n.settingsLanguageEnglish),
                        ),
                        ButtonSegment(
                          value: 'fr',
                          icon: const Icon(Icons.language),
                          label: Text(l10n.settingsLanguageFrench),
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
                _SettingsSectionTitle(text: 'Data & Privacy'),
                _SettingsToggleRow(
                  icon: Icons.location_on_outlined,
                  title: 'Share Location',
                  subtitle: 'Enable location for coverage map and H3 tiles',
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
                  title: 'Use Mobile Data',
                  subtitle: 'Upload contributions over LTE/5G when needed',
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

          _SettingsSectionContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsSectionTitle(text: 'Legal'),
                _SettingsNavRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we handle your data',
                  onTap: () => _openWebView(
                    context,
                    'https://greengains.eremat.org/privacy-policy',
                    'Privacy Policy',
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                _SettingsNavRow(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'Usage terms and conditions',
                  onTap: () => _openWebView(
                    context,
                    'https://greengains.eremat.org/terms-of-service',
                    'Terms of Service',
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                _SettingsNavRow(
                  icon: Icons.delete_outline,
                  title: 'Request Data Deletion',
                  subtitle: 'Remove your contributions',
                  onTap: () => _openWebView(
                    context,
                    'https://greengains.eremat.org/data-deletion-request',
                    'Request Data Deletion',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spaceLg),

          Center(
            child: Text(
              'Version $_version',
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
      onTap: onTap,
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
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
