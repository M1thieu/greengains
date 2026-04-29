// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get onboardingWelcomeTitle => 'Finally know your neighborhood.';

  @override
  String get onboardingWelcomeSubtitle =>
      'Your phone reads light, pressure, and motion as you walk — and builds a map of everywhere you\'ve been.';

  @override
  String get onboardingFeature1Title => 'Nothing to do.';

  @override
  String get onboardingFeature1Description =>
      'Start once, carry your phone. That\'s it — your map builds itself.';

  @override
  String get onboardingFeature2Title => 'Private by default';

  @override
  String get onboardingFeature2Description =>
      'Your route is never stored — readings are anonymized before they leave your phone.';

  @override
  String get onboardingFeature3Title => 'See how far you\'ve been.';

  @override
  String get onboardingFeature3Description =>
      'Every place you visit shows up on your map. Walk the same streets, watch them fill in.';

  @override
  String get onboardingSignInTitle => 'Your map starts here.';

  @override
  String get onboardingSignInSubtitle =>
      'Sign in to keep your map synced across devices.';

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
  String get statsTitle => 'Your Map';

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
  String get settingsLocationSharing => 'Location Sharing';

  @override
  String get settingsMobileData => 'Mobile Data Upload';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get permissionLocationTitle => 'Location Permission';

  @override
  String get permissionLocationMessage =>
      'Allow location so your phone can map as you walk.';

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
      'Sign in with Google to keep your map synced across devices.';

  @override
  String get profileAnonymousNote =>
      'Using anonymously. Sign in to save your map.';

  @override
  String get profileUserFallback => 'User';

  @override
  String get profileViewStats => 'View Statistics';

  @override
  String get profileContributionsHint => 'See your map';

  @override
  String get profileSignedOut => 'Signed out';

  @override
  String get chipContributing => 'Mapping';

  @override
  String get chipPaused => 'Paused';

  @override
  String get chipTapStart => 'Tap ▶ to start mapping';

  @override
  String chipDataPts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pts',
      one: '1 pt',
    );
    return '$_temp0';
  }

  @override
  String homeSessionZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count zones',
      one: '+1 zone',
      zero: 'Mapping',
    );
    return '$_temp0';
  }

  @override
  String get homeYourMap => 'YOUR MAP';

  @override
  String homeCityPct(String pct) {
    return '$pct% of city filled';
  }

  @override
  String get profileImpactSection => 'YOUR MAP';

  @override
  String get profileAccountSection => 'ACCOUNT';

  @override
  String get homeFirstUseHint =>
      'Tap ▶ — watch your first zone appear on the map';

  @override
  String get homeFirstTrackingHint =>
      'Scanning light, pressure and motion — first zone after first upload';

  @override
  String homeTrackingReadings(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString readings captured',
      one: '1 reading captured',
    );
    return '$_temp0';
  }

  @override
  String homeReturnHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones on your map — tap ▶ to keep growing',
      one: '1 zone on your map — tap ▶ to keep growing',
    );
    return '$_temp0';
  }

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
  String get statsThisWeek => 'This week';

  @override
  String get statsDaysActive => 'Days Active';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsCoverage => 'Zones';

  @override
  String get statsAreasLabel => 'zones mapped';

  @override
  String get statsDataPtsLabel => 'recordings';

  @override
  String get statsKmMapped => 'km² mapped';

  @override
  String get statsBestDay => 'Best day';

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
      'Each hexagon covers ~0.1 km² — this is your personal footprint on the map.';

  @override
  String get infoDataPtsTitle => 'Uploads';

  @override
  String get infoDataPtsBody =>
      'Each upload captures light, pressure, and movement — more uploads means a denser map.';

  @override
  String get infoTodayTitle => 'Recordings today';

  @override
  String get infoTodayBody =>
      'Sensor readings uploaded today — light, pressure, and movement at each stop.';

  @override
  String get infoThisWeekTitle => 'This week';

  @override
  String get infoThisWeekBody =>
      'Recordings over the last 7 days — consistency builds richer map data.';

  @override
  String get infoDaysActiveTitle => 'Days active';

  @override
  String get infoDaysActiveBody =>
      'Days you contributed — no need to be active every day.';

  @override
  String get infoBestDayTitle => 'Best day';

  @override
  String get infoBestDayBody =>
      'Your most active day this week — usually means more time outdoors.';

  @override
  String get infoMilestoneTitle => 'Next milestone';

  @override
  String get infoMilestoneBody =>
      'Each new area you map counts toward the next milestone.';

  @override
  String get infoTileQualityTitle => 'Coverage quality';

  @override
  String get infoTileQualityBody =>
      'Green = well covered, yellow = partial, red = needs more passes.';

  @override
  String get infoTilePersonalTitle => 'Your area';

  @override
  String get infoTilePersonalBody => 'Your phone recorded here.';

  @override
  String get infoTileCommunityTitle => 'Community area';

  @override
  String get infoTileCommunityBody =>
      'Mapped by others — walk here to make it yours.';

  @override
  String get statsTotalContributions => 'Total Contributions';

  @override
  String get statsActivityTrend => 'Your week';

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
  String get statsAchievements => '';

  @override
  String get statsEarnings => '';

  @override
  String get statsVisualizationNote => '';

  @override
  String get statsAchievementsDescription => '';

  @override
  String get statsEarningsTracking => '';

  @override
  String get statsEarningsDescription => '';

  @override
  String get statsStartContributing => 'Your map is blank.';

  @override
  String get statsEmptyDescription =>
      'Tap ▶. Your first zone is waiting to be mapped.';

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
  String get mapCenterTooltip => 'Center on location';

  @override
  String get yourContributions => 'YOUR TERRITORY';

  @override
  String get impactCardContext => 'zones mapped';

  @override
  String get loadingStatsLabel => 'Loading your stats';

  @override
  String get noContributionsYet => 'Nothing recorded yet — tap ▶ to start.';

  @override
  String get startContributingTitle => 'Start mapping';

  @override
  String get startContributingHint =>
      'Your phone maps your world silently while you go about your day';

  @override
  String get areaCovered => 'Area covered';

  @override
  String get activeStreak => 'Territory';

  @override
  String contributionStatsSemanticsLabel(String uploads, String area) {
    return 'Your contributions: $uploads. Area covered: $area.';
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
  String get tileInfoSamplesLabel => 'readings';

  @override
  String get tileInfoDevicesLabel => 'people';

  @override
  String get tileInfoQualityLabel => 'Coverage';

  @override
  String get tileInfoAreaLabel => 'area';

  @override
  String get tileInfoPersonal => 'Yours';

  @override
  String get tileInfoCommunity => 'Not yours yet';

  @override
  String get tileOnlyYouMapped => 'Only you\'ve been here';

  @override
  String get tickerMotionStill => 'still';

  @override
  String get tickerMotionMoving => 'moving';

  @override
  String get tickerMotionActive => 'active';

  @override
  String tileInfoSamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count readings',
      one: '1 reading',
    );
    return '$_temp0';
  }

  @override
  String get tileInfoConfidence => 'Confidence';

  @override
  String get tileInfoQuality => 'Coverage quality';

  @override
  String tileInfoDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
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
  String get sensorLiveSubtitle => 'Real-time sensor readings from your phone.';

  @override
  String get sensorInactiveTitle => 'Not recording';

  @override
  String get sensorInactiveSubtitle => 'Start tracking to see live readings.';

  @override
  String get sensorPausedTitle => 'Recording paused';

  @override
  String get sensorPausedSubtitle => 'Resume to see live readings.';

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
  String get referralInviteTitle => 'Invite friends';

  @override
  String get referralInviteDescription =>
      'Every friend maps places you haven\'t been yet.';

  @override
  String get referralLinkCopied => 'Link copied';

  @override
  String get referralCopyLink => 'Copy link';

  @override
  String get referralShareLink => 'Share';

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
  String get statsHighlightsLabel => 'HIGHLIGHTS';

  @override
  String get statsMappingSince => 'Mapping since';

  @override
  String get statsFailedToLoad => 'Failed to load stats';

  @override
  String get statsReadyToContribute => 'Start walking to build your map.';

  @override
  String get statsFirstContributionHint =>
      'Start tracking to map your first area';

  @override
  String get statsWeeklyLabel => '7 DAYS';

  @override
  String statsWeeklyTotal(int count) {
    return '$count this week';
  }

  @override
  String get statsMilestoneLabel => 'Next level';

  @override
  String get statsMilestoneHint =>
      'Map enough zones to reach this level and unlock the next one';

  @override
  String get statsMilestoneElite => 'Fully mapped · explorer status';

  @override
  String statsMilestoneRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones to go',
      one: '1 zone to go',
    );
    return '$_temp0';
  }

  @override
  String statsCommunityAreas(int count) {
    return '$count areas mapped by community';
  }

  @override
  String get batteryDialogTitle => 'Keep mapping';

  @override
  String get batteryDialogBody =>
      'Disable battery optimization so the app keeps mapping in the background.';

  @override
  String get batteryDialogBodyBold =>
      'Disable \"Battery Optimization\" for GreenGains on the next screen.';

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
  String get tileQualityExcellent => 'Well covered';

  @override
  String get tileQualityGood => 'Good coverage';

  @override
  String get tileQualityFair => 'Pass here again';

  @override
  String get tileMeasuredWith => 'Recorded with';

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
  String get legendCommunitySub => 'Recorded by other people';

  @override
  String get permissionPrimingTitle => 'One thing before we start';

  @override
  String get permissionPrimingBattery => 'Smart battery';

  @override
  String get permissionPrimingBatteryDesc =>
      'Less than 1% per hour — adapts automatically in background';

  @override
  String get permissionPrimingCollects => 'Private by design';

  @override
  String get permissionPrimingCollectsDesc =>
      'Light, pressure and motion only — never your route or identity';

  @override
  String get permissionPrimingCta => 'Enable location';

  @override
  String get settingsBatteryMode => 'Smart battery';

  @override
  String get settingsBatteryModeDesc =>
      'Quiet when still, precise when moving — adapts automatically';

  @override
  String get firstStartTitle => 'Building your map.';

  @override
  String get firstStartBody => 'Move — zones appear as you go.';

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
  String get milestoneReachedBody => 'How far can you go?';

  @override
  String get milestoneReachedCta => 'Keep going';

  @override
  String get firstUploadTitle => 'First area mapped.';

  @override
  String get firstUploadBody => 'Keep moving — your map is growing.';

  @override
  String get firstUploadCta => 'See my map';

  @override
  String onboardingSocialProof(int count) {
    return '$count people already mapping their neighborhood';
  }

  @override
  String sessionSummaryZonesClaimed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'zones mapped',
      one: 'zone mapped',
    );
    return '$_temp0';
  }

  @override
  String sessionSummaryTotal(int zones, String km2) {
    return 'Total: $zones zones · $km2 km²';
  }

  @override
  String get sessionSummaryCta => 'See my map';

  @override
  String get sessionSummaryDone => 'Done';

  @override
  String get statsMapGrowing => 'map growing — keep walking';

  @override
  String get statsWeeklyChartOffline => 'Weekly chart loads once connected';

  @override
  String uploadMilestone(int count) {
    return '$count uploads — keep going!';
  }

  @override
  String get statsViewOnMap => 'View on map';

  @override
  String statsCommunityMappers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people mapping this month',
      one: '1 person mapping this month',
    );
    return '$_temp0';
  }

  @override
  String tileFirstMapped(String date) {
    return 'First mapped $date';
  }

  @override
  String statsSinceDate(String date) {
    return 'since $date';
  }

  @override
  String get statsStreakLabel => 'Streak';

  @override
  String statsStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days in a row',
      one: '1 day in a row',
    );
    return '$_temp0';
  }

  @override
  String get tileCommunityClaimCta => 'Walk through here to make it yours';

  @override
  String get tileLowQualityHint =>
      'Walk here again — more passes = stronger data.';

  @override
  String homeSinceLastSession(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count zones since last time',
      one: '+1 zone since last time',
    );
    return '$_temp0';
  }

  @override
  String homeZonesOnYourMap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones on your map',
      one: '1 zone on your map',
    );
    return '$_temp0';
  }

  @override
  String homeCommunityScopeHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones mapped in your area',
      one: '1 zone mapped in your area',
    );
    return '$_temp0';
  }

  @override
  String get tileCivicNote => 'You measured this.';

  @override
  String sessionSummaryShareText(int gained, int total, String km2) {
    return 'I mapped +$gained zones today — $total zones total · $km2 km²';
  }

  @override
  String sensorLuxLabel(int lux) {
    return '$lux lux';
  }

  @override
  String sensorHpaLabel(String hpa) {
    return '$hpa hPa';
  }

  @override
  String sensorMovementLabel(String val) {
    return '$val';
  }

  @override
  String get sensorLuxDark => 'Dark';

  @override
  String get sensorLuxIndoor => 'Indoors';

  @override
  String get sensorLuxBright => 'Bright';

  @override
  String get sensorLuxDirect => 'Full sun';

  @override
  String get sensorMovementLow => 'Quiet';

  @override
  String get sensorMovementMid => 'Active';

  @override
  String get sensorMovementHigh => 'Busy';

  @override
  String get sensorHpaLow => 'Fair';

  @override
  String get sensorHpaMid => 'Mixed';

  @override
  String get sensorHpaHigh => 'Unsettled';

  @override
  String get tileSensorInsightsLabel => 'Conditions recorded here';

  @override
  String territoryHeroLabel(String neighborhood, int count) {
    return '$neighborhood · $count zones';
  }

  @override
  String get serverWakingUp => 'Starting up — hang tight…';

  @override
  String referralNeighborhoodHook(String neighborhood) {
    return 'Help map $neighborhood — every neighbor fills in what you haven\'t reached.';
  }

  @override
  String get onboardingActivateTitle => 'Almost there';

  @override
  String get onboardingActivateSubtitle =>
      'Allow location access — your phone maps as you move.';

  @override
  String get onboardingActivateCta => 'Start mapping';

  @override
  String homeMaxClusterHint(int count) {
    return 'biggest area: $count zones';
  }

  @override
  String get firstUploadBadge => 'FIRST ZONE UPLOADED';

  @override
  String get firstUploadHeadline => 'Your first zone is on the map.';

  @override
  String get firstUploadSubtext =>
      'Light, pressure and motion — recorded, anonymised, and added to the map.';

  @override
  String get firstUploadSensorsLabel => 'SENSORS';

  @override
  String get firstUploadSensorsValue => 'light · motion · pressure';

  @override
  String get firstUploadPrivacyLabel => 'PRIVACY';

  @override
  String get firstUploadPrivacyValue => 'anonymised';

  @override
  String get firstUploadKeepMappingCta => 'Keep mapping';

  @override
  String get liveSensorsHeader => 'LIVE SENSORS';

  @override
  String get liveSensorMotionLabel => 'Motion';

  @override
  String get liveSensorPressureLabel => 'Pressure';

  @override
  String get sessionSummaryBadge => 'WALK DONE';

  @override
  String get sessionSummaryZonesGainedLabel => 'NEW ZONES';

  @override
  String get sessionSummarySubline => 'added to your map';

  @override
  String get sessionSummaryWatermark => 'Mapped with GreenGains';

  @override
  String get sessionSummaryShareCta => 'Share';

  @override
  String get sessionSummaryNextHook =>
      'Come back tomorrow to keep your streak.';

  @override
  String get sessionSummaryNextHookEmpty =>
      'Walk more next time — zones fill in as you move.';

  @override
  String get sessionStatArea => 'AREA';

  @override
  String get sessionStatDuration => 'TIME';

  @override
  String get sessionStatTotal => 'TOTAL';

  @override
  String statsMilestoneTarget(int target) {
    return '$target zones';
  }
}
