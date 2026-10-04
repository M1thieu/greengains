import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Finally know your neighborhood.'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingFeature1Title.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do.'**
  String get onboardingFeature1Title;

  /// No description provided for @onboardingFeature2Title.
  ///
  /// In en, this message translates to:
  /// **'Private by default'**
  String get onboardingFeature2Title;

  /// No description provided for @onboardingFeature3Title.
  ///
  /// In en, this message translates to:
  /// **'See what\'s around you.'**
  String get onboardingFeature3Title;

  /// No description provided for @onboardingSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Your map starts here.'**
  String get onboardingSignInTitle;

  /// No description provided for @onboardingPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our {privacyPolicy} and {termsOfService}.'**
  String onboardingPrivacyNotice(String privacyPolicy, String termsOfService);

  /// No description provided for @signInWithGoogleLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogleLabel;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @buttonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get buttonNext;

  /// No description provided for @signInError.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled or failed'**
  String get signInError;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @homeStatArea.
  ///
  /// In en, this message translates to:
  /// **'{area} mapped'**
  String homeStatArea(String area);

  /// No description provided for @homeActionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get homeActionStart;

  /// No description provided for @homeActionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get homeActionStop;

  /// No description provided for @homeActionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get homeActionResume;

  /// No description provided for @startTracking.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking'**
  String get startTracking;

  /// No description provided for @stopTracking.
  ///
  /// In en, this message translates to:
  /// **'Stop Tracking'**
  String get stopTracking;

  /// No description provided for @trackingPaused.
  ///
  /// In en, this message translates to:
  /// **'Tracking Paused'**
  String get trackingPaused;

  /// No description provided for @lastUpload.
  ///
  /// In en, this message translates to:
  /// **'Last update: {time}'**
  String lastUpload(String time);

  /// No description provided for @totalUploads.
  ///
  /// In en, this message translates to:
  /// **'Total scans'**
  String get totalUploads;

  /// No description provided for @profileMemberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String profileMemberSince(String date);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get settingsLanguageFrench;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplay;

  /// No description provided for @settingsMobileData.
  ///
  /// In en, this message translates to:
  /// **'Use mobile data'**
  String get settingsMobileData;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @permissionLocationMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow location so your phone can map as you walk.'**
  String get permissionLocationMessage;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @buttonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get buttonCancel;

  /// No description provided for @buttonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get buttonClose;

  /// No description provided for @buttonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get buttonRetry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @profileUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileUserFallback;

  /// No description provided for @chipPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get chipPaused;

  /// No description provided for @semanticsCenterOnMe.
  ///
  /// In en, this message translates to:
  /// **'Center map on my location'**
  String get semanticsCenterOnMe;

  /// No description provided for @statsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statsToday;

  /// No description provided for @statsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get statsThisWeek;

  /// No description provided for @statsDaysActive.
  ///
  /// In en, this message translates to:
  /// **'Days Active'**
  String get statsDaysActive;

  /// No description provided for @statsAreasLabel.
  ///
  /// In en, this message translates to:
  /// **'places covered'**
  String get statsAreasLabel;

  /// No description provided for @statsDataPtsLabel.
  ///
  /// In en, this message translates to:
  /// **'readings'**
  String get statsDataPtsLabel;

  /// No description provided for @statsKmMapped.
  ///
  /// In en, this message translates to:
  /// **'km² covered'**
  String get statsKmMapped;

  /// No description provided for @statsBarCalloutUploads.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scan} other{{count} scans}}'**
  String statsBarCalloutUploads(int count);

  /// No description provided for @statsBarCalloutToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statsBarCalloutToday;

  /// No description provided for @statsBarCalloutBest.
  ///
  /// In en, this message translates to:
  /// **'Best day'**
  String get statsBarCalloutBest;

  /// No description provided for @statsBestDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Best day'**
  String get statsBestDayLabel;

  /// No description provided for @statsAvgPerDay.
  ///
  /// In en, this message translates to:
  /// **'Avg. per day'**
  String get statsAvgPerDay;

  /// No description provided for @statsWeeklyTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get statsWeeklyTargetLabel;

  /// No description provided for @statsWeeklyTargetComplete.
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get statsWeeklyTargetComplete;

  /// No description provided for @statsLocalLegendLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR NEIGHBORHOOD'**
  String get statsLocalLegendLabel;

  /// No description provided for @statsLocalLegendLeader.
  ///
  /// In en, this message translates to:
  /// **'You\'re the most active in your neighborhood this week'**
  String get statsLocalLegendLeader;

  /// No description provided for @statsLocalLegendRank.
  ///
  /// In en, this message translates to:
  /// **'#{rank} of {total} in your neighborhood this week'**
  String statsLocalLegendRank(int rank, int total);

  /// No description provided for @statsLocalLegendGap.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place to take the lead} other{{count} places to take the lead}}'**
  String statsLocalLegendGap(int count);

  /// No description provided for @statsImpactLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR IMPACT'**
  String get statsImpactLabel;

  /// No description provided for @statsImpactSolo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You\'re the only one who\'s been to 1 of your places} other{You\'re the only one who\'s been to {count} of your places}}'**
  String statsImpactSolo(int count);

  /// No description provided for @statsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get statsDetailTitle;

  /// No description provided for @statsCityBlocks.
  ///
  /// In en, this message translates to:
  /// **'~{count} city blocks covered'**
  String statsCityBlocks(int count);

  /// No description provided for @statsPersonalRecords.
  ///
  /// In en, this message translates to:
  /// **'Personal records'**
  String get statsPersonalRecords;

  /// No description provided for @statsRecordBestDay.
  ///
  /// In en, this message translates to:
  /// **'Best day'**
  String get statsRecordBestDay;

  /// No description provided for @statsRecordLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get statsRecordLongestStreak;

  /// No description provided for @statsRecordTotalUploads.
  ///
  /// In en, this message translates to:
  /// **'Total scans'**
  String get statsRecordTotalUploads;

  /// No description provided for @statsRecordFirstDay.
  ///
  /// In en, this message translates to:
  /// **'First mapping day'**
  String get statsRecordFirstDay;

  /// No description provided for @statsRecordBestSession.
  ///
  /// In en, this message translates to:
  /// **'Best session'**
  String get statsRecordBestSession;

  /// No description provided for @statsZoneExplainer.
  ///
  /// In en, this message translates to:
  /// **'A place is roughly one city block.'**
  String get statsZoneExplainer;

  /// No description provided for @statsUploadExplainer.
  ///
  /// In en, this message translates to:
  /// **'Light, heat and ground at the time of the scan.'**
  String get statsUploadExplainer;

  /// No description provided for @statsTabInDepth.
  ///
  /// In en, this message translates to:
  /// **'In depth'**
  String get statsTabInDepth;

  /// No description provided for @statsOpenDetails.
  ///
  /// In en, this message translates to:
  /// **'In depth'**
  String get statsOpenDetails;

  /// No description provided for @statsInDepth30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get statsInDepth30Days;

  /// No description provided for @statsHeatmapLess.
  ///
  /// In en, this message translates to:
  /// **'less'**
  String get statsHeatmapLess;

  /// No description provided for @statsHeatmapMore.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get statsHeatmapMore;

  /// No description provided for @statsHeatmapDayDetail.
  ///
  /// In en, this message translates to:
  /// **'{date} · {count} passes'**
  String statsHeatmapDayDetail(String date, int count);

  /// No description provided for @statsHeatmapNoUploads.
  ///
  /// In en, this message translates to:
  /// **'{date} · no scans'**
  String statsHeatmapNoUploads(String date);

  /// No description provided for @statsInDepthHabits.
  ///
  /// In en, this message translates to:
  /// **'Your habits'**
  String get statsInDepthHabits;

  /// No description provided for @statsInDepthActiveDays.
  ///
  /// In en, this message translates to:
  /// **'Active days'**
  String get statsInDepthActiveDays;

  /// No description provided for @statsInDepthAvgPerDay.
  ///
  /// In en, this message translates to:
  /// **'Avg / active day'**
  String get statsInDepthAvgPerDay;

  /// No description provided for @statsInDepthBestWeekday.
  ///
  /// In en, this message translates to:
  /// **'Best weekday'**
  String get statsInDepthBestWeekday;

  /// No description provided for @statsInDepthWhenYouMap.
  ///
  /// In en, this message translates to:
  /// **'When you scan'**
  String get statsInDepthWhenYouMap;

  /// No description provided for @statsDaysUnit.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get statsDaysUnit;

  /// No description provided for @statsCurrentStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get statsCurrentStreakLabel;

  /// No description provided for @statsLongestLabel.
  ///
  /// In en, this message translates to:
  /// **'Longest'**
  String get statsLongestLabel;

  /// No description provided for @statsAllTimeSection.
  ///
  /// In en, this message translates to:
  /// **'ALL TIME'**
  String get statsAllTimeSection;

  /// No description provided for @statsUploadsUnit.
  ///
  /// In en, this message translates to:
  /// **'scans'**
  String get statsUploadsUnit;

  /// No description provided for @statsBestWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Best week'**
  String get statsBestWeekLabel;

  /// No description provided for @statsQualitySection.
  ///
  /// In en, this message translates to:
  /// **'RELIABILITY'**
  String get statsQualitySection;

  /// No description provided for @statsQualityExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get statsQualityExcellent;

  /// No description provided for @statsQualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get statsQualityGood;

  /// No description provided for @statsQualityFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get statsQualityFair;

  /// No description provided for @statsQualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get statsQualityLow;

  /// No description provided for @statsQualitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'The higher, the more reliable your readings.'**
  String get statsQualitySubtitle;

  /// No description provided for @statsAvgPrefix.
  ///
  /// In en, this message translates to:
  /// **'avg'**
  String get statsAvgPrefix;

  /// No description provided for @infoTileQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Reliability'**
  String get infoTileQualityTitle;

  /// No description provided for @infoTilePersonalTitle.
  ///
  /// In en, this message translates to:
  /// **'Your area'**
  String get infoTilePersonalTitle;

  /// No description provided for @statsActivityTrend.
  ///
  /// In en, this message translates to:
  /// **'Your week'**
  String get statsActivityTrend;

  /// No description provided for @statsTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get statsTodayLabel;

  /// No description provided for @statsStartContributing.
  ///
  /// In en, this message translates to:
  /// **'No data yet.'**
  String get statsStartContributing;

  /// No description provided for @statsEmptyGoMap.
  ///
  /// In en, this message translates to:
  /// **'Enable tracking'**
  String get statsEmptyGoMap;

  /// No description provided for @statsLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your stats'**
  String get statsLoadErrorTitle;

  /// No description provided for @statsCollectingTitle.
  ///
  /// In en, this message translates to:
  /// **'Collecting'**
  String get statsCollectingTitle;

  /// No description provided for @tileInfoSamplesLabel.
  ///
  /// In en, this message translates to:
  /// **'readings'**
  String get tileInfoSamplesLabel;

  /// No description provided for @tileInfoDevicesLabel.
  ///
  /// In en, this message translates to:
  /// **'people'**
  String get tileInfoDevicesLabel;

  /// No description provided for @tileInfoQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Reliability'**
  String get tileInfoQualityLabel;

  /// No description provided for @tileInfoAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'area'**
  String get tileInfoAreaLabel;

  /// No description provided for @tileInfoPersonal.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get tileInfoPersonal;

  /// No description provided for @tileInfoCommunity.
  ///
  /// In en, this message translates to:
  /// **'Not yours yet'**
  String get tileInfoCommunity;

  /// No description provided for @tileOnlyYouMapped.
  ///
  /// In en, this message translates to:
  /// **'Only you\'ve been here'**
  String get tileOnlyYouMapped;

  /// No description provided for @tileInfoNoSensorData.
  ///
  /// In en, this message translates to:
  /// **'Location only, no readings here yet.'**
  String get tileInfoNoSensorData;

  /// No description provided for @noCoverageYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get noCoverageYet;

  /// No description provided for @startTrackingToMap.
  ///
  /// In en, this message translates to:
  /// **'Start tracking to fill your map'**
  String get startTrackingToMap;

  /// No description provided for @tilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tiles'**
  String tilesCount(int count);

  /// No description provided for @sensorUnitLux.
  ///
  /// In en, this message translates to:
  /// **'lx'**
  String get sensorUnitLux;

  /// No description provided for @sensorUnitHpa.
  ///
  /// In en, this message translates to:
  /// **'hPa'**
  String get sensorUnitHpa;

  /// No description provided for @sensorUnitMovement.
  ///
  /// In en, this message translates to:
  /// **'m/s²'**
  String get sensorUnitMovement;

  /// No description provided for @sensorUnitVibration.
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get sensorUnitVibration;

  /// No description provided for @sensorMovement.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get sensorMovement;

  /// No description provided for @sensorAcceleration.
  ///
  /// In en, this message translates to:
  /// **'Acceleration'**
  String get sensorAcceleration;

  /// No description provided for @sensorLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get sensorLight;

  /// No description provided for @sensorMagneticField.
  ///
  /// In en, this message translates to:
  /// **'Interference'**
  String get sensorMagneticField;

  /// No description provided for @sensorOrientation.
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get sensorOrientation;

  /// No description provided for @sensorAirPressure.
  ///
  /// In en, this message translates to:
  /// **'Air Pressure'**
  String get sensorAirPressure;

  /// No description provided for @sensorStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get sensorStatusConnecting;

  /// No description provided for @sensorStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get sensorStatusLive;

  /// No description provided for @sensorStatusLastReading.
  ///
  /// In en, this message translates to:
  /// **'Last reading'**
  String get sensorStatusLastReading;

  /// No description provided for @sensorStatusNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get sensorStatusNoData;

  /// No description provided for @lightDark.
  ///
  /// In en, this message translates to:
  /// **'Dark sky'**
  String get lightDark;

  /// No description provided for @lightDim.
  ///
  /// In en, this message translates to:
  /// **'Dim'**
  String get lightDim;

  /// No description provided for @lightNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get lightNormal;

  /// No description provided for @lightBright.
  ///
  /// In en, this message translates to:
  /// **'Bright'**
  String get lightBright;

  /// No description provided for @lightVeryBright.
  ///
  /// In en, this message translates to:
  /// **'Very Bright'**
  String get lightVeryBright;

  /// No description provided for @magnetVeryLow.
  ///
  /// In en, this message translates to:
  /// **'Very low'**
  String get magnetVeryLow;

  /// No description provided for @magnetNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get magnetNormal;

  /// No description provided for @magnetElevated.
  ///
  /// In en, this message translates to:
  /// **'Elevated'**
  String get magnetElevated;

  /// No description provided for @magnetHighNearMetal.
  ///
  /// In en, this message translates to:
  /// **'High. Near metal.'**
  String get magnetHighNearMetal;

  /// No description provided for @daysActive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysActive(int count);

  /// No description provided for @trackingErrorUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update tracking. Please try again.'**
  String get trackingErrorUpdateFailed;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsThemeAuto;

  /// No description provided for @settingsTracking.
  ///
  /// In en, this message translates to:
  /// **'Mapping'**
  String get settingsTracking;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegal;

  /// No description provided for @settingsDataTransparency.
  ///
  /// In en, this message translates to:
  /// **'Data Transparency'**
  String get settingsDataTransparency;

  /// No description provided for @settingsExportData.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get settingsExportData;

  /// No description provided for @settingsExportDataFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export your data. Try again later.'**
  String get settingsExportDataFailed;

  /// No description provided for @referralInviteDescription.
  ///
  /// In en, this message translates to:
  /// **'Every friend who joins adds places to the map.'**
  String get referralInviteDescription;

  /// No description provided for @layerMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get layerMine;

  /// No description provided for @layerAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get layerAll;

  /// No description provided for @referralShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get referralShareLink;

  /// No description provided for @referralConversions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No friends joined yet} =1{1 friend joined} other{{count} friends joined}}'**
  String referralConversions(int count);

  /// No description provided for @statsWeeklyTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} this week'**
  String statsWeeklyTotal(int count);

  /// No description provided for @statsMilestoneElite.
  ///
  /// In en, this message translates to:
  /// **'All milestones reached.'**
  String get statsMilestoneElite;

  /// No description provided for @statsMilestoneRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more place} other{{count} more places}}'**
  String statsMilestoneRemaining(int count);

  /// No description provided for @batteryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep running in the background'**
  String get batteryDialogTitle;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Sensor Diagnostics'**
  String get settingsDiagnostics;

  /// No description provided for @settingsDiagnosticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Live readings from your device sensors'**
  String get settingsDiagnosticsDesc;

  /// No description provided for @sensorLiveSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Around you'**
  String get sensorLiveSheetTitle;

  /// No description provided for @transparencyNothingElse.
  ///
  /// In en, this message translates to:
  /// **'No precise route. No microphone. No contacts. Nothing else.'**
  String get transparencyNothingElse;

  /// No description provided for @transparencyLastUpload.
  ///
  /// In en, this message translates to:
  /// **'Last update'**
  String get transparencyLastUpload;

  /// No description provided for @transparencyNoUploadYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing sent yet.'**
  String get transparencyNoUploadYet;

  /// No description provided for @tileQualityExcellent.
  ///
  /// In en, this message translates to:
  /// **'Well covered'**
  String get tileQualityExcellent;

  /// No description provided for @tileQualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good coverage'**
  String get tileQualityGood;

  /// No description provided for @tileQualityFair.
  ///
  /// In en, this message translates to:
  /// **'Pass here again'**
  String get tileQualityFair;

  /// No description provided for @tileQualityStaling.
  ///
  /// In en, this message translates to:
  /// **'Getting old'**
  String get tileQualityStaling;

  /// No description provided for @tileDecayWarning.
  ///
  /// In en, this message translates to:
  /// **'Info from {days} days ago. Come back here to update it.'**
  String tileDecayWarning(int days);

  /// No description provided for @tileDecayHint.
  ///
  /// In en, this message translates to:
  /// **'Updated {days} days ago.'**
  String tileDecayHint(int days);

  /// No description provided for @legendHighLabel.
  ///
  /// In en, this message translates to:
  /// **'Very reliable'**
  String get legendHighLabel;

  /// No description provided for @legendHighSub.
  ///
  /// In en, this message translates to:
  /// **'Lots of readings here'**
  String get legendHighSub;

  /// No description provided for @legendMidLabel.
  ///
  /// In en, this message translates to:
  /// **'Fairly reliable'**
  String get legendMidLabel;

  /// No description provided for @legendMidSub.
  ///
  /// In en, this message translates to:
  /// **'A few readings. Come back to add more.'**
  String get legendMidSub;

  /// No description provided for @legendLowLabel.
  ///
  /// In en, this message translates to:
  /// **'Not very reliable'**
  String get legendLowLabel;

  /// No description provided for @legendLowSub.
  ///
  /// In en, this message translates to:
  /// **'Barely any data. Needs more passes.'**
  String get legendLowSub;

  /// No description provided for @legendCommunitySub.
  ///
  /// In en, this message translates to:
  /// **'Recorded by other people'**
  String get legendCommunitySub;

  /// No description provided for @permissionPrimingBattery.
  ///
  /// In en, this message translates to:
  /// **'Smart battery'**
  String get permissionPrimingBattery;

  /// No description provided for @permissionPrimingCollects.
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get permissionPrimingCollects;

  /// No description provided for @onboardingSocialProof.
  ///
  /// In en, this message translates to:
  /// **'{count} people are already filling in their neighborhood map'**
  String onboardingSocialProof(int count);

  /// No description provided for @statsWeeklyChartOffline.
  ///
  /// In en, this message translates to:
  /// **'Weekly chart loads once connected'**
  String get statsWeeklyChartOffline;

  /// No description provided for @statsViewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get statsViewOnMap;

  /// No description provided for @tileFirstMapped.
  ///
  /// In en, this message translates to:
  /// **'First visit {date}'**
  String tileFirstMapped(String date);

  /// No description provided for @statsSinceDate.
  ///
  /// In en, this message translates to:
  /// **'since {date}'**
  String statsSinceDate(String date);

  /// No description provided for @statsStreakNewRecord.
  ///
  /// In en, this message translates to:
  /// **'New record'**
  String get statsStreakNewRecord;

  /// No description provided for @statsChartWeekTab.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statsChartWeekTab;

  /// No description provided for @statsChartMonthTab.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statsChartMonthTab;

  /// No description provided for @statsChartMonthEmpty.
  ///
  /// In en, this message translates to:
  /// **'Walk more days to unlock monthly view'**
  String get statsChartMonthEmpty;

  /// No description provided for @statsBarCalloutDetail.
  ///
  /// In en, this message translates to:
  /// **'~{count, plural, =1{1 scan} other{{count} scans}} · light · movement · weather'**
  String statsBarCalloutDetail(int count);

  /// No description provided for @statsTerritoryDetails.
  ///
  /// In en, this message translates to:
  /// **'See territory details'**
  String get statsTerritoryDetails;

  /// No description provided for @statsTerritorySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Your territory'**
  String get statsTerritorySheetTitle;

  /// No description provided for @statsTerritoryZones.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place} other{{count} places}}'**
  String statsTerritoryZones(int count);

  /// No description provided for @statsTerritoryWhatRecorded.
  ///
  /// In en, this message translates to:
  /// **'What your phone measured here'**
  String get statsTerritoryWhatRecorded;

  /// No description provided for @statsTerritoryLightLabel.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get statsTerritoryLightLabel;

  /// No description provided for @statsTerritoryLightDesc.
  ///
  /// In en, this message translates to:
  /// **'How bright or dark this place usually is: indoors, outdoors, shaded'**
  String get statsTerritoryLightDesc;

  /// No description provided for @statsTerritoryMotionLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get statsTerritoryMotionLabel;

  /// No description provided for @statsTerritoryMotionDesc.
  ///
  /// In en, this message translates to:
  /// **'How lively this place usually feels: people, traffic, movement'**
  String get statsTerritoryMotionDesc;

  /// No description provided for @statsTerritoryPressureLabel.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get statsTerritoryPressureLabel;

  /// No description provided for @statsTerritoryPressureDesc.
  ///
  /// In en, this message translates to:
  /// **'Air pressure here. It follows the weather.'**
  String get statsTerritoryPressureDesc;

  /// No description provided for @statsTerritoryMapCta.
  ///
  /// In en, this message translates to:
  /// **'Tap any place on the map to see its readings'**
  String get statsTerritoryMapCta;

  /// No description provided for @tileCommunityClaimCta.
  ///
  /// In en, this message translates to:
  /// **'Walk through here to make it yours'**
  String get tileCommunityClaimCta;

  /// No description provided for @sensorLuxDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get sensorLuxDark;

  /// No description provided for @sensorLuxIndoor.
  ///
  /// In en, this message translates to:
  /// **'Dim'**
  String get sensorLuxIndoor;

  /// No description provided for @sensorLuxBright.
  ///
  /// In en, this message translates to:
  /// **'Bright'**
  String get sensorLuxBright;

  /// No description provided for @sensorLuxDirect.
  ///
  /// In en, this message translates to:
  /// **'In sunlight'**
  String get sensorLuxDirect;

  /// No description provided for @sensorMovementLow.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get sensorMovementLow;

  /// No description provided for @sensorMovementMid.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sensorMovementMid;

  /// No description provided for @sensorMovementHigh.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get sensorMovementHigh;

  /// No description provided for @sensorMovementIntense.
  ///
  /// In en, this message translates to:
  /// **'Heavy traffic'**
  String get sensorMovementIntense;

  /// No description provided for @sensorHpaLow.
  ///
  /// In en, this message translates to:
  /// **'Clear air'**
  String get sensorHpaLow;

  /// No description provided for @sensorHpaMid.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get sensorHpaMid;

  /// No description provided for @sensorHpaHigh.
  ///
  /// In en, this message translates to:
  /// **'Heavy air'**
  String get sensorHpaHigh;

  /// No description provided for @sensorAccelStill.
  ///
  /// In en, this message translates to:
  /// **'Barely moving'**
  String get sensorAccelStill;

  /// No description provided for @sensorAccelWalk.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get sensorAccelWalk;

  /// No description provided for @sensorAccelActive.
  ///
  /// In en, this message translates to:
  /// **'Running / cycling'**
  String get sensorAccelActive;

  /// No description provided for @sensorAccelHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy movement'**
  String get sensorAccelHeavy;

  /// No description provided for @sensorGyroStill.
  ///
  /// In en, this message translates to:
  /// **'Holding still'**
  String get sensorGyroStill;

  /// No description provided for @sensorGyroSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow turn'**
  String get sensorGyroSlow;

  /// No description provided for @sensorGyroFast.
  ///
  /// In en, this message translates to:
  /// **'Fast rotation'**
  String get sensorGyroFast;

  /// No description provided for @tileVibrationCalm.
  ///
  /// In en, this message translates to:
  /// **'Very still'**
  String get tileVibrationCalm;

  /// No description provided for @tileVibrationLight.
  ///
  /// In en, this message translates to:
  /// **'Light activity'**
  String get tileVibrationLight;

  /// No description provided for @tileVibrationActive.
  ///
  /// In en, this message translates to:
  /// **'Lots of movement'**
  String get tileVibrationActive;

  /// No description provided for @tileVibrationHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy traffic'**
  String get tileVibrationHeavy;

  /// No description provided for @tileSurfaceSmooth.
  ///
  /// In en, this message translates to:
  /// **'smooth ground'**
  String get tileSurfaceSmooth;

  /// No description provided for @tileSurfaceRough.
  ///
  /// In en, this message translates to:
  /// **'uneven ground'**
  String get tileSurfaceRough;

  /// No description provided for @tileSurfaceHeavy.
  ///
  /// In en, this message translates to:
  /// **'very rough'**
  String get tileSurfaceHeavy;

  /// No description provided for @tileCondLightDark.
  ///
  /// In en, this message translates to:
  /// **'dark'**
  String get tileCondLightDark;

  /// No description provided for @tileCondLightDim.
  ///
  /// In en, this message translates to:
  /// **'dim'**
  String get tileCondLightDim;

  /// No description provided for @tileCondLightBright.
  ///
  /// In en, this message translates to:
  /// **'bright'**
  String get tileCondLightBright;

  /// No description provided for @tileCondLightShaded.
  ///
  /// In en, this message translates to:
  /// **'shaded'**
  String get tileCondLightShaded;

  /// No description provided for @tileCondLightPartial.
  ///
  /// In en, this message translates to:
  /// **'overcast'**
  String get tileCondLightPartial;

  /// No description provided for @tileCondLightIntense.
  ///
  /// In en, this message translates to:
  /// **'very bright'**
  String get tileCondLightIntense;

  /// No description provided for @tileCondActivityCalm.
  ///
  /// In en, this message translates to:
  /// **'quiet'**
  String get tileCondActivityCalm;

  /// No description provided for @tileCondActivityModerate.
  ///
  /// In en, this message translates to:
  /// **'moderate'**
  String get tileCondActivityModerate;

  /// No description provided for @tileCondActivityActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get tileCondActivityActive;

  /// No description provided for @tileCondActivityBusy.
  ///
  /// In en, this message translates to:
  /// **'busy'**
  String get tileCondActivityBusy;

  /// No description provided for @sessionCharacterDarkSky.
  ///
  /// In en, this message translates to:
  /// **'DARK SKY'**
  String get sessionCharacterDarkSky;

  /// No description provided for @sessionCharacterBrightCity.
  ///
  /// In en, this message translates to:
  /// **'LIT STREETS'**
  String get sessionCharacterBrightCity;

  /// No description provided for @sessionCharacterHotRoute.
  ///
  /// In en, this message translates to:
  /// **'HOT OUTING'**
  String get sessionCharacterHotRoute;

  /// No description provided for @sessionCharacterRoughRoad.
  ///
  /// In en, this message translates to:
  /// **'UNEVEN GROUND'**
  String get sessionCharacterRoughRoad;

  /// No description provided for @sessionCharacterSunExposed.
  ///
  /// In en, this message translates to:
  /// **'OPEN SKY'**
  String get sessionCharacterSunExposed;

  /// No description provided for @mapperRoleContributor.
  ///
  /// In en, this message translates to:
  /// **'Contributor'**
  String get mapperRoleContributor;

  /// No description provided for @mapperRolePioneer.
  ///
  /// In en, this message translates to:
  /// **'Pioneer'**
  String get mapperRolePioneer;

  /// No description provided for @mapperRoleExplorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get mapperRoleExplorer;

  /// No description provided for @mapperRoleCartographer.
  ///
  /// In en, this message translates to:
  /// **'Cartographer'**
  String get mapperRoleCartographer;

  /// No description provided for @mapperRoleCityMapper.
  ///
  /// In en, this message translates to:
  /// **'City Mapper'**
  String get mapperRoleCityMapper;

  /// No description provided for @mapperRoleUrbanScientist.
  ///
  /// In en, this message translates to:
  /// **'Urban Scientist'**
  String get mapperRoleUrbanScientist;

  /// No description provided for @serverWakingUp.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get serverWakingUp;

  /// No description provided for @permissionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Location access off'**
  String get permissionLostTitle;

  /// No description provided for @permissionLostCta.
  ///
  /// In en, this message translates to:
  /// **'Fix in Settings'**
  String get permissionLostCta;

  /// No description provided for @referralNeighborhoodHook.
  ///
  /// In en, this message translates to:
  /// **'Invite your neighbors to fill in the map of {neighborhood}.'**
  String referralNeighborhoodHook(String neighborhood);

  /// No description provided for @onboardingActivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get onboardingActivateTitle;

  /// No description provided for @onboardingActivateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone reads the environment around you as you go. Your route is never stored.'**
  String get onboardingActivateSubtitle;

  /// No description provided for @onboardingActivateCta.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardingActivateCta;

  /// No description provided for @onboardingPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location is needed to fill your map.'**
  String get onboardingPermissionDenied;

  /// No description provided for @profileTileAreaCells.
  ///
  /// In en, this message translates to:
  /// **'places'**
  String get profileTileAreaCells;

  /// No description provided for @profileStatCityBlocks.
  ///
  /// In en, this message translates to:
  /// **'city blocks'**
  String get profileStatCityBlocks;

  /// No description provided for @profileStreakToMilestone.
  ///
  /// In en, this message translates to:
  /// **'{days} {unit} to {milestone}-{unit} streak'**
  String profileStreakToMilestone(int days, String unit, int milestone);

  /// No description provided for @profileUploadsExplanation.
  ///
  /// In en, this message translates to:
  /// **'A scan is what your phone measures at one place.'**
  String get profileUploadsExplanation;

  /// No description provided for @profileDaysExplanation.
  ///
  /// In en, this message translates to:
  /// **'Days your phone scanned at least once.'**
  String get profileDaysExplanation;

  /// No description provided for @profileZonesExplanation.
  ///
  /// In en, this message translates to:
  /// **'A place is roughly one city block. Tap the map to see them.'**
  String get profileZonesExplanation;

  /// No description provided for @profileSeeInStats.
  ///
  /// In en, this message translates to:
  /// **'See in Stats'**
  String get profileSeeInStats;

  /// No description provided for @profileViewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on Map'**
  String get profileViewOnMap;

  /// No description provided for @statsActivitySection.
  ///
  /// In en, this message translates to:
  /// **'YOUR WEEK'**
  String get statsActivitySection;

  /// No description provided for @statsVsPrevWeek.
  ///
  /// In en, this message translates to:
  /// **'{delta}% vs prev week'**
  String statsVsPrevWeek(String delta);

  /// No description provided for @statsTerritorySection.
  ///
  /// In en, this message translates to:
  /// **'YOUR NEIGHBORHOOD'**
  String get statsTerritorySection;

  /// No description provided for @mapTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a place to explore'**
  String get mapTapHint;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Your account and all your data will be erased. This can\'t be undone.'**
  String get settingsDeleteAccountWarning;

  /// No description provided for @settingsDeleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDeleteAccountConfirm;

  /// No description provided for @streakResetBanner.
  ///
  /// In en, this message translates to:
  /// **'Streak reset. Start fresh today.'**
  String get streakResetBanner;

  /// No description provided for @statsEmptyLockLight.
  ///
  /// In en, this message translates to:
  /// **'Light: dark sky at night, sunlight by day'**
  String get statsEmptyLockLight;

  /// No description provided for @statsEmptyLockMovement.
  ///
  /// In en, this message translates to:
  /// **'Activity: how lively each place feels'**
  String get statsEmptyLockMovement;

  /// No description provided for @statsEmptyLockPressure.
  ///
  /// In en, this message translates to:
  /// **'Weather: heat and pressure around you'**
  String get statsEmptyLockPressure;

  /// No description provided for @statsKm2Unit.
  ///
  /// In en, this message translates to:
  /// **'km²'**
  String get statsKm2Unit;

  /// No description provided for @statsLast30DaysUnit.
  ///
  /// In en, this message translates to:
  /// **'/ 30'**
  String get statsLast30DaysUnit;

  /// No description provided for @referralWaiting.
  ///
  /// In en, this message translates to:
  /// **'Link shared. No one yet. You might be the first in your neighborhood.'**
  String get referralWaiting;

  /// No description provided for @referralFirstJoined.
  ///
  /// In en, this message translates to:
  /// **'First person joined.'**
  String get referralFirstJoined;

  /// No description provided for @referralShareAgain.
  ///
  /// In en, this message translates to:
  /// **'Share again'**
  String get referralShareAgain;

  /// No description provided for @referralShareText.
  ///
  /// In en, this message translates to:
  /// **'Join me on GreenGains: we\'re mapping light, weather and street conditions around us. My code: {code}'**
  String referralShareText(String code);

  /// No description provided for @onboardingHaveCode.
  ///
  /// In en, this message translates to:
  /// **'Got an invite code?'**
  String get onboardingHaveCode;

  /// No description provided for @onboardingCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code (e.g. GG-XXXXX)'**
  String get onboardingCodeHint;

  /// No description provided for @profileUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Your map is saving.'**
  String get profileUnlockTitle;

  /// No description provided for @mapZeroStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first place is one walk away'**
  String get mapZeroStateTitle;

  /// No description provided for @insightNoData.
  ///
  /// In en, this message translates to:
  /// **'Not enough readings here yet.'**
  String get insightNoData;

  /// No description provided for @insightNormal.
  ///
  /// In en, this message translates to:
  /// **'Nothing unusual detected here.'**
  String get insightNormal;

  /// No description provided for @insightRouteHeader.
  ///
  /// In en, this message translates to:
  /// **'YOUR OUTING'**
  String get insightRouteHeader;

  /// No description provided for @insightLightPristine.
  ///
  /// In en, this message translates to:
  /// **'Very little artificial light here.'**
  String get insightLightPristine;

  /// No description provided for @insightLightLow.
  ///
  /// In en, this message translates to:
  /// **'Naturally dark here. Good for winding down if you come home this way.'**
  String get insightLightLow;

  /// No description provided for @insightLightModerate.
  ///
  /// In en, this message translates to:
  /// **'Some sky glow. Enough artificial light to affect your body clock over time.'**
  String get insightLightModerate;

  /// No description provided for @insightLightHigh.
  ///
  /// In en, this message translates to:
  /// **'Bright at night, like a lit room. Not ideal before sleep.'**
  String get insightLightHigh;

  /// No description provided for @insightLightSevere.
  ///
  /// In en, this message translates to:
  /// **'Very bright at night. Your body thinks it\'s still daytime here.'**
  String get insightLightSevere;

  /// No description provided for @insightSunShaded.
  ///
  /// In en, this message translates to:
  /// **'Shaded and cool.'**
  String get insightSunShaded;

  /// No description provided for @insightSunPartial.
  ///
  /// In en, this message translates to:
  /// **'Normal outdoor conditions.'**
  String get insightSunPartial;

  /// No description provided for @insightSunBright.
  ///
  /// In en, this message translates to:
  /// **'Sunny spot.'**
  String get insightSunBright;

  /// No description provided for @insightSunIntense.
  ///
  /// In en, this message translates to:
  /// **'Strong direct sun. Worth planning water or shade here in summer.'**
  String get insightSunIntense;

  /// No description provided for @insightSurfaceSmooth.
  ///
  /// In en, this message translates to:
  /// **'Smooth ground.'**
  String get insightSurfaceSmooth;

  /// No description provided for @insightSurfaceNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal ground.'**
  String get insightSurfaceNormal;

  /// No description provided for @insightSurfaceRough.
  ///
  /// In en, this message translates to:
  /// **'Uneven ground.'**
  String get insightSurfaceRough;

  /// No description provided for @insightSurfacePoor.
  ///
  /// In en, this message translates to:
  /// **'Very uneven ground.'**
  String get insightSurfacePoor;

  /// No description provided for @insightHeatExposed.
  ///
  /// In en, this message translates to:
  /// **'Warmer than the streets around.'**
  String get insightHeatExposed;

  /// No description provided for @insightSessionDarkSky.
  ///
  /// In en, this message translates to:
  /// **'Little artificial light during your outing.'**
  String get insightSessionDarkSky;

  /// No description provided for @insightSessionBrightCity.
  ///
  /// In en, this message translates to:
  /// **'Brightly lit at night during your outing.'**
  String get insightSessionBrightCity;

  /// No description provided for @insightSessionRoughRoute.
  ///
  /// In en, this message translates to:
  /// **'Uneven ground during your outing.'**
  String get insightSessionRoughRoute;

  /// No description provided for @insightSessionHotRoute.
  ///
  /// In en, this message translates to:
  /// **'It was hot during your outing.'**
  String get insightSessionHotRoute;

  /// No description provided for @statsInsightLabel.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get statsInsightLabel;

  /// No description provided for @statsInsightRoughest.
  ///
  /// In en, this message translates to:
  /// **'Most uneven street: {street} (more than {pct}% of your outings)'**
  String statsInsightRoughest(String street, int pct);

  /// No description provided for @statsInsightNewZones.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new place this week} other{{count} new places this week}}'**
  String statsInsightNewZones(int count);

  /// No description provided for @statsInsightSolo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place only you\'ve ever been} other{{count} places only you\'ve ever been}}'**
  String statsInsightSolo(int count);

  /// No description provided for @statsInsightBrightest.
  ///
  /// In en, this message translates to:
  /// **'Most lit-up spot: {street}'**
  String statsInsightBrightest(String street);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
