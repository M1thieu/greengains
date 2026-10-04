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
  String get onboardingFeature1Title => 'Nothing to do.';

  @override
  String get onboardingFeature2Title => 'Private by default';

  @override
  String get onboardingFeature3Title => 'See what\'s around you.';

  @override
  String get onboardingSignInTitle => 'Your map starts here.';

  @override
  String onboardingPrivacyNotice(String privacyPolicy, String termsOfService) {
    return 'By continuing, you agree to our $privacyPolicy and $termsOfService.';
  }

  @override
  String get signInWithGoogleLabel => 'Continue with Google';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get buttonNext => 'Next';

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
  String homeStatArea(String area) {
    return '$area mapped';
  }

  @override
  String get homeActionStart => 'Start';

  @override
  String get homeActionStop => 'Stop';

  @override
  String get homeActionResume => 'Resume';

  @override
  String get startTracking => 'Start Tracking';

  @override
  String get stopTracking => 'Stop Tracking';

  @override
  String get trackingPaused => 'Tracking Paused';

  @override
  String lastUpload(String time) {
    return 'Last update: $time';
  }

  @override
  String get totalUploads => 'Total scans';

  @override
  String profileMemberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsDisplay => 'Display';

  @override
  String get settingsMobileData => 'Use mobile data';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get permissionLocationMessage =>
      'Allow location so your phone can map as you walk.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get buttonCancel => 'Cancel';

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
  String get chipPaused => 'Paused';

  @override
  String get semanticsCenterOnMe => 'Center map on my location';

  @override
  String get statsToday => 'Today';

  @override
  String get statsThisWeek => 'This week';

  @override
  String get statsDaysActive => 'Days Active';

  @override
  String get statsAreasLabel => 'places covered';

  @override
  String get statsDataPtsLabel => 'readings';

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
  String get statsWeeklyTargetLabel => 'THIS WEEK';

  @override
  String get statsWeeklyTargetComplete => 'Goal reached';

  @override
  String get statsLocalLegendLabel => 'YOUR NEIGHBORHOOD';

  @override
  String get statsLocalLegendLeader =>
      'You\'re the most active in your neighborhood this week';

  @override
  String statsLocalLegendRank(int rank, int total) {
    return '#$rank of $total in your neighborhood this week';
  }

  @override
  String statsLocalLegendGap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places to take the lead',
      one: '1 place to take the lead',
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
      other: 'You\'re the only one who\'s been to $count of your places',
      one: 'You\'re the only one who\'s been to 1 of your places',
    );
    return '$_temp0';
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
  String get statsRecordBestSession => 'Best session';

  @override
  String get statsZoneExplainer => 'A place is roughly one city block.';

  @override
  String get statsUploadExplainer =>
      'Light, heat and ground at the time of the scan.';

  @override
  String get statsTabInDepth => 'In depth';

  @override
  String get statsOpenDetails => 'In depth';

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
    return '$date · no scans';
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
  String get statsInDepthWhenYouMap => 'When you scan';

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
  String get statsQualitySection => 'RELIABILITY';

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
      'The higher, the more reliable your readings.';

  @override
  String get statsAvgPrefix => 'avg';

  @override
  String get infoTileQualityTitle => 'Reliability';

  @override
  String get infoTilePersonalTitle => 'Your area';

  @override
  String get statsActivityTrend => 'Your week';

  @override
  String get statsTodayLabel => 'TODAY';

  @override
  String get statsStartContributing => 'No data yet.';

  @override
  String get statsEmptyGoMap => 'Enable tracking';

  @override
  String get statsLoadErrorTitle => 'Couldn\'t load your stats';

  @override
  String get statsCollectingTitle => 'Collecting';

  @override
  String get tileInfoSamplesLabel => 'readings';

  @override
  String get tileInfoDevicesLabel => 'people';

  @override
  String get tileInfoQualityLabel => 'Reliability';

  @override
  String get tileInfoAreaLabel => 'area';

  @override
  String get tileInfoPersonal => 'Yours';

  @override
  String get tileInfoCommunity => 'Not yours yet';

  @override
  String get tileOnlyYouMapped => 'Only you\'ve been here';

  @override
  String get tileInfoNoSensorData => 'Location only, no readings here yet.';

  @override
  String get noCoverageYet => 'Nothing here yet';

  @override
  String get startTrackingToMap => 'Start tracking to fill your map';

  @override
  String tilesCount(int count) {
    return '$count tiles';
  }

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
  String get magnetVeryLow => 'Very low';

  @override
  String get magnetNormal => 'Normal';

  @override
  String get magnetElevated => 'Elevated';

  @override
  String get magnetHighNearMetal => 'High. Near metal.';

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
  String get settingsLegal => 'Legal';

  @override
  String get settingsDataTransparency => 'Data Transparency';

  @override
  String get settingsExportData => 'Export My Data';

  @override
  String get settingsExportDataFailed =>
      'Couldn\'t export your data. Try again later.';

  @override
  String get referralInviteDescription =>
      'Every friend who joins adds places to the map.';

  @override
  String get layerMine => 'Mine';

  @override
  String get layerAll => 'All';

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
  String statsWeeklyTotal(int count) {
    return '$count this week';
  }

  @override
  String get statsMilestoneElite => 'All milestones reached.';

  @override
  String statsMilestoneRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more places',
      one: '1 more place',
    );
    return '$_temp0';
  }

  @override
  String get batteryDialogTitle => 'Keep running in the background';

  @override
  String get settingsDiagnostics => 'Sensor Diagnostics';

  @override
  String get settingsDiagnosticsDesc =>
      'Live readings from your device sensors';

  @override
  String get sensorLiveSheetTitle => 'Around you';

  @override
  String get transparencyNothingElse =>
      'No precise route. No microphone. No contacts. Nothing else.';

  @override
  String get transparencyLastUpload => 'Last update';

  @override
  String get transparencyNoUploadYet => 'Nothing sent yet.';

  @override
  String get tileQualityExcellent => 'Well covered';

  @override
  String get tileQualityGood => 'Good coverage';

  @override
  String get tileQualityFair => 'Pass here again';

  @override
  String get tileQualityStaling => 'Getting old';

  @override
  String tileDecayWarning(int days) {
    return 'Info from $days days ago. Come back here to update it.';
  }

  @override
  String tileDecayHint(int days) {
    return 'Updated $days days ago.';
  }

  @override
  String get legendHighLabel => 'Very reliable';

  @override
  String get legendHighSub => 'Lots of readings here';

  @override
  String get legendMidLabel => 'Fairly reliable';

  @override
  String get legendMidSub => 'A few readings. Come back to add more.';

  @override
  String get legendLowLabel => 'Not very reliable';

  @override
  String get legendLowSub => 'Barely any data. Needs more passes.';

  @override
  String get legendCommunitySub => 'Recorded by other people';

  @override
  String get permissionPrimingBattery => 'Smart battery';

  @override
  String get permissionPrimingCollects => 'Private by design';

  @override
  String onboardingSocialProof(int count) {
    return '$count people are already filling in their neighborhood map';
  }

  @override
  String get statsWeeklyChartOffline => 'Weekly chart loads once connected';

  @override
  String get statsViewOnMap => 'View on map';

  @override
  String tileFirstMapped(String date) {
    return 'First visit $date';
  }

  @override
  String statsSinceDate(String date) {
    return 'since $date';
  }

  @override
  String get statsStreakNewRecord => 'New record';

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
    return '~$_temp0 · light · movement · weather';
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
      'Air pressure here. It follows the weather.';

  @override
  String get statsTerritoryMapCta =>
      'Tap any place on the map to see its readings';

  @override
  String get tileCommunityClaimCta => 'Walk through here to make it yours';

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
  String get sensorHpaLow => 'Clear air';

  @override
  String get sensorHpaMid => 'Stable';

  @override
  String get sensorHpaHigh => 'Heavy air';

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
  String get tileVibrationCalm => 'Very still';

  @override
  String get tileVibrationLight => 'Light activity';

  @override
  String get tileVibrationActive => 'Lots of movement';

  @override
  String get tileVibrationHeavy => 'Heavy traffic';

  @override
  String get tileSurfaceSmooth => 'smooth ground';

  @override
  String get tileSurfaceRough => 'uneven ground';

  @override
  String get tileSurfaceHeavy => 'very rough';

  @override
  String get tileCondLightDark => 'dark';

  @override
  String get tileCondLightDim => 'dim';

  @override
  String get tileCondLightBright => 'bright';

  @override
  String get tileCondLightShaded => 'shaded';

  @override
  String get tileCondLightPartial => 'overcast';

  @override
  String get tileCondLightIntense => 'very bright';

  @override
  String get tileCondActivityCalm => 'quiet';

  @override
  String get tileCondActivityModerate => 'moderate';

  @override
  String get tileCondActivityActive => 'active';

  @override
  String get tileCondActivityBusy => 'busy';

  @override
  String get sessionCharacterDarkSky => 'DARK SKY';

  @override
  String get sessionCharacterBrightCity => 'LIT STREETS';

  @override
  String get sessionCharacterHotRoute => 'HOT OUTING';

  @override
  String get sessionCharacterRoughRoad => 'UNEVEN GROUND';

  @override
  String get sessionCharacterSunExposed => 'OPEN SKY';

  @override
  String get mapperRoleContributor => 'Contributor';

  @override
  String get mapperRolePioneer => 'Pioneer';

  @override
  String get mapperRoleExplorer => 'Explorer';

  @override
  String get mapperRoleCartographer => 'Cartographer';

  @override
  String get mapperRoleCityMapper => 'City Mapper';

  @override
  String get mapperRoleUrbanScientist => 'Urban Scientist';

  @override
  String get serverWakingUp => 'Loading…';

  @override
  String get permissionLostTitle => 'Location access off';

  @override
  String get permissionLostCta => 'Fix in Settings';

  @override
  String referralNeighborhoodHook(String neighborhood) {
    return 'Invite your neighbors to fill in the map of $neighborhood.';
  }

  @override
  String get onboardingActivateTitle => 'Almost there';

  @override
  String get onboardingActivateSubtitle =>
      'Your phone reads the environment around you as you go. Your route is never stored.';

  @override
  String get onboardingActivateCta => 'Start';

  @override
  String get onboardingPermissionDenied =>
      'Location is needed to fill your map.';

  @override
  String get profileTileAreaCells => 'places';

  @override
  String get profileStatCityBlocks => 'city blocks';

  @override
  String profileStreakToMilestone(int days, String unit, int milestone) {
    return '$days $unit to $milestone-$unit streak';
  }

  @override
  String get profileUploadsExplanation =>
      'A scan is what your phone measures at one place.';

  @override
  String get profileDaysExplanation => 'Days your phone scanned at least once.';

  @override
  String get profileZonesExplanation =>
      'A place is roughly one city block. Tap the map to see them.';

  @override
  String get profileSeeInStats => 'See in Stats';

  @override
  String get profileViewOnMap => 'View on Map';

  @override
  String get statsActivitySection => 'YOUR WEEK';

  @override
  String statsVsPrevWeek(String delta) {
    return '$delta% vs prev week';
  }

  @override
  String get statsTerritorySection => 'YOUR NEIGHBORHOOD';

  @override
  String get mapTapHint => 'Tap a place to explore';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsDeleteAccount => 'Delete my account';

  @override
  String get settingsDeleteAccountWarning =>
      'Your account and all your data will be erased. This can\'t be undone.';

  @override
  String get settingsDeleteAccountConfirm => 'Delete';

  @override
  String get streakResetBanner => 'Streak reset. Start fresh today.';

  @override
  String get statsEmptyLockLight => 'Light: dark sky at night, sunlight by day';

  @override
  String get statsEmptyLockMovement => 'Activity: how lively each place feels';

  @override
  String get statsEmptyLockPressure => 'Weather: heat and pressure around you';

  @override
  String get statsKm2Unit => 'km²';

  @override
  String get statsLast30DaysUnit => '/ 30';

  @override
  String get referralWaiting =>
      'Link shared. No one yet. You might be the first in your neighborhood.';

  @override
  String get referralFirstJoined => 'First person joined.';

  @override
  String get referralShareAgain => 'Share again';

  @override
  String referralShareText(String code) {
    return 'Join me on GreenGains: we\'re mapping light, weather and street conditions around us. My code: $code';
  }

  @override
  String get onboardingHaveCode => 'Got an invite code?';

  @override
  String get onboardingCodeHint => 'Enter invite code (e.g. GG-XXXXX)';

  @override
  String get profileUnlockTitle => 'Your map is saving.';

  @override
  String get mapZeroStateTitle => 'Your first place is one walk away';

  @override
  String get insightNoData => 'Not enough readings here yet.';

  @override
  String get insightNormal => 'Nothing unusual detected here.';

  @override
  String get insightRouteHeader => 'YOUR OUTING';

  @override
  String get insightLightPristine => 'Very little artificial light here.';

  @override
  String get insightLightLow =>
      'Naturally dark here. Good for winding down if you come home this way.';

  @override
  String get insightLightModerate =>
      'Some sky glow. Enough artificial light to affect your body clock over time.';

  @override
  String get insightLightHigh =>
      'Bright at night, like a lit room. Not ideal before sleep.';

  @override
  String get insightLightSevere =>
      'Very bright at night. Your body thinks it\'s still daytime here.';

  @override
  String get insightSunShaded => 'Shaded and cool.';

  @override
  String get insightSunPartial => 'Normal outdoor conditions.';

  @override
  String get insightSunBright => 'Sunny spot.';

  @override
  String get insightSunIntense =>
      'Strong direct sun. Worth planning water or shade here in summer.';

  @override
  String get insightSurfaceSmooth => 'Smooth ground.';

  @override
  String get insightSurfaceNormal => 'Normal ground.';

  @override
  String get insightSurfaceRough => 'Uneven ground.';

  @override
  String get insightSurfacePoor => 'Very uneven ground.';

  @override
  String get insightHeatExposed => 'Warmer than the streets around.';

  @override
  String get insightSessionDarkSky =>
      'Little artificial light during your outing.';

  @override
  String get insightSessionBrightCity =>
      'Brightly lit at night during your outing.';

  @override
  String get insightSessionRoughRoute => 'Uneven ground during your outing.';

  @override
  String get insightSessionHotRoute => 'It was hot during your outing.';

  @override
  String get statsInsightLabel => 'THIS WEEK';

  @override
  String statsInsightRoughest(String street, int pct) {
    return 'Most uneven street: $street (more than $pct% of your outings)';
  }

  @override
  String statsInsightNewZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new places this week',
      one: '1 new place this week',
    );
    return '$_temp0';
  }

  @override
  String statsInsightSolo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places only you\'ve ever been',
      one: '1 place only you\'ve ever been',
    );
    return '$_temp0';
  }

  @override
  String statsInsightBrightest(String street) {
    return 'Most lit-up spot: $street';
  }
}
