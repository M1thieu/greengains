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
      'Your phone reads light levels, air pressure, and movement as you go. See what your usual routes are actually like.';

  @override
  String get onboardingFeature1Title => 'Nothing to do.';

  @override
  String get onboardingFeature1Description =>
      'Start once, carry your phone. Your map builds itself.';

  @override
  String get onboardingFeature2Title => 'Private by default';

  @override
  String get onboardingFeature2Description =>
      'Your route is never stored. Readings are anonymous before they leave your phone.';

  @override
  String get onboardingFeature3Title => 'See what\'s around you.';

  @override
  String get onboardingFeature3Description =>
      'Light levels, air pressure, road conditions — the invisible environment you move through every day.';

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
  String get homeIdleTagline => 'See what your routes expose you to';

  @override
  String get homeIdleSubtitle =>
      'Leave it on. Light, heat, surface — all passive.';

  @override
  String homeStatPlaces(int count) {
    return '$count places';
  }

  @override
  String homeStatArea(String area) {
    return '$area mapped';
  }

  @override
  String homeStatStreak(int count) {
    return '$count-day streak';
  }

  @override
  String get homeActionStart => 'Start';

  @override
  String get homeActionStop => 'Stop';

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
  String profileLastMapped(String ago) {
    return 'Last mapped $ago';
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
  String get settingsDisplay => 'Display';

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
  String get errorUploadFailed => 'Couldn\'t sync. Will retry later.';

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
  String get profileUserFallback => 'User';

  @override
  String get chipContributing => 'Mapping';

  @override
  String get chipPaused => 'Paused';

  @override
  String get chipTapStart => 'Tap ▶ to start mapping';

  @override
  String get chipTapStartFirst => 'Start mapping your neighborhood';

  @override
  String chipDataPts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scans',
      one: '1 scan',
    );
    return '$_temp0';
  }

  @override
  String homeSessionZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count new places',
      one: '+1 new place',
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
  String get homeFirstUseHint =>
      'Tap ▶ to watch your first place appear on the map';

  @override
  String get homeFirstTrackingHint =>
      'Reading light, heat and surface conditions. First zone appears after upload.';

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
      other: '$count places on your map. Tap ▶ to explore more',
      one: '1 place on your map. Tap ▶ to explore more',
    );
    return '$_temp0';
  }

  @override
  String get uploadSuccessMessage => 'Map updated!';

  @override
  String uploadSuccessNewZone(int count) {
    return 'New place added · $count on your map';
  }

  @override
  String get semanticsRefreshMap => 'Refresh map data';

  @override
  String get semanticsToggleTracking => 'Toggle tracking';

  @override
  String get semanticsCenterOnMe => 'Center map on my location';

  @override
  String semanticsZoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places: view stats',
      one: '1 place: view stats',
    );
    return '$_temp0';
  }

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
  String get statsCoverage => 'Places';

  @override
  String get statsAreasLabel => 'places covered';

  @override
  String get statsDataPtsLabel => 'data points';

  @override
  String get statsKmMapped => 'km² covered';

  @override
  String statsBarCalloutUploads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scans',
      one: '1 scan',
    );
    return '$_temp0';
  }

  @override
  String get statsBarCalloutToday => 'Today';

  @override
  String get statsBarCalloutBest => 'Best day';

  @override
  String get statsBestDayLabel => 'Best day';

  @override
  String get statsAvgPerDay => 'Avg. per day';

  @override
  String get statsVerdictStrong => 'Strong week';

  @override
  String get statsVerdictGood => 'Good week';

  @override
  String get statsVerdictSlow => 'Slow week';

  @override
  String get statsVerdictNone => 'No data yet';

  @override
  String statsVerdictSubStrong(int days) {
    return 'Active $days of 7 days this week.';
  }

  @override
  String statsVerdictSubGood(int days) {
    return 'Active $days of 7 days this week.';
  }

  @override
  String statsVerdictSubSlow(int days) {
    return 'Active $days day this week.';
  }

  @override
  String get statsVerdictSubNone => 'Enable tracking and go about your day.';

  @override
  String get statsWeeklyTargetLabel => 'THIS WEEK';

  @override
  String get statsWeeklyTargetComplete => 'Goal reached';

  @override
  String get statsLocalLegendLabel => 'LOCAL LEGEND';

  @override
  String get statsLocalLegendLeader => 'Top mapper in your area this week';

  @override
  String statsLocalLegendRank(int rank, int total) {
    return '#$rank of $total nearby this week';
  }

  @override
  String statsLocalLegendGap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones to take the lead',
      one: '1 zone to take the lead',
    );
    return '$_temp0';
  }

  @override
  String get statsImpactLabel => 'YOUR IMPACT';

  @override
  String statsImpactSolo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Only you have ever mapped $count of your zones',
      one: 'Only you have ever mapped 1 of your zones',
    );
    return '$_temp0';
  }

  @override
  String statsWeeklyTargetRemaining(int count) {
    return '$count more';
  }

  @override
  String get statsDetailTitle => 'Your data';

  @override
  String statsCityBlocks(int count) {
    return '~$count city blocks covered';
  }

  @override
  String get statsPersonalRecords => 'Personal records';

  @override
  String get statsRecordBestDay => 'Best day';

  @override
  String get statsRecordLongestStreak => 'Longest streak';

  @override
  String get statsRecordTotalUploads => 'Total scans';

  @override
  String get statsRecordFirstDay => 'First mapping day';

  @override
  String get statsZoneExplainer =>
      'A zone is roughly one city block — recorded as you passed through.';

  @override
  String get statsUploadExplainer =>
      'Light, heat and surface quality captured at that moment.';

  @override
  String get statsTabCore => 'Overview';

  @override
  String get statsTabInDepth => 'In depth';

  @override
  String get statsInDepth30Days => 'Last 30 days';

  @override
  String get statsHeatmapLess => 'less';

  @override
  String get statsHeatmapMore => 'more';

  @override
  String statsHeatmapDayDetail(String date, int count) {
    return '$date · $count passes';
  }

  @override
  String statsHeatmapNoUploads(String date) {
    return '$date · no uploads';
  }

  @override
  String get statsInDepthHabits => 'Your habits';

  @override
  String get statsInDepthActiveDays => 'Active days';

  @override
  String get statsInDepthAvgPerDay => 'Avg / active day';

  @override
  String get statsInDepthBestWeekday => 'Best weekday';

  @override
  String get statsDaysUnit => 'days';

  @override
  String get statsCurrentStreakLabel => 'Current streak';

  @override
  String get statsLongestLabel => 'Longest';

  @override
  String get statsAllTimeSection => 'ALL TIME';

  @override
  String get statsUploadsUnit => 'scans';

  @override
  String get statsBestWeekLabel => 'Best week';

  @override
  String get statsQualitySection => 'SIGNAL QUALITY';

  @override
  String get statsQualityExcellent => 'Excellent';

  @override
  String get statsQualityGood => 'Good';

  @override
  String get statsQualityFair => 'Fair';

  @override
  String get statsQualityLow => 'Low';

  @override
  String get statsQualitySubtitle =>
      'How clean your readings are: strong signal, fewer gaps';

  @override
  String get statsAvgPrefix => 'avg';

  @override
  String get infoKmTitle => 'Territory mapped';

  @override
  String get infoKmBody =>
      'Each zone is roughly a city block. This is how much of your area has been recorded.';

  @override
  String get infoDataPtsTitle => 'Places mapped';

  @override
  String get infoDataPtsBody =>
      'Each pass records what that spot is like. More passes means more accuracy.';

  @override
  String get infoTodayTitle => 'Today';

  @override
  String get infoTodayBody =>
      'Light, weather, and movement captured today at each stop.';

  @override
  String get infoThisWeekTitle => 'This week';

  @override
  String get infoThisWeekBody => 'Recordings over the last 7 days.';

  @override
  String get infoDaysActiveTitle => 'Days active';

  @override
  String get infoDaysActiveBody =>
      'Days your phone was active. No need to go out every day.';

  @override
  String get infoBestDayTitle => 'Best day';

  @override
  String get infoBestDayBody =>
      'Your most active day this week. Usually means more time outdoors.';

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
      'Mapped by others. Walk here to make it yours.';

  @override
  String get statsTotalContributions => 'Times you\'ve mapped';

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
  String get statsStartContributing => 'No data yet.';

  @override
  String get statsEmptyDescription =>
      'Enable tracking once. Light, heat and surface quality are recorded silently.';

  @override
  String get statsEmptyGoMap => 'Enable tracking';

  @override
  String get statsEmptyUnlockHint => 'Walk to unlock';

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
  String get impactCardContext => 'places mapped';

  @override
  String get loadingStatsLabel => 'Loading your stats';

  @override
  String get noContributionsYet => 'Nothing recorded yet. Tap ▶ to start.';

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
  String get chipZones => 'places';

  @override
  String get chipSensors => 'signals';

  @override
  String homeZonesMapped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places on your map',
      one: '1 place on your map',
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
  String get tileInfoNoSensorData =>
      'Location only. No sensor readings for this spot.';

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
  String get sensorLiveReadings => 'What\'s around you';

  @override
  String get sensorLiveSubtitle =>
      'Light, movement and air pressure, live from your phone.';

  @override
  String get sensorInactiveTitle => 'Not recording';

  @override
  String get sensorInactiveSubtitle => 'Enable tracking to see live readings.';

  @override
  String get sensorPausedTitle => 'Recording paused';

  @override
  String get sensorPausedSubtitle => 'Resume to see live readings.';

  @override
  String get sensorCollectingFirst => 'Reading…';

  @override
  String get sensorAroundYou => 'Around You';

  @override
  String get sensorPressure => 'Pressure';

  @override
  String get sensorUnitLux => 'lx';

  @override
  String get sensorUnitHpa => 'hPa';

  @override
  String get sensorUnitMovement => 'm/s²';

  @override
  String get sensorUnitVibration => '%';

  @override
  String get sensorMovement => 'Movement';

  @override
  String get sensorAcceleration => 'Acceleration';

  @override
  String get sensorLight => 'Light';

  @override
  String get sensorMagneticField => 'Interference';

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
  String get sensorStatusLastReading => 'Last reading';

  @override
  String get sensorStatusNoData => 'No data';

  @override
  String get lightDark => 'Dark sky';

  @override
  String get lightDim => 'Dim';

  @override
  String get lightNormal => 'Normal';

  @override
  String get lightBright => 'Bright';

  @override
  String get lightVeryBright => 'Very Bright';

  @override
  String get lightDarkHint => 'Minimal artificial light';

  @override
  String get lightDimHint => 'Low ambient light';

  @override
  String get lightNormalHint => 'Typical indoor daylight';

  @override
  String get lightBrightHint => 'Near a window or outdoors';

  @override
  String get lightVeryBrightHint => 'Direct sunlight, peak UV exposure';

  @override
  String get magnetVeryLow => 'Very low';

  @override
  String get magnetNormal => 'Normal';

  @override
  String get magnetElevated => 'Elevated';

  @override
  String get magnetHighNearMetal => 'High. Near metal.';

  @override
  String get magnetVeryLowHint => 'Minimal electromagnetic interference';

  @override
  String get magnetNormalHint => 'Normal background EMF';

  @override
  String get magnetElevatedHint => 'Possible metal structures or wiring nearby';

  @override
  String get magnetHighHint =>
      'Near electrical infrastructure or heavy equipment';

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
  String get trackingFabStarting => 'Starting...';

  @override
  String get trackingFabRecording => 'Mapping in background';

  @override
  String get trackingFabResume => 'Tap to resume';

  @override
  String get trackingFabStart => 'Tap to start';

  @override
  String get trackingFabStopInSettings =>
      'Mapping is on. Turn it off in Settings.';

  @override
  String get trackingErrorUpdateFailed =>
      'Couldn\'t update tracking. Please try again.';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeAuto => 'Auto';

  @override
  String get settingsTracking => 'Mapping';

  @override
  String get settingsTrackingDesc => 'Turn off to stop all background mapping';

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
  String get settingsDataTransparency => 'Data Transparency';

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
      'Every person who joins maps places you haven\'t reached.';

  @override
  String get layerMine => 'Mine';

  @override
  String get layerAll => 'All';

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
  String get statsReadyToContribute => 'Enable tracking and go about your day.';

  @override
  String get statsFirstContributionHint =>
      'Enable tracking to record your first area';

  @override
  String get statsWeeklyLabel => '7 DAYS';

  @override
  String statsWeeklyTotal(int count) {
    return '$count this week';
  }

  @override
  String get statsMilestoneLabel => 'Next milestone';

  @override
  String get statsMilestoneHint =>
      'Keep going — each route adds to your coverage.';

  @override
  String get statsMilestoneElite => 'All milestones reached.';

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
  String milestoneNudge(int remaining, int target) {
    return '$remaining to $target';
  }

  @override
  String statsCommunityAreas(int count) {
    return '$count places mapped by people near you';
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
  String get transparencyNothingElse =>
      'No precise route. No microphone. No contacts. Nothing else.';

  @override
  String get transparencyLastUpload => 'Last upload';

  @override
  String get transparencyNoUploadYet => 'Nothing sent yet.';

  @override
  String get tileQualityExcellent => 'Well covered';

  @override
  String get tileQualityGood => 'Good coverage';

  @override
  String get tileQualityFair => 'Pass here again';

  @override
  String get tileQualityStaling => 'Staling';

  @override
  String tileDecayWarning(int days) {
    return 'Data is $days days old. Walk here to refresh it.';
  }

  @override
  String tileDecayHint(int days) {
    return 'Mapped $days days ago. Score will drop soon.';
  }

  @override
  String get tileMeasuredWith => 'Recorded with';

  @override
  String get legendHighLabel => 'High quality';

  @override
  String get legendHighSub => 'Lots of good data from here';

  @override
  String get legendMidLabel => 'Medium quality';

  @override
  String get legendMidSub => 'Some data. Walk here again to fill it in.';

  @override
  String get legendLowLabel => 'Low quality';

  @override
  String get legendLowSub => 'Barely any data. Needs more passes.';

  @override
  String get legendCommunitySub => 'Recorded by other people';

  @override
  String get permissionPrimingTitle => 'One thing before we start';

  @override
  String get permissionPrimingBattery => 'Smart battery';

  @override
  String get permissionPrimingBatteryDesc =>
      'Less than 1% per hour. Adapts automatically in background.';

  @override
  String get permissionPrimingCollects => 'Private by design';

  @override
  String get permissionPrimingCollectsDesc =>
      'Brightness, activity and weather only. Never your route or identity.';

  @override
  String get permissionPrimingCta => 'Enable location';

  @override
  String get settingsBatteryMode => 'Smart battery';

  @override
  String get settingsBatteryModeDesc =>
      'Quiet when still, precise when moving. Adapts automatically.';

  @override
  String get firstStartTitle => 'Mapping in the background.';

  @override
  String get firstStartBody =>
      'Light, heat, surface quality — recorded silently. Just go.';

  @override
  String get alwaysOnBannerBody =>
      'Set location to \'Always\' to keep mapping in the background';

  @override
  String get alwaysOnBannerFix => 'Fix';

  @override
  String milestoneReachedTitle(int count) {
    return '$count places mapped';
  }

  @override
  String get milestoneReachedBody => 'Keep going.';

  @override
  String get milestoneReachedCta => 'Keep going';

  @override
  String get firstUploadTitle => 'First area mapped.';

  @override
  String get firstUploadBody => 'Keep moving. Your map is growing.';

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
      other: 'places mapped',
      one: 'place mapped',
    );
    return '$_temp0';
  }

  @override
  String sessionSummaryTotal(int zones, String km2) {
    return 'Total: $zones places · $km2 km²';
  }

  @override
  String get sessionSummaryCta => 'See my map';

  @override
  String get sessionSummaryDone => 'Nice';

  @override
  String get statsMapGrowing => 'map growing. keep walking';

  @override
  String get statsWeeklyChartOffline => 'Weekly chart loads once connected';

  @override
  String uploadMilestone(int count) {
    return '$count uploads. Keep going!';
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
  String get statsStreakAtRisk => 'Go out today to keep your streak.';

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
  String get statsStreakNewRecord => 'New record';

  @override
  String statsStreakPersonalBest(int count) {
    return 'Best: $count days';
  }

  @override
  String get statsChartWeekTab => 'Week';

  @override
  String get statsChartMonthTab => 'Month';

  @override
  String get statsChartMonthEmpty => 'Walk more days to unlock monthly view';

  @override
  String statsBarCalloutDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scans',
      one: '1 scan',
    );
    return '~$_temp0 · brightness · activity · weather';
  }

  @override
  String get statsTerritoryDetails => 'See territory details';

  @override
  String get statsTerritorySheetTitle => 'Your territory';

  @override
  String statsTerritoryZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places',
      one: '1 place',
    );
    return '$_temp0';
  }

  @override
  String get statsTerritoryWhatRecorded => 'What your phone measured here';

  @override
  String get statsTerritoryLightLabel => 'Light';

  @override
  String get statsTerritoryLightDesc =>
      'How bright or dark this place usually is: indoors, outdoors, shaded';

  @override
  String get statsTerritoryMotionLabel => 'Activity';

  @override
  String get statsTerritoryMotionDesc =>
      'How lively this place usually feels: people, traffic, movement';

  @override
  String get statsTerritoryPressureLabel => 'Weather';

  @override
  String get statsTerritoryPressureDesc =>
      'The air pressure recorded here. Reflects local weather conditions.';

  @override
  String get statsTerritoryMapCta =>
      'Tap any place on the map to see its readings';

  @override
  String get tileCommunityClaimCta => 'Walk through here to make it yours';

  @override
  String get tileLowQualityHint =>
      'Walk through here again. More visits make this place stronger on the map.';

  @override
  String homeZonesOnYourMap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places on your map',
      one: '1 place on your map',
    );
    return '$_temp0';
  }

  @override
  String homeCommunityScopeHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places mapped in your area',
      one: '1 place mapped in your area',
    );
    return '$_temp0';
  }

  @override
  String get tileCivicNote => 'You measured this.';

  @override
  String get tileShareButton => 'Share this spot';

  @override
  String tileShareText(String condition) {
    return 'I measured this spot: $condition. Check it out on the map.';
  }

  @override
  String sessionSummaryShareText(int gained, int total, String km2) {
    return 'I mapped +$gained new places today. $total total · $km2 km²';
  }

  @override
  String sessionSummaryShareTextEmpty(String duration, int total, String km2) {
    return 'Mapped for $duration. $total places on my map · $km2 km²';
  }

  @override
  String sessionSummaryShareTextDarkSky(int total, String km2) {
    return 'Mapped a dark sky zone tonight — $total places on my light pollution map · $km2 km²\nhttps://greengains.app/dashboard/#map';
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
  String get sensorLuxIndoor => 'Dim';

  @override
  String get sensorLuxBright => 'Bright';

  @override
  String get sensorLuxDirect => 'In sunlight';

  @override
  String get sensorMovementLow => 'Calm';

  @override
  String get sensorMovementMid => 'Active';

  @override
  String get sensorMovementHigh => 'Busy';

  @override
  String get sensorMovementIntense => 'Heavy traffic';

  @override
  String get sensorMovementLowHint => 'Minimal foot traffic';

  @override
  String get sensorMovementMidHint => 'Light pedestrian activity';

  @override
  String get sensorMovementHighHint => 'Transit or crowds';

  @override
  String get sensorMovementIntenseHint => 'Heavy traffic or machinery';

  @override
  String get sensorHpaLow => 'Clear air';

  @override
  String get sensorHpaMid => 'Stable';

  @override
  String get sensorHpaHigh => 'Heavy air';

  @override
  String get sensorHpaLowHint => 'High pressure, stable dry conditions';

  @override
  String get sensorHpaMidHint => 'Normal atmospheric pressure at this altitude';

  @override
  String get sensorHpaHighHint => 'Low pressure, unsettled weather possible';

  @override
  String get sensorAccelStill => 'Barely moving';

  @override
  String get sensorAccelWalk => 'Walking';

  @override
  String get sensorAccelActive => 'Running / cycling';

  @override
  String get sensorAccelHeavy => 'Heavy movement';

  @override
  String get sensorGyroStill => 'Holding still';

  @override
  String get sensorGyroSlow => 'Slow turn';

  @override
  String get sensorGyroFast => 'Fast rotation';

  @override
  String get tileSensorInsightsLabel => 'What\'s usually here';

  @override
  String get tileVibrationCalm => 'Very still';

  @override
  String get tileVibrationLight => 'Light activity';

  @override
  String get tileVibrationActive => 'Active surface';

  @override
  String get tileVibrationHeavy => 'Heavy traffic';

  @override
  String tileConditionSummary(String light, String movement, String pressure) {
    return 'Usually $light, $movement, under $pressure.';
  }

  @override
  String tileConditionSummaryNoHpa(String light, String movement) {
    return 'Usually $light and $movement.';
  }

  @override
  String territoryHeroLabel(String neighborhood, int count) {
    return '$neighborhood · $count places';
  }

  @override
  String get serverWakingUp => 'Loading…';

  @override
  String get ambientHereLabel => 'Here';

  @override
  String get ambientNearbyLabel => 'Nearby';

  @override
  String get ambientUnmappedLabel => 'Walk here to reveal data';

  @override
  String get permissionLostTitle => 'Location access off';

  @override
  String get permissionLostBody => 'Your map stopped updating. Tap to fix.';

  @override
  String get permissionLostCta => 'Fix in Settings';

  @override
  String referralNeighborhoodHook(String neighborhood) {
    return 'Help map $neighborhood. Every neighbor fills in what you haven\'t reached.';
  }

  @override
  String get onboardingActivateTitle => 'Almost there';

  @override
  String get onboardingActivateSubtitle =>
      'Your phone reads the environment around you as you go. Your route is never stored.';

  @override
  String get onboardingActivateCta => 'Start mapping';

  @override
  String get onboardingPermissionDenied =>
      'Location permission is required to map your city.';

  @override
  String get onboardingPermissionDeniedForeverTitle => 'Permission required';

  @override
  String get onboardingPermissionDeniedForeverBody =>
      'Location access was permanently denied. Open Settings and enable it under Permissions → Location.';

  @override
  String get onboardingOpenSettings => 'Open Settings';

  @override
  String homeMaxClusterHint(int count) {
    return 'biggest area: $count places';
  }

  @override
  String get firstUploadBadge => 'FIRST PLACE MAPPED';

  @override
  String get firstUploadHeadline => 'Your first spot is on the map.';

  @override
  String get firstUploadSubtext =>
      'Every place you pass through fills in automatically.';

  @override
  String get firstUploadSensorsLabel => 'RECORDED PASSIVELY';

  @override
  String get firstUploadSensorsValue => 'light · heat · surface quality';

  @override
  String get firstUploadPrivacyLabel => 'PRIVACY';

  @override
  String get firstUploadPrivacyValue => 'anonymous · no route stored';

  @override
  String get firstUploadKeepMappingCta => 'Keep mapping';

  @override
  String get liveSensorsHeader => 'LIVE SENSORS';

  @override
  String get liveSensorMotionLabel => 'Motion';

  @override
  String get liveSensorPressureLabel => 'Pressure';

  @override
  String get sessionSummaryBadge => 'DONE';

  @override
  String get sessionSummaryZonesGainedLabel => 'NEW PLACES';

  @override
  String get sessionSummarySubline => 'added';

  @override
  String get sessionSummaryNoZonesLabel => 'YOUR MAP';

  @override
  String get sessionSummaryNoZonesSubline => 'Try a different route next time.';

  @override
  String get sessionSummaryWatermark => 'Mapped with GreenGains';

  @override
  String get sessionSummaryShareCta => 'Share';

  @override
  String sessionMilestoneHit(int milestone) {
    return '$milestone places.';
  }

  @override
  String get sessionSummaryNextHook => 'Come back tomorrow.';

  @override
  String get sessionSummaryNextHookEmpty =>
      'Recorded silently every time you go out.';

  @override
  String get sessionStatArea => 'AREA';

  @override
  String get sessionStatDuration => 'TIME';

  @override
  String get sessionStatTotal => 'TOTAL';

  @override
  String get sessionStatUploads => 'SYNCS';

  @override
  String get sessionStatAreaExplain =>
      'Total area you\'ve mapped this session, based on the zones covered.';

  @override
  String get sessionStatDurationExplain =>
      'How long tracking was active during this session.';

  @override
  String get sessionStatUploadsExplain =>
      'Number of times your sensor data was uploaded during this session.';

  @override
  String get sessionStatTotalExplain =>
      'Total unique zones you\'ve ever mapped across all sessions.';

  @override
  String homeSessionPill(int uploads) {
    return '$uploads synced';
  }

  @override
  String homeSessionPillWithZones(int uploads, int zones) {
    return '$uploads synced · +$zones zones';
  }

  @override
  String get statsUploadsHint => 'uploads';

  @override
  String get statsKpiTodayExplain => 'Syncs sent today.';

  @override
  String get statsKpiWeekExplain => 'Syncs sent this week.';

  @override
  String get statsKpiBestDayExplain => 'Most syncs in a single day.';

  @override
  String get statsKpiAvgExplain => 'Average syncs on active days.';

  @override
  String get profileTileUploadsExplain => 'Total syncs sent to our servers.';

  @override
  String get profileTileDaysExplain =>
      'Days you\'ve contributed at least once.';

  @override
  String profileTileAreaExplain(String area) {
    return 'Area mapped across all your sessions.';
  }

  @override
  String get profileTileAreaCells => 'zones explored';

  @override
  String get profileStatCityBlocks => 'city blocks';

  @override
  String get profileStreakExplain => 'Consecutive days with at least one sync.';

  @override
  String profileStreakToMilestone(int days, String unit, int milestone) {
    return '$days $unit to $milestone-$unit streak';
  }

  @override
  String get profileUploadsExplanation =>
      'Each upload is a batch of sensor readings captured at one location.';

  @override
  String get profileDaysExplanation =>
      'Days where your phone was active at least once. More days means richer, more recent coverage.';

  @override
  String get profileZonesExplanation =>
      'Each zone is roughly a city block. Tap the map to see which areas you\'ve covered.';

  @override
  String get profileSeeInStats => 'See in Stats';

  @override
  String get profileViewOnMap => 'View on Map';

  @override
  String statsMilestoneTarget(int target) {
    return '$target places';
  }

  @override
  String get statsActivitySection => 'YOUR WEEK';

  @override
  String get statsTerritorySection => 'YOUR AREA';

  @override
  String get mapTapHint => 'Tap a place to explore';

  @override
  String get sessionPersonalBest => 'Personal best';

  @override
  String returnDeltaTitle(int zones) {
    return '$zones new places while you were away.';
  }

  @override
  String get returnDeltaDismiss => 'Got it';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutConfirmTitle => 'Sign out?';

  @override
  String get settingsSignOutConfirmBody =>
      'You\'ll need to sign back in to see your map.';

  @override
  String get settingsSignOutConfirm => 'Sign out';

  @override
  String get settingsSignOutCancel => 'Cancel';

  @override
  String get mappingActiveSheetTitle => 'Mapping now';

  @override
  String get mappingActiveSheetBody =>
      'Keep moving to discover new places. Your map grows automatically.';

  @override
  String mappingActiveSheetZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new places this session',
      one: '1 new place this session',
      zero: 'No new places yet',
    );
    return '$_temp0';
  }

  @override
  String get mappingActiveSheetCta => 'Open map';

  @override
  String get mappingActiveSheetStop => 'Stop mapping';

  @override
  String homeStreakBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count day streak',
      one: '1 day streak',
    );
    return '$_temp0';
  }

  @override
  String get streakResetBanner => 'Streak reset. Start fresh today.';

  @override
  String get sessionSummaryNextHookStreak => 'Streak alive.';

  @override
  String get sessionSummaryNextHookFirst =>
      'Go out tomorrow to start a streak.';

  @override
  String get weeklyGoalTitle => 'Week complete.';

  @override
  String get weeklyGoalBody => 'See you next week.';

  @override
  String get weeklyGoalDismiss => 'Nice';

  @override
  String get statsEmptyLockLight =>
      'Light levels — pollution at night, sunlight by day';

  @override
  String get statsEmptyLockMovement =>
      'Surface quality — smoothness of your routes';

  @override
  String get statsEmptyLockPressure => 'Heat & pressure — urban heat exposure';

  @override
  String get statsKm2Unit => 'km²';

  @override
  String get statsLast30DaysUnit => '/ 30';

  @override
  String get referralWaiting =>
      'Link shared. No one yet — you might be first in your area.';

  @override
  String get referralFirstJoined => 'First person joined.';

  @override
  String get referralShareAgain => 'Share again';

  @override
  String referralShareText(String code) {
    return 'Join me on GreenGains — we\'re mapping light pollution, air pressure and road conditions around us. Use my invite code $code when you sign up.';
  }

  @override
  String get onboardingHaveCode => 'Got an invite code?';

  @override
  String get onboardingCodeHint => 'Enter invite code (e.g. GG-XXXXX)';

  @override
  String get onboardingCodeApplied => 'Invite code applied.';

  @override
  String get profileUnlockTitle => 'Your map is saving.';

  @override
  String get profileUnlockBody =>
      'Sign in to keep it forever and sync across devices.';

  @override
  String get profileUnlockCta => 'Sign in to keep my map';

  @override
  String get mapZeroStateTitle => 'Runs in the background';

  @override
  String get mapZeroStateBody =>
      'Enable tracking once. Your map fills in as you move.';

  @override
  String get snapshotCardTitle => 'YOUR NEIGHBOURHOOD';

  @override
  String snapshotReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count readings',
      one: '1 reading',
    );
    return '$_temp0';
  }

  @override
  String snapshotAcrossZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones',
      one: '1 zone',
    );
    return 'across $_temp0';
  }

  @override
  String get snapshotLightDark => 'Dark';

  @override
  String get snapshotLightDim => 'Dim';

  @override
  String get snapshotLightNormal => 'Well lit';

  @override
  String get snapshotLightBright => 'Bright';

  @override
  String get snapshotLightVeryBright => 'Very bright';

  @override
  String get snapshotMovementCalm => 'Calm';

  @override
  String get snapshotMovementActive => 'Active';

  @override
  String get snapshotMovementBusy => 'Busy';

  @override
  String get snapshotPressureLow => 'Low pressure';

  @override
  String get snapshotPressureStable => 'Stable';

  @override
  String get snapshotPressureHigh => 'High pressure';

  @override
  String get insightNoData => 'Not enough data yet for this area.';

  @override
  String get insightNormal => 'Nothing unusual detected here.';

  @override
  String get insightRouteHeader => 'YOUR ROUTE';

  @override
  String get insightLightPristine =>
      'Almost no artificial light here. Your melatonin stays intact on this route.';

  @override
  String get insightLightLow =>
      'Naturally dark here. Good for winding down if you come home this way.';

  @override
  String get insightLightModerate =>
      'Some sky glow. Enough artificial light to affect your body clock over time.';

  @override
  String get insightLightHigh =>
      'Bright at night — like a lit room. Not ideal before sleep.';

  @override
  String get insightLightSevere =>
      'Very bright at night. Your body thinks it\'s still daytime here.';

  @override
  String get insightSunShaded => 'Shaded and cool. Lower UV than open streets.';

  @override
  String get insightSunPartial => 'Normal outdoor conditions.';

  @override
  String get insightSunBright => 'Open and well-exposed to daylight.';

  @override
  String get insightSunIntense =>
      'Strong direct sun. Worth planning water or shade here in summer.';

  @override
  String get insightSurfaceSmooth =>
      'Smooth surface. Easy on bikes, joints and strollers.';

  @override
  String get insightSurfaceNormal => 'Normal pavement.';

  @override
  String get insightSurfaceRough =>
      'Rough road. Harder on bikes, joints and strollers.';

  @override
  String get insightSurfacePoor =>
      'Very rough surface. Worth avoiding if you\'re on a bike or with a stroller.';

  @override
  String get insightHeatExposed =>
      'This zone runs hot. Noticeably warmer than nearby streets.';

  @override
  String get insightSessionDarkSky =>
      'Low artificial light on this route. Good for sleep if you come home this way.';

  @override
  String get insightSessionBrightCity =>
      'Bright at night throughout this route. Like walking through a lit office before bed.';

  @override
  String get insightSessionRoughRoute =>
      'Rough road on this route. Harder on your body than smoother alternatives.';

  @override
  String get insightSessionHotRoute =>
      'This route runs hot. Worth considering cooler alternatives in summer.';
}
