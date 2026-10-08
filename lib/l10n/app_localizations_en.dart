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
      'Your phone measures light, pressure and movement along the streets you pass.';

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
      'Light, pressure and movement, measured wherever you go.';

  @override
  String get onboardingSignInTitle => 'Your readings start here.';

  @override
  String get onboardingSignInSubtitle =>
      'Sign in to keep your readings across devices.';

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
  String homeStatArea(String area) {
    return '$area mapped';
  }

  @override
  String homeStatToday(int count) {
    return '+$count today';
  }

  @override
  String get homeActionStart => 'Start';

  @override
  String get homeActionStop => 'Stop';

  @override
  String get homeActionResume => 'Resume';

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
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

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
  String get buttonClose => 'Close';

  @override
  String get loading => 'Loading...';

  @override
  String get success => 'Success';

  @override
  String get error => 'Error';

  @override
  String get profileUserFallback => 'User';

  @override
  String get chipPaused => 'Paused';

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
  String get uploadSuccessMessage => 'Map updated!';

  @override
  String uploadSuccessNewZone(int count) {
    return 'New place measured · $count in total';
  }

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
  String get statsKmMapped => 'Area covered';

  @override
  String get statsBestDayLabel => 'Best day';

  @override
  String get statsAvgPerDay => 'Avg. per day';

  @override
  String get statsWeeklyTargetComplete => 'Goal reached';

  @override
  String get statsImpactLabel => 'YOUR IMPACT';

  @override
  String statsImpactSolo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places nobody else has measured',
      one: '1 place nobody else has measured',
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
  String statsZoneExplainer(String area) {
    return '1 place ≈ $area';
  }

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
      'GPS accuracy, steadiness and sensor exposure';

  @override
  String get statsAvgPrefix => 'avg';

  @override
  String get statsActivityTrend => 'Your week';

  @override
  String get statsTodayLabel => 'TODAY';

  @override
  String get statsStartContributing => 'No data yet.';

  @override
  String get statsEmptyDescription =>
      'Your measurements show up here after the first upload.';

  @override
  String get statsEmptyGoMap => 'Enable tracking';

  @override
  String get tileInfoQualityLabel => 'Coverage';

  @override
  String get tileInfoPersonal => 'You measured here';

  @override
  String get tileInfoCommunity => 'Measured by the community';

  @override
  String get tileOnlyYouMapped => 'Only you\'ve been here';

  @override
  String get mapLayerTitle => 'Map layer';

  @override
  String get mapLayerQuality => 'Data quality';

  @override
  String tileContributors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributors',
      one: '1 contributor',
    );
    return '$_temp0';
  }

  @override
  String tileMeasurements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count measurements',
      one: '1 measurement',
    );
    return '$_temp0';
  }

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
  String get sensorLiveReadings => 'What\'s around you';

  @override
  String get sensorLiveSubtitle => 'Light, movement and pressure, live.';

  @override
  String get sensorAroundYou => 'Around You';

  @override
  String get sensorMovement => 'Movement';

  @override
  String get sensorAcceleration => 'Acceleration';

  @override
  String get sensorLight => 'Light';

  @override
  String get sensorMagneticField => 'Magnetic field';

  @override
  String get sensorWifi => 'Wi-Fi';

  @override
  String get sensorTemperature => 'Temperature';

  @override
  String get sensorHumidity => 'Humidity';

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
  String get lightDarkHint => 'Night, or sensor covered';

  @override
  String get lightDimHint => 'Low ambient light';

  @override
  String get lightNormalHint => 'Typical indoor daylight';

  @override
  String get lightBrightHint => 'Near a window or outdoors';

  @override
  String get lightVeryBrightHint => 'Full daylight, outdoors';

  @override
  String get magnetVeryLow => 'Very low';

  @override
  String get magnetNormal => 'Normal';

  @override
  String get magnetElevated => 'Elevated';

  @override
  String get magnetHighNearMetal => 'Very high';

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
  String get settingsMobileDataDescription => 'Upload over LTE/5G when needed';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsDataTransparency => 'Data Transparency';

  @override
  String get settingsDataDeletion => 'Request Data Deletion';

  @override
  String get settingsExportData => 'Export My Data';

  @override
  String get settingsExportDataPreparing => 'Preparing your export…';

  @override
  String get settingsExportDataFailed =>
      'Couldn\'t export your data. Try again later.';

  @override
  String get referralInviteDescription =>
      'Every person you invite measures other places.';

  @override
  String get layerMine => 'Me';

  @override
  String get layerAll => 'Everyone';

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
  String get statsMilestoneLabel => 'Next milestone';

  @override
  String get statsMilestoneElite => 'All milestones reached.';

  @override
  String statsMilestoneRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places to go',
      one: '1 place to go',
    );
    return '$_temp0';
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
  String get batteryDialogOemXiaomiHint =>
      'Also on Xiaomi/Redmi: enable AutoStart in Settings → Apps → Manage apps → GreenGains → AutoStart';

  @override
  String get batteryDialogOemHuaweiHint =>
      'Also on Huawei/Honor: open Settings → Battery → App launch, set GreenGains to manual with all toggles on';

  @override
  String get batteryDialogOemSamsungHint =>
      'Also on Samsung: set GreenGains to Unrestricted in Settings → Battery → Background usage limits';

  @override
  String get settingsDiagnostics => 'Sensor Diagnostics';

  @override
  String get settingsNotifications => 'Notifications';

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
  String get tileQualityFair => 'Few readings';

  @override
  String get tileQualityStaling => 'Staling';

  @override
  String get permissionPrimingBattery => 'Smart battery';

  @override
  String get permissionPrimingBatteryDesc =>
      'Adapts automatically in the background.';

  @override
  String get permissionPrimingCollects => 'Private by design';

  @override
  String get permissionPrimingCollectsDesc =>
      'Light, movement and pressure only. Never your route or identity.';

  @override
  String onboardingSocialProof(int count) {
    return '$count people already mapping their neighborhood';
  }

  @override
  String statsCommunityLine(int mappers, int zones) {
    return '$mappers people mapping this month · $zones places covered';
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
  String get statsWeeklyChartOffline => 'Weekly chart loads once connected';

  @override
  String uploadMilestone(int count) {
    return '$count uploads. Keep going!';
  }

  @override
  String get statsViewOnMap => 'View on map';

  @override
  String statsSinceDate(String date) {
    return 'since $date';
  }

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
  String get statsChartWeekTab => 'Week';

  @override
  String get statsChartMonthTab => 'Month';

  @override
  String get statsChartMonthEmpty =>
      'Monthly view appears after more active days';

  @override
  String get statsTerritoryDetails => 'See measurement details';

  @override
  String get statsTerritorySheetTitle => 'Your measurements';

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
  String get statsTerritoryWhatRecorded => 'Sensors used';

  @override
  String get statsTerritoryLightLabel => 'Light';

  @override
  String get statsTerritoryMotionLabel => 'Movement';

  @override
  String get statsTerritoryPressureLabel => 'Pressure';

  @override
  String get statsTerritoryMapCta =>
      'Tap any place on the map to see its readings';

  @override
  String sessionSummaryShareText(int gained, int total, String km2) {
    return 'I mapped +$gained new places today. $total total · $km2';
  }

  @override
  String sessionSummaryShareTextEmpty(String duration, int total, String km2) {
    return 'Mapped for $duration. $total places measured · $km2';
  }

  @override
  String get sensorLuxDark => 'Dark';

  @override
  String get sensorLuxIndoor => 'Dim';

  @override
  String get sensorLuxBright => 'Bright';

  @override
  String get sensorLuxDirect => 'Very bright';

  @override
  String get sensorMovementLow => 'Low';

  @override
  String get sensorMovementMid => 'Moderate';

  @override
  String get sensorMovementHigh => 'High';

  @override
  String get sensorMovementIntense => 'Very high';

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
  String serverWakingUp(int seconds) {
    return 'Waking the server · $seconds s';
  }

  @override
  String get permissionLostTitle => 'Location access off';

  @override
  String get permissionLostBody => 'The map stopped updating. Tap to fix.';

  @override
  String get permissionLostCta => 'Fix in Settings';

  @override
  String referralNeighborhoodHook(String neighborhood) {
    return 'Help measure $neighborhood.';
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
  String get sessionSummaryBadge => 'DONE';

  @override
  String get sessionSummaryZonesGainedLabel => 'NEW PLACES';

  @override
  String get sessionSummarySubline => 'added';

  @override
  String get sessionSummaryNoZonesLabel => 'YOUR READINGS';

  @override
  String get sessionSummaryWatermark => 'Mapped with GreenGains';

  @override
  String get sessionSummaryShareCta => 'Share';

  @override
  String sessionMilestoneHit(int milestone) {
    return '$milestone places.';
  }

  @override
  String get sessionStatArea => 'AREA';

  @override
  String get sessionStatDuration => 'TIME';

  @override
  String get sessionStatTotal => 'TOTAL';

  @override
  String get sessionStatUploads => 'SYNCS';

  @override
  String profileStreakToMilestone(int days, String unit, int milestone) {
    return '$days $unit to $milestone-$unit streak';
  }

  @override
  String statsMilestoneTarget(int target) {
    return '$target places';
  }

  @override
  String get statsActivitySection => 'YOUR WEEK';

  @override
  String statsVsPrevWeek(String delta) {
    return '$delta% vs prev week';
  }

  @override
  String get statsTerritorySection => 'YOUR CONTRIBUTION';

  @override
  String get mapTapHint => 'Tap a place to explore';

  @override
  String get sessionPersonalBest => 'Personal best';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get streakResetBanner => 'Streak reset.';

  @override
  String get statsKm2Unit => 'km²';

  @override
  String get statsHaUnit => 'ha';

  @override
  String get statsLast30DaysUnit => '/ 30';

  @override
  String get referralWaiting => 'Link shared. Nobody has joined yet.';

  @override
  String get referralFirstJoined => 'First person joined.';

  @override
  String get referralShareAgain => 'Share again';

  @override
  String referralShareText(String code) {
    return 'Join me on GreenGains: we measure light, pressure and movement in our streets. Invite code: $code';
  }

  @override
  String get onboardingHaveCode => 'Got an invite code?';

  @override
  String get onboardingCodeHint => 'Enter invite code (e.g. GG-XXXXX)';

  @override
  String get profileUnlockTitle => 'Your readings are being saved.';

  @override
  String get profileUnlockBody => 'Sign in to keep them across devices.';

  @override
  String get mapZeroStateTitle => 'The first place is a few steps away';

  @override
  String get mapZeroStateBody =>
      'Start tracking: the street appears on the map as soon as you move.';

  @override
  String get statsInsightLabel => 'THIS WEEK';

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
      other: '$count places nobody else has measured',
      one: '1 place nobody else has measured',
    );
    return '$_temp0';
  }
}
