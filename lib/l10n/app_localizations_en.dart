// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get onboardingWelcomeTitle => 'Your city, mapped block by block';

  @override
  String get onboardingWelcomeSubtitle =>
      'Your phone passively collects environmental data — light, pressure, movement — while you go about your day. You help build the sensor network cities can\'t afford. You get rewarded for it.';

  @override
  String get onboardingFeature1Title => 'Runs silently';

  @override
  String get onboardingFeature1Description =>
      'Works in the background while you commute, walk, or sleep. No tapping, no setup — ever again.';

  @override
  String get onboardingFeature2Title => 'Anonymized by design';

  @override
  String get onboardingFeature2Description =>
      'Sensor readings are bundled with thousands of others before leaving your device. No personal data, ever.';

  @override
  String get onboardingFeature3Title => 'Real data, real impact';

  @override
  String get onboardingFeature3Description =>
      'Your readings go into a live environmental map used by researchers and urban planners. Every street covered is data that didn\'t exist before.';

  @override
  String get onboardingSignInTitle => 'Join the network';

  @override
  String get onboardingSignInSubtitle =>
      'Sign in to sync your contributions across devices and track your daily streak.';

  @override
  String get onboardingCloudSync => 'Live Coverage Map';

  @override
  String get onboardingCloudSyncDescription =>
      'Watch your personal coverage area grow in real time';

  @override
  String get onboardingFutureFeatures => 'Coming Soon';

  @override
  String get onboardingFutureDescription =>
      'Revenue sharing, data insights, and contributor milestones';

  @override
  String onboardingPrivacyNotice(String privacyPolicy, String termsOfService) {
    return 'By continuing, you agree to our $privacyPolicy and $termsOfService.';
  }

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get buttonPrevious => 'Previous';

  @override
  String get buttonNext => 'Next';

  @override
  String get signInSuccess => 'Signed in successfully';

  @override
  String get signInError => 'Sign-in cancelled or failed';

  @override
  String get navHome => 'Home';

  @override
  String get navStats => 'Stats';

  @override
  String get navProfile => 'Profile';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeTitle => 'GreenGains';

  @override
  String get startTracking => 'Start Tracking';

  @override
  String get stopTracking => 'Stop Tracking';

  @override
  String get trackingActive => 'Tracking Active';

  @override
  String get trackingPaused => 'Tracking Paused';

  @override
  String get trackingStopped => 'Tracking Stopped';

  @override
  String get uploadSuccess => 'Upload successful';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String lastUpload(String time) {
    return 'Last upload: $time';
  }

  @override
  String get noUploadYet => 'No upload yet';

  @override
  String get dailyPotTitle => 'Daily Pot';

  @override
  String dailyPotClaimButton(int amount) {
    return 'Claim $amount Credits';
  }

  @override
  String dailyPotClaimed(int amount) {
    return '+$amount credits! 🍯';
  }

  @override
  String get dailyPotAlreadyClaimed =>
      'Already claimed today! Come back tomorrow';

  @override
  String dailyPotNeedMoreUploads(int count, String s) {
    return 'Need $count more upload$s to unlock';
  }

  @override
  String dailyPotProgress(int current, int required) {
    return '$current / $required uploads';
  }

  @override
  String credits(int count) {
    return '$count credits';
  }

  @override
  String get totalCredits => 'Total Credits';

  @override
  String get creditsEarned => 'Credits Earned';

  @override
  String get statsTitle => 'Your Impact';

  @override
  String get totalUploads => 'Total Uploads';

  @override
  String get todayUploads => 'Today\'s Uploads';

  @override
  String get coverageTiles => 'Coverage Tiles';

  @override
  String get dataCollected => 'Data Collected';

  @override
  String timesContributed(int count) {
    return '$count times contributed';
  }

  @override
  String get mapTitle => 'Coverage Map';

  @override
  String get mapRecenter => 'Recenter';

  @override
  String get mapZoomIn => 'Zoom In';

  @override
  String get mapZoomOut => 'Zoom Out';

  @override
  String get mapYourLocation => 'Your Location';

  @override
  String get mapCoverageLegend => 'Coverage';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileSignedInAs => 'Signed in as';

  @override
  String profileMemberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get profileDeleteAccount => 'Delete Account';

  @override
  String get profileDeleteConfirm => 'Are you sure? This cannot be undone.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsPrivacy => 'Privacy & Data';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsLocationSharing => 'Location Sharing';

  @override
  String get settingsLocationEnabled => 'Location sharing enabled';

  @override
  String get settingsLocationDisabled => 'Location sharing disabled';

  @override
  String get settingsMobileData => 'Mobile Data Upload';

  @override
  String get settingsMobileDataEnabled => 'Upload on mobile data';

  @override
  String get settingsMobileDataDisabled => 'Upload on WiFi only';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get permissionLocationTitle => 'Location Permission';

  @override
  String get permissionLocationMessage =>
      'GreenGains needs location access to collect environmental data.';

  @override
  String get permissionLocationButton => 'Grant Permission';

  @override
  String get permissionBatteryTitle => 'Battery Optimization';

  @override
  String get permissionBatteryMessage =>
      'Please disable battery optimization for reliable background tracking.';

  @override
  String get permissionBatteryButton => 'Open Settings';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork => 'No internet connection';

  @override
  String get errorLocationUnavailable => 'Location unavailable';

  @override
  String get errorUploadFailed => 'Upload failed. Will retry later.';

  @override
  String get errorSignInRequired => 'Please sign in to continue';

  @override
  String get buttonOk => 'OK';

  @override
  String get buttonCancel => 'Cancel';

  @override
  String get buttonYes => 'Yes';

  @override
  String get buttonNo => 'No';

  @override
  String get buttonSave => 'Save';

  @override
  String get buttonDelete => 'Delete';

  @override
  String get buttonClose => 'Close';

  @override
  String get buttonRetry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get saving => 'Saving...';

  @override
  String get success => 'Success';

  @override
  String get error => 'Error';

  @override
  String get profileNotSignedIn => 'Not Signed In';

  @override
  String get profileSignInPrompt =>
      'Sign in with Google to track your streak and sync your contributions across devices.';

  @override
  String get profileAnonymousNote =>
      'Using anonymously. Sign in to track your streak.';

  @override
  String get profileUserFallback => 'User';

  @override
  String get profileViewStats => 'View Statistics';

  @override
  String get profileContributionsHint => 'Track your contributions';

  @override
  String get profileSignedOut => 'Signed out';

  @override
  String get chipContributing => 'Contributing';

  @override
  String get chipPaused => 'Paused';

  @override
  String get chipTapStart => 'Tap Start';

  @override
  String get uploadSuccessMessage => 'Contribution uploaded successfully!';

  @override
  String get semanticsRefreshMap => 'Refresh map data';

  @override
  String get semanticsToggleTracking => 'Toggle tracking';

  @override
  String get semanticsCenterOnMe => 'Center map on my location';

  @override
  String get tipViewLiveDataTitle => 'View live data';

  @override
  String get tipViewLiveDataMessage =>
      'Tap below to see what data you\'re contributing right now';

  @override
  String get statsScreenTitle => 'Statistics';

  @override
  String get statsToday => 'Today';

  @override
  String get statsStreak => 'Streak';

  @override
  String get statsDaysActive => 'Days Active';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsCoverage => 'Zones';

  @override
  String get statsTotalContributions => 'Total Contributions';

  @override
  String get statsKeepContributing => 'Keep contributing to track trends';

  @override
  String get statsActivityTrend => 'Activity Trend';

  @override
  String get statsLast7Days => 'Last 7 days';

  @override
  String get statsTodayLabel => 'TODAY';

  @override
  String get statsHistoryNote =>
      'Weekly history will appear once you have multiple days of data';

  @override
  String get statsContributionTimeline => 'Contribution Timeline';

  @override
  String get statsAchievements => 'Achievements';

  @override
  String get statsEarnings => 'Earnings';

  @override
  String get statsVisualizationNote =>
      'Visualization based on your current activity';

  @override
  String get statsAchievementsDescription =>
      'Unlock badges and milestones as you contribute';

  @override
  String get statsEarningsTracking => 'Earnings Tracking';

  @override
  String get statsEarningsDescription =>
      'Track your earnings and payout history once monetization begins';

  @override
  String get statsStartContributing => 'Start Contributing';

  @override
  String get statsEmptyDescription =>
      'Your statistics will appear here once you begin tracking';

  @override
  String get statsUpdatedPrefix => 'Updated ';

  @override
  String get statsDayMon => 'Mon';

  @override
  String get statsDayTue => 'Tue';

  @override
  String get statsDayWed => 'Wed';

  @override
  String get statsDayThu => 'Thu';

  @override
  String get statsDayFri => 'Fri';

  @override
  String get statsDaySat => 'Sat';

  @override
  String get statsDayToday => 'Today';

  @override
  String get mapLoadingText => 'Loading map...';

  @override
  String get mapComingSoonTitle => 'Coverage Heatmap Coming Soon';

  @override
  String get mapComingSoonDescription =>
      'Tile coverage visualization in progress';

  @override
  String get mapCenterTooltip => 'Center on location';

  @override
  String get yourContributions => 'YOUR CONTRIBUTIONS';

  @override
  String get impactCardContext => 'environmental readings — shared anonymously';

  @override
  String get loadingStatsLabel => 'Loading contribution stats';

  @override
  String get noContributionsYet =>
      'No contributions yet. Start tracking to begin.';

  @override
  String get startContributingTitle => 'Start contributing';

  @override
  String get startContributingHint =>
      'Your phone maps the city silently while you go about your day';

  @override
  String get areaCovered => 'Area covered';

  @override
  String get activeStreak => 'Active streak';

  @override
  String contributionStatsSemanticsLabel(
      String uploads, String area, String streak) {
    return 'Your contributions: $uploads. Area covered: $area. Active streak: $streak.';
  }

  @override
  String get chipZones => 'zones';

  @override
  String get tileInfoSamplesLabel => 'samples';

  @override
  String get tileInfoDevicesLabel => 'contributors';

  @override
  String get tileInfoPersonal => 'Personal';

  @override
  String get tileInfoCommunity => 'Community';

  @override
  String tileInfoSamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samples',
      one: '1 sample',
    );
    return '$_temp0';
  }

  @override
  String get tileInfoConfidence => 'Confidence';

  @override
  String tileInfoDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributors',
      one: '1 contributor',
    );
    return '$_temp0';
  }

  @override
  String get tileScanningNow => 'Scanning now';

  @override
  String get noCoverageYet => 'No coverage yet';

  @override
  String get startTrackingToMap => 'Start tracking to map your area';

  @override
  String tilesCount(int count) {
    return '$count tiles';
  }

  @override
  String get sensorLiveReadings => 'Live readings';

  @override
  String get sensorLiveSubtitle =>
      'See what data you\'re contributing right now';

  @override
  String get sensorInactiveTitle => 'Sensors inactive';

  @override
  String get sensorInactiveSubtitle =>
      'Start tracking above to begin collecting data';

  @override
  String get sensorPausedTitle => 'Sensors paused';

  @override
  String get sensorPausedSubtitle =>
      'Resume tracking to continue collecting data';

  @override
  String get sensorCollectingFirst => 'Collecting first readings…';

  @override
  String get sensorAroundYou => 'Around You';

  @override
  String get sensorMovement => 'Movement';

  @override
  String get sensorAcceleration => 'Acceleration';

  @override
  String get sensorLight => 'Light';

  @override
  String get sensorMagneticField => 'Magnetic Field';

  @override
  String get sensorOrientation => 'Orientation';

  @override
  String get sensorAirPressure => 'Air Pressure';

  @override
  String get sensorAccelerationIntensity => 'Acceleration intensity';

  @override
  String get sensorRotationSpeed => 'Rotation speed';

  @override
  String get sensorAtmosphericPressure => 'Atmospheric pressure';

  @override
  String get sensorStatusPaused => 'Paused';

  @override
  String get sensorStatusConnecting => 'Connecting…';

  @override
  String get sensorStatusLive => 'Live';

  @override
  String get lightDark => 'Dark';

  @override
  String get lightDim => 'Dim';

  @override
  String get lightNormal => 'Normal';

  @override
  String get lightBright => 'Bright';

  @override
  String get lightVeryBright => 'Very Bright';

  @override
  String get magnetVeryLow => 'Very low';

  @override
  String get magnetNormal => 'Normal';

  @override
  String get magnetElevated => 'Elevated';

  @override
  String get magnetHighNearMetal => 'High — near metal';

  @override
  String daysActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get trackingFabStarting => 'Starting…';

  @override
  String get trackingFabPause => 'Pause tracking';

  @override
  String get trackingFabResume => 'Resume tracking';

  @override
  String get trackingFabStart => 'Start tracking';

  @override
  String get trackingErrorUpdateFailed =>
      'Couldn\'t update tracking — please try again.';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeAuto => 'Auto';

  @override
  String get settingsLocationDescription =>
      'Enable location for coverage map and H3 tiles';

  @override
  String get settingsMobileDataDescription =>
      'Upload contributions over LTE/5G when needed';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsPrivacyPolicyDesc => 'How we handle your data';

  @override
  String get settingsTermsOfServiceDesc => 'Usage terms and conditions';

  @override
  String get settingsDataDeletion => 'Request Data Deletion';

  @override
  String get settingsDataDeletionDesc => 'Remove your contributions';

  @override
  String get settingsDataSection => 'Data';

  @override
  String settingsConsentDate(String date) {
    return 'Consented: $date';
  }

  @override
  String get settingsDataRetention => 'Retention: 7 days (Free)';

  @override
  String get onboardingDataCollectedTitle => 'What we collect';

  @override
  String get onboardingDataCollectedDescription =>
      'Light, motion, pressure and anonymous location — aggregated with 100,000+ devices before any analysis.';

  @override
  String get referralInviteTitle => 'Grow the network';

  @override
  String get referralInviteDescription =>
      'Invite contributors to expand coverage. More contributors means better data.';

  @override
  String get referralLinkCopied => 'Referral link copied';

  @override
  String get referralCopyLink => 'Copy link';

  @override
  String referralConversions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends joined',
      one: '1 friend joined',
      zero: 'No friends joined yet',
    );
    return '$_temp0';
  }

  @override
  String get tooltipRefresh => 'Refresh';

  @override
  String get tooltipDismiss => 'Dismiss';

  @override
  String get statsFailedToLoad => 'Failed to load stats';

  @override
  String get statsReadyToContribute => 'Ready to contribute?';

  @override
  String get statsFirstContributionHint =>
      'Start tracking to make your first contribution';

  @override
  String get statsDayStreak => 'Day Streak';

  @override
  String get offlineBannerMessage => 'No connection · data queued locally';

  @override
  String get statsWeeklyLabel => '7 DAYS';

  @override
  String statsWeeklyTotal(int count) {
    return '$count this week';
  }

  @override
  String get statsMilestoneLabel => 'Next reward';

  @override
  String get statsMilestoneHint =>
      'Rewards unlock when you reach this milestone — keep contributing';

  @override
  String get statsMilestoneElite =>
      'Elite contributor · all milestones reached';

  @override
  String statsCommunityAreas(int count) {
    return '$count areas mapped by community';
  }

  @override
  String get batteryDialogTitle => 'Maximize Your Impact';

  @override
  String get batteryDialogBody =>
      'To contribute 24/7, GreenGains needs to run in the background without being killed by the system.';

  @override
  String get batteryDialogBodyBold =>
      'Please disable \"Battery Optimization\" for GreenGains in the next screen.';

  @override
  String get batteryDialogDismissForever => 'Don\'t show again';

  @override
  String get batteryDialogLater => 'Later';

  @override
  String get batteryDialogAllow => 'Allow Background Run';

  @override
  String get batteryDialogError => 'Unable to open battery settings';

  @override
  String get locationPermBannerBody =>
      'Set to \'Allow all the time\' for 24/7 collection';

  @override
  String get locationPermBannerFix => 'Fix';

  @override
  String get legendYou => 'You';

  @override
  String get legendCommunity => 'Community';

  @override
  String get referralStepShare => 'Share';

  @override
  String get referralStepJoin => 'They join';

  @override
  String get referralStepEarn => 'You earn';

  @override
  String get settingsDiagnostics => 'Sensor Diagnostics';

  @override
  String get settingsDiagnosticsDesc =>
      'Live readings from your device sensors';
}
