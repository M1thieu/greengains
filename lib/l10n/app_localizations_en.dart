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
      'Your phone quietly reads light, pressure, and movement as you move. No interaction needed — you walk, it maps.';

  @override
  String get onboardingFeature1Title => 'Runs silently';

  @override
  String get onboardingFeature1Description =>
      'Works in the background while you commute, walk, or sleep. No tapping, no setup — ever again.';

  @override
  String get onboardingFeature2Title => 'Anonymized by design';

  @override
  String get onboardingFeature2Description =>
      'Your data is bundled with thousands of others before it ever leaves your device. No location history, no personal data — ever.';

  @override
  String get onboardingFeature3Title => 'Real data, real impact';

  @override
  String get onboardingFeature3Description =>
      'Your walks appear on a live city map used by researchers and planners. Every street you cover adds data that never existed before.';

  @override
  String get onboardingSignInTitle => 'Join the network';

  @override
  String get onboardingSignInSubtitle =>
      'Sign in once — your coverage map and progress follow you everywhere.';

  @override
  String get onboardingCloudSync => 'Live Coverage Map';

  @override
  String get onboardingCloudSyncDescription =>
      'Watch your personal coverage area grow in real time';

  @override
  String get onboardingFutureFeatures => 'Coming Soon';

  @override
  String get onboardingFutureDescription =>
      'Contributor milestones, impact reports, and more';

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
      'Allow location to start mapping your city.';

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
      'Sign in with Google to keep your streak and sync your map across devices.';

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
  String get chipContributing => 'Mapping';

  @override
  String get chipPaused => 'Paused';

  @override
  String get chipTapStart => 'Tap ▶ to start';

  @override
  String get homeFirstUseHint => 'Maps your city silently while you move';

  @override
  String get uploadSuccessMessage => 'Map updated!';

  @override
  String uploadSuccessNewZone(int count) {
    return 'New area · $count zones on your map';
  }

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
  String statsStreakBest(int days) {
    return 'BEST ${days}D';
  }

  @override
  String get statsDaysActive => 'Days Active';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsCoverage => 'Zones';

  @override
  String get statsAreasLabel => 'areas mapped';

  @override
  String get statsDataPtsLabel => 'uploads';

  @override
  String get statsKmMapped => 'km² mapped';

  @override
  String get statsBestDay => 'best day';

  @override
  String get statsStreakLabel => 'streak';

  @override
  String get statsRecordStreak => 'record';

  @override
  String statsBarCalloutUploads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uploads',
      one: '1 upload',
    );
    return '$_temp0';
  }

  @override
  String get statsBarCalloutToday => 'Today';

  @override
  String get statsBarCalloutBest => 'Best day';

  @override
  String get infoKmTitle => 'Territory mapped';

  @override
  String get infoKmBody =>
      'Each hexagon on your map covers about 0.1 km². This shows how much of your city you have personally mapped so far.';

  @override
  String get infoDataPtsTitle => 'Uploads';

  @override
  String get infoDataPtsBody =>
      'Each upload records light, pressure, and movement as you move. More uploads = more detail on your map.';

  @override
  String get infoDaysActiveTitle => 'Days active';

  @override
  String get infoDaysActiveBody =>
      'The number of days you were active. No need to be active every day.';

  @override
  String get infoBestDayTitle => 'Best day';

  @override
  String get infoBestDayBody =>
      'Your most active day this week, measured by data points uploaded. A higher number usually means more time outdoors.';

  @override
  String get infoMilestoneTitle => 'Next milestone';

  @override
  String get infoMilestoneBody =>
      'Milestones track your territory growth. Each new hexagon you map counts toward the next level.';

  @override
  String get infoTileQualityTitle => 'Coverage quality';

  @override
  String get infoTileQualityBody =>
      'Quality reflects how many sensor readings were collected in this area and how consistent they are. Green = solid data, yellow = partial, red = sparse.';

  @override
  String get infoTilePersonalTitle => 'Your area';

  @override
  String get infoTilePersonalBody =>
      'You mapped this area. Your phone recorded here during your travels.';

  @override
  String get infoTileCommunityTitle => 'Community area';

  @override
  String get infoTileCommunityBody =>
      'This area was mapped by other users. Together you\'re building a city-wide map.';

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
  String get statsStartContributing => 'Nothing here yet';

  @override
  String get statsEmptyDescription =>
      'Head to the map and tap ▶ — your stats will appear after your first upload.';

  @override
  String get statsEmptyGoMap => 'Go to map';

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
  String get yourContributions => 'YOUR UPLOADS';

  @override
  String get impactCardContext => 'uploads — shared anonymously';

  @override
  String get loadingStatsLabel => 'Loading your stats';

  @override
  String get noContributionsYet =>
      'Nothing recorded yet. Start tracking to begin.';

  @override
  String get startContributingTitle => 'Start mapping';

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
  String get chipSensors => 'signals';

  @override
  String homeZonesMapped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones mapped',
      one: '1 zone mapped',
    );
    return '$_temp0';
  }

  @override
  String get tileInfoSamplesLabel => 'samples';

  @override
  String get tileInfoDevicesLabel => 'contributors';

  @override
  String get tileInfoQualityLabel => 'Data quality';

  @override
  String get tileInfoAreaLabel => 'area';

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
  String get tileInfoQuality => 'Air quality';

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
  String get sensorInactiveTitle => 'Not recording';

  @override
  String get sensorInactiveSubtitle => 'Start tracking to begin recording';

  @override
  String get sensorPausedTitle => 'Recording paused';

  @override
  String get sensorPausedSubtitle => 'Resume tracking to keep recording';

  @override
  String get sensorCollectingFirst => 'Starting up…';

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
      'Required for the live coverage map';

  @override
  String get settingsMobileDataDescription => 'Upload over LTE/5G when needed';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsPrivacyPolicyDesc => 'How we handle your data';

  @override
  String get settingsTermsOfServiceDesc => 'Usage terms and conditions';

  @override
  String get settingsDataDeletion => 'Request Data Deletion';

  @override
  String get settingsDataDeletionDesc => 'Erase all your recorded data';

  @override
  String get settingsDataSection => 'Data';

  @override
  String settingsConsentDate(String date) {
    return 'Consented: $date';
  }

  @override
  String get settingsDataRetention => 'Data kept for 7 days (Free)';

  @override
  String get onboardingDataCollectedTitle => 'What we collect';

  @override
  String get onboardingDataCollectedDescription =>
      'Light, motion, pressure and anonymous location — aggregated with 100,000+ devices before any analysis.';

  @override
  String get referralInviteTitle => 'Invite friends';

  @override
  String get referralInviteDescription =>
      'Invite friends to map more of your city. Every person adds streets you haven\'t walked yet.';

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
  String statsMilestoneRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count areas to go',
      one: '1 area to go',
    );
    return '$_temp0';
  }

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
      'Set to \'Allow all the time\' to map in the background';

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
  String get referralStepEarn => 'Map grows';

  @override
  String get settingsDiagnostics => 'Sensor Diagnostics';

  @override
  String get settingsDiagnosticsDesc =>
      'Live readings from your device sensors';

  @override
  String get sensorLiveSheetTitle => 'What you\'re measuring';

  @override
  String get tileQualityExcellent => 'Excellent coverage — well recorded';

  @override
  String get tileQualityGood => 'Good data — useful but room to grow';

  @override
  String get tileQualityFair => 'Sparse data — more passes needed';

  @override
  String get tileMeasuredWith => 'Sensors active';

  @override
  String get legendHighLabel => 'High quality';

  @override
  String get legendHighSub => '≥75% valid sensor readings';

  @override
  String get legendMidLabel => 'Medium quality';

  @override
  String get legendMidSub => '50–74% valid readings';

  @override
  String get legendLowLabel => 'Low quality';

  @override
  String get legendLowSub => 'Below 50% — needs more data';

  @override
  String get legendCommunitySub => 'Mapped by other contributors';

  @override
  String get permissionPrimingTitle => 'One thing before we start';

  @override
  String get permissionPrimingBattery =>
      'Less than 1% battery per hour — same as a weather app';

  @override
  String get permissionPrimingCollects =>
      'We collect ambient light, pressure and motion — never your identity';

  @override
  String get permissionPrimingCta => 'Enable location';

  @override
  String get firstStartTitle => 'You\'re live';

  @override
  String get firstStartBody =>
      'Walk, commute, live normally — your first zone will appear on the map soon';

  @override
  String get alwaysOnBannerBody =>
      'Set location to \'Always\' to keep mapping in the background';

  @override
  String get alwaysOnBannerFix => 'Fix';

  @override
  String milestoneReachedTitle(int count) {
    return '$count zones mapped';
  }

  @override
  String get milestoneReachedBody =>
      'You\'re building a real map of your city. Keep going.';

  @override
  String get milestoneReachedCta => 'Keep mapping';

  @override
  String get firstUploadTitle => 'Your first zone is on the map!';

  @override
  String get firstUploadBody =>
      'Your phone just recorded its first area. Walk more and watch your map grow.';

  @override
  String get firstUploadCta => 'See my map';

  @override
  String onboardingSocialProof(int count) {
    return '$count people already mapping their cities';
  }

  @override
  String uploadMilestone(int count) {
    return '$count uploads — keep going!';
  }
}
