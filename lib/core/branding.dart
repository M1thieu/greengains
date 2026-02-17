/// Branding Constants
///
/// Single source of truth for app name and branding across the Flutter app.
/// Update these values when rebranding - all references will update automatically.
///
/// CRITICAL: Package ID must NEVER change to avoid requiring reinstalls.

class Branding {
  Branding._(); // Private constructor - use static members only

  /// App display name - used in UI, notifications, etc.
  /// UPDATE THIS when rebranding
  static const String appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'GreenGains');

  /// App display name for specific contexts
  /// UPDATE THIS when rebranding
  static const String appDisplayName =
      String.fromEnvironment('APP_DISPLAY_NAME', defaultValue: 'GreenGains');

  /// Package identifier - MUST NEVER CHANGE
  /// Changing this would require all users to reinstall the app
  static const String packageId = 'com.eremat.greengains';

  /// Firebase project identifier - MUST NEVER CHANGE
  /// Changing this would break authentication for all users
  static const String firebaseProjectId = 'greengains-f46f7';

  /// Tagline for branding
  /// UPDATE THIS when rebranding
  static const String tagline = 'Passive ambient sensor monitoring';

  /// SharedPreferences prefix
  /// UPDATE THIS when rebranding to avoid conflicts
  static String get prefsPrefix =>
      const String.fromEnvironment('APP_NAME', defaultValue: 'greengains')
          .toLowerCase();

  /// Generate SharedPreferences key with app prefix
  static String prefsKey(String key) => '${prefsPrefix}_$key';
}
