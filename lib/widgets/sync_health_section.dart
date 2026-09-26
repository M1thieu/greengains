import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/app_preferences.dart';
import '../core/extensions/context_extensions.dart';
import '../core/themes.dart';
import 'section_header.dart';
import 'time_ago_text.dart';

/// DEVELOPER-ONLY upload / network health panel. Not a product feature.
///
/// End users never see this: it renders nothing outside debug builds, and DiagnosticsScreen
/// does not even build it there (so release tree-shaking drops it). It exists because a failing
/// uploader used to be completely silent — the production server was down for months and
/// nothing on the phone said so. Plain English on purpose: dev tooling, not user-facing copy.
class SyncHealthSection extends StatefulWidget {
  const SyncHealthSection({super.key});

  @override
  State<SyncHealthSection> createState() => _SyncHealthSectionState();
}

class _SyncHealthSectionState extends State<SyncHealthSection> {
  static const _pollInterval = Duration(seconds: 5);

  Timer? _timer;
  Map<String, dynamic>? _health;

  @override
  void initState() {
    super.initState();
    if (!kDebugMode) return;
    _load();
    _timer = Timer.periodic(_pollInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = AppPreferences.instance;
    await prefs.reload();
    if (mounted) setState(() => _health = prefs.uploadHealth);
  }

  int _int(String key) => (_health?[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink(); // defence in depth: never in release

    final isDark = context.isDarkMode;
    final h = _health;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Dev · sync health'),
        Container(
          width: double.infinity,
          decoration: AppTheme.contentCard(isDark: isDark),
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: h == null
              ? Text(
                  'Nothing recorded yet. Start tracking.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                )
              : _rows(context, isDark, h),
        ),
      ],
    );
  }

  Widget _rows(BuildContext context, bool isDark, Map<String, dynamic> h) {
    final lastSuccessMs = (h['last_success_at'] as num?)?.toInt();
    final failures = _int('consecutive_failures');
    final lastError = h['last_error'] as String?;
    final transport = h['transport'] as String? ?? 'none';

    final rows = <Widget>[
      _Row(
        label: 'Network',
        child: _value(
          context,
          transport == 'none'
              ? 'none'
              : '$transport · ${h['validated'] == true ? 'validated' : 'NOT validated'}'
                  ' · ${h['metered'] == true ? 'metered' : 'unmetered'}',
        ),
      ),
      _Row(
        label: 'Last successful sync',
        child: lastSuccessMs == null
            ? _value(context, 'never')
            : TimeAgoText(
                timestamp: DateTime.fromMillisecondsSinceEpoch(lastSuccessMs),
                style: _valueStyle(context),
              ),
      ),
      _Row(
        label: 'Failures in a row',
        child: _value(context, '$failures', color: failures > 0 ? AppColors.error : null),
      ),
      if (lastError != null) _Row(label: 'Last error', child: _value(context, lastError)),
      _Row(
        label: 'Waiting to send',
        child: _value(context, '${_int('buffer')} readings · ${_int('retry_queue')} batches'),
      ),
      _Row(
        label: 'Lost since start',
        child: _value(context, '${_int('dropped_batches')} batches · ${_int('dropped_readings')} readings'),
      ),
      _Row(label: 'Cut by network change', child: _value(context, '${_int('interrupted')}')),
      _Row(label: 'Network changes', child: _value(context, '${_int('transitions')}')),
    ];

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: AppTheme.spaceMd, thickness: 0.5, color: AppColors.divider(isDark)),
          rows[i],
        ],
      ],
    );
  }

  TextStyle? _valueStyle(BuildContext context, {Color? color}) {
    final isDark = context.isDarkMode;
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color ?? AppColors.textPrimary(isDark),
          fontWeight: AppFontWeights.semibold,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
  }

  Widget _value(BuildContext context, String text, {Color? color}) =>
      Text(text, textAlign: TextAlign.end, style: _valueStyle(context, color: color));
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
          ),
        ),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(flex: 6, child: Align(alignment: Alignment.centerRight, child: child)),
      ],
    );
  }
}
