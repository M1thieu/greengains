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
    return 'Last upload: $time';
  }

  @override
  String get totalUploads => 'Total Uploads';

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
  String get settingsMobileData => 'Mobile Data Upload';

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
  String get statsZoneExplainer =>
      'A zone is roughly one city block, recorded as you pass through.';

  @override
  String get statsUploadExplainer =>
      'Light, heat and surface quality captured at that moment.';

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
  String get statsInDepthWhenYouMap => 'When you map';

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
  String get infoTileQualityTitle => 'Coverage quality';

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
  String get tileInfoNoSensorData =>
      'Location only. No sensor readings for this spot.';

  @override
  String get noCoverageYet => 'No coverage yet';

  @override
  String get startTrackingToMap => 'Start tracking to map your area';

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
      'Every person who joins maps places you haven\'t reached.';

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
      other: '$count zones to go',
      one: '1 zone to go',
    );
    return '$_temp0';
  }

  @override
  String get batteryDialogTitle => 'Keep mapping';

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
  String get permissionPrimingBattery => 'Smart battery';

  @override
  String get permissionPrimingCollects => 'Private by design';

  @override
  String onboardingSocialProof(int count) {
    return '$count people already mapping their neighborhood';
  }

  @override
  String get statsWeeklyChartOffline => 'Weekly chart loads once connected';

  @override
  String get statsViewOnMap => 'View on map';

  @override
  String tileFirstMapped(String date) {
    return 'First mapped $date';
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
  String get tileVibrationActive => 'Active surface';

  @override
  String get tileVibrationHeavy => 'Heavy traffic';

  @override
  String get tileSurfaceSmooth => 'smooth road';

  @override
  String get tileSurfaceRough => 'rough road';

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
  String get sessionCharacterHotRoute => 'HOT ROUTE';

  @override
  String get sessionCharacterRoughRoad => 'ROUGH ROADS';

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
  String get profileTileAreaCells => 'zones explored';

  @override
  String get profileStatCityBlocks => 'city blocks';

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
  String get statsActivitySection => 'YOUR WEEK';

  @override
  String statsVsPrevWeek(String delta) {
    return '$delta% vs prev week';
  }

  @override
  String get statsTerritorySection => 'YOUR AREA';

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
  String get statsEmptyLockPressure =>
      'Weather: heat and pressure along your routes';

  @override
  String get statsKm2Unit => 'km²';

  @override
  String get statsLast30DaysUnit => '/ 30';

  @override
  String get referralWaiting =>
      'Link shared. No one yet. You might be first in your area.';

  @override
  String get referralFirstJoined => 'First person joined.';

  @override
  String get referralShareAgain => 'Share again';

  @override
  String referralShareText(String code) {
    return 'Join me on GreenGains. We\'re mapping light pollution, air pressure and road conditions around us. Use my invite code $code when you sign up.';
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
      'Bright at night, like a lit room. Not ideal before sleep.';

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

  @override
  String get statsInsightLabel => 'THIS WEEK';

  @override
  String statsInsightRoughest(String street, int pct) {
    return 'Roughest stretch: $street, bumpier than $pct% of your mapped routes';
  }

  @override
  String statsInsightNewZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new places mapped this week',
      one: '1 new place mapped this week',
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
