import 'package:flutter/material.dart';

/// Centralized color system following UI/UX design guide
class AppColors {
  AppColors._();

  // Primary brand color — Emerald 500 (modern, Stripe/Linear ecosystem)
  // Replaces Material Green 500 (0xFF4CAF50) — more vibrant, less Android-default
  static const Color primary = Color(0xFF10B981);
  static const Color primaryLight = Color(0xFF34D399); // Emerald 300
  static const Color primaryDark = Color(0xFF059669);  // Emerald 600

  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color errorDark = Color(0xFFD32F2F);

  // Light mode neutrals (Calm Tech)
  static const Color lightBackground = Color(0xFFF4F7F4);
  static const Color lightSurface = Color(0xFFF9FBF8);
  static const Color lightSurfaceElevated = Color(0xFFF0F4F1);
  static const Color lightSurfaceActive = Color(0xFFE6F1EA);

  static const Color lightTextPrimary = Color(0xFF1F2422);
  static const Color lightTextSecondary = Color(0xFF5F6A65);
  static const Color lightTextTertiary = Color(0xFF7B8781);
  static const Color lightBorder = Color(0xFFD8E0DB);
  static const Color lightDivider = Color(0xFFC8D2CC);

  // Dark mode neutrals — slightly blue-tinted navy (Nodle/Linear style).
  // Lifted from pure black to reduce harshness; blue tint adds depth.
  // bg→surface: +12 lightness, surface→elevated: +8, border: +36.
  static const Color darkBackground = Color(0xFF111927);       // dark navy (not void black)
  static const Color darkSurface = Color(0xFF1C2333);          // card surface (+12)
  static const Color darkSurfaceElevated = Color(0xFF243044);  // elevated sheet (+8)
  static const Color darkSurfaceActive = Color(0xFF2C3A52);    // pressed state

  static const Color darkTextPrimary = Color(0xFFF0F0F0);      // near-white
  static const Color darkTextSecondary = Color(0xFFA0A0A0);    // readable mid-gray
  static const Color darkTextTertiary = Color(0xFF8E8E8E);     // hints/placeholders — 4.5:1 on darkSurface
  static const Color darkBorder = Color(0xFF525252);           // clearly visible (82, +44 from surface)
  static const Color darkDivider = Color(0xFF3A3A3A);          // separator (58)

  // Helpers
  static Color shadowLight(double opacity) =>
      Colors.white.withValues(alpha: opacity);
  static Color shadowDark(double opacity) =>
      Colors.black.withValues(alpha: opacity);
  static Color primaryAlpha(double opacity) =>
      primary.withValues(alpha: opacity);

  // Theme-aware color helpers (reduces isDark ternaries)
  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color textTertiary(bool isDark) => isDark ? darkTextTertiary : lightTextTertiary;
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color surfaceElevated(bool isDark) => isDark ? darkSurfaceElevated : lightSurfaceElevated;
  static Color surfaceActive(bool isDark) => isDark ? darkSurfaceActive : lightSurfaceActive;
  static Color background(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color divider(bool isDark) => isDark ? darkDivider : lightDivider;

  static const List<Color> gradientGreen = [primaryLight, primary];
  static const List<Color> gradientRed = [error, errorDark];

  // Data Visualization & Mapping colors (for heatmaps, tiles, charts)
  static const Color accentTeal = Color(0xFF20B2AA); // Secondary brand color
  static const Color accentBlue = Color(0xFF2196F3); // For data viz variety
  static const Color accentPurple = Color(0xFF9C27B0); // Charts/graphs accent

  // Heatmap gradient (cold → neutral → hot) for intensity visualization
  static const Color heatmapCold = Color(0xFF3B82F6); // Blue (low intensity)
  static const Color heatmapMedium = Color(0xFFFFA726); // Orange (medium)
  static const Color heatmapHot = Color(0xFFEF4444); // Red (high intensity)

  // Coverage tile states (for map tiles showing visit frequency)
  static const Color tileUncovered = Color(0xFF9E9E9E); // Gray (not visited)
  static const Color tileLowCoverage = Color(0xFF81C784); // Light green (1-2 visits)
  static const Color tileMediumCoverage = Color(0xFF66BB6A); // Medium green (3-5 visits)
  static const Color tileHighCoverage = Color(0xFF4CAF50); // Dark green (6+ visits)

  // Achievement/reward tier colors
  static const Color tierBronze = Color(0xFFCD7F32);
  static const Color tierSilver = Color(0xFFC0C0C0);
  static const Color tierGold = Color(0xFFFFD700);
  static const Color tierPlatinum = Color(0xFFE5E4E2);

  // Box shadows for depth
  static List<BoxShadow> elevationLight({required bool active}) {
    return [
      BoxShadow(
        color: shadowLight(0.8),
        offset: const Offset(0, -1),
        blurRadius: 1,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: shadowDark(active ? 0.1 : 0.04),
        offset: const Offset(0, 2),
        blurRadius: active ? 9 : 5,
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> elevationDark({required bool active}) {
    return [
      BoxShadow(
        color: shadowLight(0.05),
        offset: const Offset(0, -1),
        blurRadius: 1,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: shadowDark(active ? 0.32 : 0.24),
        offset: const Offset(0, 2),
        blurRadius: active ? 9 : 5,
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> buttonShadow(bool isDark) {
    return [
      BoxShadow(
        color: isDark ? shadowLight(0.05) : shadowLight(0.2),
        offset: const Offset(0, -1),
        blurRadius: 0,
      ),
      BoxShadow(
        color: isDark ? shadowDark(0.6) : shadowDark(0.2),
        offset: const Offset(0, 3),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ];
  }

  /// Frosted-glass BoxDecoration — pair with ClipRRect + BackdropFilter(glassBlurSigma).
  /// Keeps the blur/border/opacity system consistent across all glass overlays.
  /// Pass [isDark] to adapt the tint and border for light vs dark mode.
  /// For overlays always on dark backgrounds (map chip, FAB), pass isDark: true.
  static BoxDecoration glassDecoration({
    required bool isDark,
    double backgroundAlpha = 0.50,
    double borderAlpha = 0.10,
  }) =>
      BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: backgroundAlpha),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: borderAlpha),
        ),
      );

  static List<BoxShadow> glowEffect(Color color, {double opacity = 0.4}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: 4,
        spreadRadius: 1,
      )
    ];
  }

  // Shimmer colors for loading states
  static Color shimmerBase(bool isDark) => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0);
  static Color shimmerHighlight(bool isDark) => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFAFAFA);

  // Sensor data visualization colors (used in charts, map tiles, sensor cards)
  static const Color light     = Color(0xFFFBBF24); // Amber-400   — light sensor (sun = yellow)
  static const Color movement  = Color(0xFFF97316); // Orange-500  — movement/accel (heat/activity)
  static const Color pressure  = Color(0xFF818CF8); // Indigo-400  — air pressure (meteorology conv.)
  static const Color quality   = Color(0xFF10B981); // Emerald-500 — data quality / air (AQI green)
  static const Color community = Color(0xFF6366F1); // Indigo-500  — community/global tiles

  // MapLibre GL hex strings — mirrors the Color constants above.
  // MapLibre layer paint properties require '#rrggbb' strings, not Color objects.
  static const String lightHex     = '#fbbf24';
  static const String movementHex  = '#f97316';
  static const String pressureHex  = '#818cf8';
  static const String qualityHex   = '#10b981';
  static const String communityHex = '#6366f1';
  static const String primaryHex   = '#10b981';
  static const String warningHex   = '#f59e0b'; // amber-400 — matches AppColors.warning

  // Accent colors for rewards and achievements (complementary to green)
  static const Color accentMagenta = Color(0xFFE91E63); // Material pink 500
  static const Color accentMagentaLight = Color(0xFFF06292); // Material pink 300

  // Refined semantic colors
  static const Color info = Color(0xFF29B6F6); // Material light blue 400

  // Surface tint system (Material 3 pattern)
  static Color surfaceTint(bool isDark) => isDark
      ? primary.withValues(alpha: 0.05)
      : primary.withValues(alpha: 0.02);

  // Action button colors — home screen floating controls
  static const Color actionPrimaryFg  = Color(0xFF04221a); // dark forest on green bg
  static const Color actionSecondaryBg = Color(0xFF1c2f2a); // dark green surface
  static const Color actionDangerBg    = Color(0xFF2a1c1c); // dark red surface
  static const Color actionSegActiveFg = Color(0xFF04221a); // segment active fg (same as primary)

  // Map overlay tints — frosted glass pills that float above the dark map.
  // Always rendered on a dark background, so these use darkBackground as the tint color.
  // Use these instead of hardcoded hex Color(0x??111927) values.
  static const Color mapOverlayDark  = Color(0xD9111927); // 85% — primary pill bg
  static const Color mapOverlayMid   = Color(0xCC111927); // 80% — secondary (layer toggle, hints)
  static const Color mapOverlayLight = Color(0xB2111927); // 70% — subtle (no-zone tracking hint)
  static const Color mapOverlayGreen = Color(0xCC0B1E15); // 80% green-tinted (live conditions)
}

/// Animation duration constants for consistent timing across the app
/// Inspired by Wonderous design system
class AppDurations {
  AppDurations._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 300);
  static const Duration medium = Duration(milliseconds: 600);
  static const Duration slow = Duration(milliseconds: 900);
  static const Duration pageTransition = Duration(milliseconds: 200);
  static const Duration shimmer = Duration(milliseconds: 750);
}

/// Border and stroke widths
class AppBorderWidths {
  AppBorderWidths._();

  static const double hairline   = 0.5; // subtle container borders
  static const double thin       = 1.0; // standard dividers
  static const double medium     = 1.5; // emphasis borders
  static const double thick      = 3.0; // accent stripes (kpi cards)
  static const double spinner    = 2.0; // circular progress indicators
  static const double ringStroke = 4.5; // milestone ring painter
}

/// Opacity scale for consistent alpha usage
class AppOpacity {
  AppOpacity._();

  static const double disabled  = 0.38;
  static const double hint      = 0.55;
  static const double secondary = 0.65;
  static const double subtle    = 0.75;
  static const double overlay   = 0.85;
}

/// Animation slide/offset distances (dp) for enter/exit transitions
class AppOffsets {
  AppOffsets._();

  static const double slideXs  = 8.0;
  static const double slideSm  = 12.0;
  static const double slideMd  = 18.0;  // standard enter-from-bottom
  static const double slideLg  = 28.0;  // hero / page-level transitions
  static const double shadowY  = 2.0;   // standard shadow y-offset
}

/// Text shadow presets for premium look on floating elements
/// Used for elevated UI elements, overlays, and emphasis
class AppShadows {
  AppShadows._();

  /// Soft shadow for subtle depth (buttons, cards)
  static const textSoft = [
    Shadow(
      color: Color(0x40000000), // black26
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  /// Standard shadow for regular emphasis (titles, CTAs)
  static const text = [
    Shadow(
      color: Color(0x99000000), // black54
      offset: Offset(0, 2),
      blurRadius: 2,
    ),
  ];

  /// Strong shadow for maximum contrast (hero text, overlays)
  static const textStrong = [
    Shadow(
      color: Color(0x99000000), // black54
      offset: Offset(0, 4),
      blurRadius: 6,
    ),
  ];
}

/// Reusable gradients for consistent visual effects
/// Used for active states, backgrounds, and emphasis
class AppGradients {
  AppGradients._();

  /// Green glow for active sensor cards and primary CTAs
  static LinearGradient greenGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primary.withValues(alpha: 0.15),
      AppColors.primaryLight.withValues(alpha: 0.20),
    ],
  );

  /// Button/FAB gradient: top-left light → bottom-right darkened.
  /// Gives depth without needing a separate shadow pass.
  static LinearGradient darkBottomGradient(Color base) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      base.withValues(alpha: 0.95),
      Color.lerp(base, Colors.black, 0.20)!,
    ],
  );

  /// Subtle neutral surface gradient — NO color tint.
  /// Used sparingly for depth; prefer flat colors for most surfaces.
  static LinearGradient surfaceGlow(bool isDark) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? [
            const Color(0xFF171717),
            const Color(0xFF1F1F1F),
          ]
        : [
            const Color(0xFFF9FBF9),
            const Color(0xFFF2F4F3),
          ],
  );
}

/// Font weight scale for typography personality
/// Clean, readable weights without extreme condensing
class AppFontWeights {
  AppFontWeights._();

  static const thin = FontWeight.w300;
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semibold = FontWeight.w600;
  static const bold = FontWeight.w700;
  // Note: w900 removed - too heavy and condensed looking
}

/// Motion personality - easing curves that define our animation character
/// Consistent curves make animations feel intentional, not arbitrary
class AppMotion {
  AppMotion._();

  /// Smooth, confident motion for most animations
  static const standard = Curves.easeInOutCubic;

  /// Slight bounce for positive events (upload success, achievements)
  static const emphasized = Curves.easeOutBack;

  /// Fast start, gentle end for appearing elements
  static const decelerated = Curves.easeOut;

  /// Gentle start, fast end for disappearing elements
  static const accelerated = Curves.easeIn;
}

/// Icon size scale for consistency
/// Prevents arbitrary icon sizes scattered through the app
class AppIconSizes {
  AppIconSizes._();

  static const double xxs = 14;
  static const double xs  = 16;
  static const double sm  = 20;
  static const double md  = 24;
  static const double lg  = 32;
  static const double xl  = 48;
}

/// Line-height (height) scale for Text widgets
class AppLineHeights {
  AppLineHeights._();

  static const double tight   = 1.1; // display numbers, headings
  static const double snug    = 1.3; // card body copy
  static const double normal  = 1.4; // default body
  static const double relaxed = 1.5; // longer paragraphs
}

class AppTheme {
  // Spacing scale (comprehensive)
  static const double spaceXxxs = 2;  // Micro spacing — dot gaps, tight icon rows
  static const double spaceTiny = 3;  // stat item inner gaps, accent strips
  static const double spaceXxs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double spaceXxl = 48;

  // Common layout tokens
  static const double ctaGapLink = 4;
  static const double bottomSafe = 16;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(24, 16, 24, bottomSafe);
  static const double onboardingLinkBottomGap = 28;

  // Radii
  static const double radiusMin = 4;   // Minimal radius for subtle rounding
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999; // Fully rounded (pill shape)

  // Touch targets (accessibility)
  static const double minTouchTarget = 48;

  // Floating nav bar
  static const double floatingNavHeight = 64;
  static const double fontSizeNavLabel  = 10.0; // sub-caption, below bodySmall(12)

  // Sub-body font sizes
  static const double fontSizeXxs  = 10.0; // micro — nav labels only
  static const double fontSizeXs   = 12.0; // captions, badges, secondary labels
  static const double fontSizeBody  = 13.0; // card body copy, secondary text
  static const double fontSizeSm      = 14.0; // primary body, comfortable reading
  static const double fontSizeMd      = 15.0; // emphasis body, sheet titles
  static const double fontSizeLg      = 22.0; // card headlines, weekly goal title
  static const double fontSizeDisplay = 80.0; // hero display number (session summary)

  // Glass UI constants (BackdropFilter + frosted container)
  static const double glassBlurSigma = 16.0; // consistent across all glass overlays

  // Onboarding hero sizing
  static const double onboardingHeroMin = 280;
  static const double onboardingHeroMax = 460;
  static const double onboardingHeroIconRatio = 0.46;

  // Drag handle — standard across all bottom sheets
  static const double dragHandleWidth  = 36.0;
  static const double dragHandleHeight = 4.0;

  // Sensor/stat card dot indicator
  static const double dotSize = 6.0;

  // Common component sizes
  static const double tileTrailingButtonWidth = 120;
  static const double tileTrailingButtonHeight = 40;
  static const double authButtonHeight = 56;

  /// Standard drag handle pill — use at the top of every bottom sheet.
  static Widget dragHandle(bool isDark) => Center(
        child: Container(
          width: dragHandleWidth,
          height: dragHandleHeight,
          margin: const EdgeInsets.only(top: spaceSm, bottom: spaceSm),
          decoration: BoxDecoration(
            color: AppColors.border(isDark),
            borderRadius: BorderRadius.circular(radiusMin),
          ),
        ),
      );

  static String googleButtonAsset(Brightness b) => b == Brightness.dark
      ? 'assets/brands/google_button_dark.svg'
      : 'assets/brands/google_button_light.svg';

  // Typography Helpers - Clean, readable styles using design tokens

  /// Large numbers for statistics (clean, not condensed)
  static TextStyle displayNumber(ThemeData theme) {
    return theme.textTheme.displayMedium!.copyWith(
      fontWeight: AppFontWeights.bold,
      height: 1.1,
      letterSpacing: -0.5, // Subtle tightening for large numbers
    );
  }

  /// Section headers (Environment, Motion, etc.)
  static TextStyle sectionHeader(ThemeData theme, bool isDark) {
    return theme.textTheme.labelLarge!.copyWith(
      fontWeight: AppFontWeights.semibold,
      letterSpacing: 0.6,
      color: AppColors.textSecondary(isDark).withValues(alpha: 0.85),
    );
  }

  /// Card titles (readable, not heavy)
  static TextStyle cardTitle(ThemeData theme) {
    return theme.textTheme.titleLarge!.copyWith(
      fontWeight: AppFontWeights.semibold,
      letterSpacing: -0.2,
    );
  }

  /// Small header with subtle shadow
  static TextStyle smallHeader(ThemeData theme) {
    return theme.textTheme.titleSmall!.copyWith(
      fontWeight: AppFontWeights.semibold,
      shadows: AppShadows.textSoft,
    );
  }

  /// Badge/pill text styling
  static TextStyle badge(bool isDark, Color color) {
    return TextStyle(
      color: isDark ? Colors.white : color,
      fontWeight: AppFontWeights.semibold,
      fontSize: 12,
    );
  }

  // Decoration Helpers - reduces ~150 lines of duplicate code

  /// Creates a surface container with elevation and theme-aware colors
  /// Used for cards, panels, and elevated surfaces throughout the app
  static BoxDecoration surfaceContainer({
    required bool isDark,
    bool active = false,
    bool elevated = false,
    double radius = radiusMd,
    Border? border,
  }) {
    Color bgColor;
    if (active) {
      bgColor = AppColors.surfaceActive(isDark);
    } else if (elevated) {
      bgColor = AppColors.surfaceElevated(isDark);
    } else {
      bgColor = AppColors.surface(isDark);
    }

    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(radius),
      border: border,
      boxShadow: isDark
          ? AppColors.elevationDark(active: active)
          : AppColors.elevationLight(active: active),
    );
  }

  /// Standard content card — elevated surface with hairline border.
  /// Use for any card that holds data (stat tiles, KPI cells, sensor cards, sheet stats).
  static BoxDecoration contentCard({required bool isDark, Color? accentBorder}) =>
      BoxDecoration(
        color: AppColors.surfaceElevated(isDark),
        borderRadius: BorderRadius.circular(radiusMd),
        border: accentBorder != null
            ? Border.all(color: accentBorder, width: AppBorderWidths.thin)
            : Border.all(color: AppColors.border(isDark), width: AppBorderWidths.hairline),
      );

  /// Standard section eyebrow label — ALL CAPS, small, muted.
  /// Use above charts, KPI rows, and data sections.
  static TextStyle eyebrowLabel(bool isDark) => TextStyle(
        fontSize: fontSizeXs,
        fontWeight: AppFontWeights.semibold,
        color: AppColors.textTertiary(isDark),
        letterSpacing: 0.8,
      );

  /// Label below a big stat number — consistent across all stat cells.
  static TextStyle statLabel(bool isDark) => TextStyle(
        fontSize: fontSizeXs,
        color: AppColors.textTertiary(isDark),
        fontWeight: AppFontWeights.medium,
        height: AppLineHeights.snug,
      );

  /// KPI card decoration — flat surface with a colored left-border accent.
  static BoxDecoration kpiCard({
    required bool isDark,
    Color accentColor = AppColors.primary,
    double radius = radiusLg,
  }) =>
      BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(radius),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
      );

  /// Creates an icon container with primary-colored background
  /// Used for feature icons, status indicators, etc.
  static BoxDecoration iconContainer({
    required bool isDark,
    bool active = false,
    double padding = spaceSm,
    double radius = radiusSm,
  }) {
    return BoxDecoration(
      color: active
          ? AppColors.primaryAlpha(0.15)
          : AppColors.surfaceElevated(isDark),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  static const _seed = Color(0xFF059669); // Emerald 600 — drives Material 3 ColorScheme

  static TextTheme _buildTextTheme(TextTheme base, {required bool isDark}) {
    // System font (Roboto on Android, SF Pro on iOS) — no extra download
    final body = base;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return body.copyWith(
      displayLarge: body.displayLarge?.copyWith(
        fontWeight: AppFontWeights.bold,
        letterSpacing: -0.5,
        color: textColor,
      ),
      displayMedium: body.displayMedium?.copyWith(
        fontWeight: AppFontWeights.bold,
        letterSpacing: -0.5,
        color: textColor,
      ),
      displaySmall: body.displaySmall?.copyWith(
        fontWeight: AppFontWeights.semibold,
        letterSpacing: 0,
        color: textColor,
      ),
      headlineLarge: body.headlineLarge?.copyWith(
        fontWeight: AppFontWeights.bold,
        letterSpacing: 0,
        color: textColor,
      ),
      headlineMedium: body.headlineMedium?.copyWith(
        fontWeight: AppFontWeights.semibold,
        letterSpacing: 0,
        color: textColor,
      ),
      headlineSmall: body.headlineSmall?.copyWith(
        fontWeight: AppFontWeights.semibold,
        letterSpacing: 0,
        color: textColor,
      ),
      titleLarge: body.titleLarge?.copyWith(
        fontWeight: AppFontWeights.semibold,
        letterSpacing: 0,
        color: textColor,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontWeight: AppFontWeights.semibold,
        color: textColor,
      ),
      titleSmall: body.titleSmall?.copyWith(
        fontWeight: AppFontWeights.semibold,
        color: textColor,
      ),
      bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, color: textColor),
      bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, color: textColor), // M3 spec: 14
      bodySmall: body.bodySmall?.copyWith(fontSize: 12, color: secondary),   // M3 spec: 12
      labelLarge: body.labelLarge?.copyWith(fontWeight: AppFontWeights.semibold, color: textColor),
      labelMedium: body.labelMedium?.copyWith(fontWeight: AppFontWeights.medium, color: textColor),
    );
  }

  static ThemeData theme() {
    final base = ThemeData(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      onSurfaceVariant: const Color(0xFF4E5A55),
    );
    final textTheme = _buildTextTheme(base.textTheme, isDark: false);
    return base.copyWith(
      colorScheme: scheme,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      }),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background(false),
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: scheme.onSurface,
          ),
        ),
      ),
      scaffoldBackgroundColor: AppColors.background(false),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background(false),
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF2F6F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFFD9E1DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFFD9E1DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF8EA5A1), width: 1.2),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
          side: BorderSide(color: AppColors.lightBorder),
          foregroundColor: AppColors.lightTextPrimary,
          backgroundColor: Colors.white,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          visualDensity: VisualDensity.standard,
        ),
      ),
      textTheme: textTheme,
    );
  }

  static ThemeData themeDark() {
    final base = ThemeData(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark)
        .copyWith(
      onSurfaceVariant: const Color(0xFF9DA7A2),
      // Force all text to be white/readable in dark mode
      onSurface: AppColors.darkTextPrimary,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );
    final textTheme = _buildTextTheme(base.textTheme, isDark: true);
    return base.copyWith(
      colorScheme: scheme,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      }),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background(true),
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
      scaffoldBackgroundColor: AppColors.background(true),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background(true),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.darkTextPrimary,
        textColor: AppColors.darkTextPrimary,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.darkTextSecondary),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF111111), // neutral dark, no green tint
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF2E2E2E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF2E2E2E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF525252), width: 1.2),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
          side: const BorderSide(color: Color(0xFF2E2E2E)),
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF111111),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          visualDensity: VisualDensity.standard,
        ),
      ),
      textTheme: textTheme,
      brightness: Brightness.dark,
    );
  }
}
