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

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone measures light, pressure and movement along the streets you pass.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingFeature1Title.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do.'**
  String get onboardingFeature1Title;

  /// No description provided for @onboardingFeature1Description.
  ///
  /// In en, this message translates to:
  /// **'Start once, carry your phone. Your map builds itself.'**
  String get onboardingFeature1Description;

  /// No description provided for @onboardingFeature2Title.
  ///
  /// In en, this message translates to:
  /// **'Private by default'**
  String get onboardingFeature2Title;

  /// No description provided for @onboardingFeature2Description.
  ///
  /// In en, this message translates to:
  /// **'Your route is never stored. Readings are anonymous before they leave your phone.'**
  String get onboardingFeature2Description;

  /// No description provided for @onboardingFeature3Title.
  ///
  /// In en, this message translates to:
  /// **'See what\'s around you.'**
  String get onboardingFeature3Title;

  /// No description provided for @onboardingFeature3Description.
  ///
  /// In en, this message translates to:
  /// **'Light, pressure and movement, measured wherever you go.'**
  String get onboardingFeature3Description;

  /// No description provided for @onboardingSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Your readings start here.'**
  String get onboardingSignInTitle;

  /// No description provided for @onboardingSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your readings across devices.'**
  String get onboardingSignInSubtitle;

  /// No description provided for @onboardingPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our {privacyPolicy} and {termsOfService}.'**
  String onboardingPrivacyNotice(String privacyPolicy, String termsOfService);

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

  /// No description provided for @buttonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get buttonPrevious;

  /// No description provided for @buttonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get buttonNext;

  /// No description provided for @signInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get signInSuccess;

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

  /// No description provided for @homeStatToday.
  ///
  /// In en, this message translates to:
  /// **'+{count} today'**
  String homeStatToday(int count);

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

  /// No description provided for @trackingPaused.
  ///
  /// In en, this message translates to:
  /// **'Tracking Paused'**
  String get trackingPaused;

  /// No description provided for @lastUpload.
  ///
  /// In en, this message translates to:
  /// **'Last upload: {time}'**
  String lastUpload(String time);

  /// No description provided for @totalUploads.
  ///
  /// In en, this message translates to:
  /// **'Total Uploads'**
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

  /// No description provided for @settingsMobileData.
  ///
  /// In en, this message translates to:
  /// **'Mobile Data Upload'**
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

  /// No description provided for @buttonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get buttonClose;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

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

  /// No description provided for @homeSessionZones.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Mapping} =1{+1 new place} other{+{count} new places}}'**
  String homeSessionZones(int count);

  /// No description provided for @uploadSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Map updated!'**
  String get uploadSuccessMessage;

  /// No description provided for @uploadSuccessNewZone.
  ///
  /// In en, this message translates to:
  /// **'New place measured · {count} in total'**
  String uploadSuccessNewZone(int count);

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
  /// **'data points'**
  String get statsDataPtsLabel;

  /// No description provided for @statsKmMapped.
  ///
  /// In en, this message translates to:
  /// **'Area covered'**
  String get statsKmMapped;

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

  /// No description provided for @statsWeeklyTargetComplete.
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get statsWeeklyTargetComplete;

  /// No description provided for @statsImpactLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR IMPACT'**
  String get statsImpactLabel;

  /// No description provided for @statsImpactSolo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place nobody else has measured} other{{count} places nobody else has measured}}'**
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
  /// **'1 place ≈ {area}'**
  String statsZoneExplainer(String area);

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
  /// **'{date} · no uploads'**
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
  /// **'When you map'**
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
  /// **'SIGNAL QUALITY'**
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
  /// **'GPS accuracy, steadiness and sensor exposure'**
  String get statsQualitySubtitle;

  /// No description provided for @statsAvgPrefix.
  ///
  /// In en, this message translates to:
  /// **'avg'**
  String get statsAvgPrefix;

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

  /// No description provided for @statsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your measurements show up here after the first upload.'**
  String get statsEmptyDescription;

  /// No description provided for @statsEmptyGoMap.
  ///
  /// In en, this message translates to:
  /// **'Enable tracking'**
  String get statsEmptyGoMap;

  /// No description provided for @tileInfoQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get tileInfoQualityLabel;

  /// No description provided for @tileInfoPersonal.
  ///
  /// In en, this message translates to:
  /// **'You measured here'**
  String get tileInfoPersonal;

  /// No description provided for @tileInfoCommunity.
  ///
  /// In en, this message translates to:
  /// **'Measured by the community'**
  String get tileInfoCommunity;

  /// No description provided for @tileOnlyYouMapped.
  ///
  /// In en, this message translates to:
  /// **'Only you\'ve been here'**
  String get tileOnlyYouMapped;

  /// No description provided for @mapLayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Map layer'**
  String get mapLayerTitle;

  /// No description provided for @mapLayerQuality.
  ///
  /// In en, this message translates to:
  /// **'Data quality'**
  String get mapLayerQuality;

  /// No description provided for @tileContributors.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 contributor} other{{count} contributors}}'**
  String tileContributors(int count);

  /// No description provided for @tileMeasurements.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 measurement} other{{count} measurements}}'**
  String tileMeasurements(int count);

  /// No description provided for @tileInfoNoSensorData.
  ///
  /// In en, this message translates to:
  /// **'Location only. No sensor readings for this spot.'**
  String get tileInfoNoSensorData;

  /// No description provided for @noCoverageYet.
  ///
  /// In en, this message translates to:
  /// **'No coverage yet'**
  String get noCoverageYet;

  /// No description provided for @startTrackingToMap.
  ///
  /// In en, this message translates to:
  /// **'Start tracking to map your area'**
  String get startTrackingToMap;

  /// No description provided for @tilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tiles'**
  String tilesCount(int count);

  /// No description provided for @sensorLiveReadings.
  ///
  /// In en, this message translates to:
  /// **'What\'s around you'**
  String get sensorLiveReadings;

  /// No description provided for @sensorLiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Light, movement and pressure, live.'**
  String get sensorLiveSubtitle;

  /// No description provided for @sensorAroundYou.
  ///
  /// In en, this message translates to:
  /// **'Around You'**
  String get sensorAroundYou;

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
  /// **'Magnetic field'**
  String get sensorMagneticField;

  /// No description provided for @sensorWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get sensorWifi;

  /// No description provided for @sensorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get sensorTemperature;

  /// No description provided for @sensorHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get sensorHumidity;

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
  /// **'Dark'**
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

  /// No description provided for @lightDarkHint.
  ///
  /// In en, this message translates to:
  /// **'Night, or sensor covered'**
  String get lightDarkHint;

  /// No description provided for @lightDimHint.
  ///
  /// In en, this message translates to:
  /// **'Low ambient light'**
  String get lightDimHint;

  /// No description provided for @lightNormalHint.
  ///
  /// In en, this message translates to:
  /// **'Typical indoor daylight'**
  String get lightNormalHint;

  /// No description provided for @lightBrightHint.
  ///
  /// In en, this message translates to:
  /// **'Near a window or outdoors'**
  String get lightBrightHint;

  /// No description provided for @lightVeryBrightHint.
  ///
  /// In en, this message translates to:
  /// **'Full daylight, outdoors'**
  String get lightVeryBrightHint;

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
  /// **'Very high'**
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

  /// No description provided for @settingsMobileDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload over LTE/5G when needed'**
  String get settingsMobileDataDescription;

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

  /// No description provided for @settingsDataDeletion.
  ///
  /// In en, this message translates to:
  /// **'Request Data Deletion'**
  String get settingsDataDeletion;

  /// No description provided for @settingsExportData.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get settingsExportData;

  /// No description provided for @settingsExportDataPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your export…'**
  String get settingsExportDataPreparing;

  /// No description provided for @settingsExportDataFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export your data. Try again later.'**
  String get settingsExportDataFailed;

  /// No description provided for @referralInviteDescription.
  ///
  /// In en, this message translates to:
  /// **'Every person you invite measures other places.'**
  String get referralInviteDescription;

  /// No description provided for @layerMine.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get layerMine;

  /// No description provided for @layerAll.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
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

  /// No description provided for @statsMilestoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Next milestone'**
  String get statsMilestoneLabel;

  /// No description provided for @statsMilestoneElite.
  ///
  /// In en, this message translates to:
  /// **'All milestones reached.'**
  String get statsMilestoneElite;

  /// No description provided for @statsMilestoneRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place to go} other{{count} places to go}}'**
  String statsMilestoneRemaining(int count);

  /// No description provided for @batteryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep mapping'**
  String get batteryDialogTitle;

  /// No description provided for @batteryDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Disable battery optimization so the app keeps mapping in the background.'**
  String get batteryDialogBody;

  /// No description provided for @batteryDialogBodyBold.
  ///
  /// In en, this message translates to:
  /// **'Disable \"Battery Optimization\" for GreenGains on the next screen.'**
  String get batteryDialogBodyBold;

  /// No description provided for @batteryDialogDismissForever.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get batteryDialogDismissForever;

  /// No description provided for @batteryDialogLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get batteryDialogLater;

  /// No description provided for @batteryDialogAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow Background Run'**
  String get batteryDialogAllow;

  /// No description provided for @batteryDialogError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open battery settings'**
  String get batteryDialogError;

  /// No description provided for @batteryDialogOemXiaomiHint.
  ///
  /// In en, this message translates to:
  /// **'Also on Xiaomi/Redmi: enable AutoStart in Settings → Apps → Manage apps → GreenGains → AutoStart'**
  String get batteryDialogOemXiaomiHint;

  /// No description provided for @batteryDialogOemHuaweiHint.
  ///
  /// In en, this message translates to:
  /// **'Also on Huawei/Honor: open Settings → Battery → App launch, set GreenGains to manual with all toggles on'**
  String get batteryDialogOemHuaweiHint;

  /// No description provided for @batteryDialogOemSamsungHint.
  ///
  /// In en, this message translates to:
  /// **'Also on Samsung: set GreenGains to Unrestricted in Settings → Battery → Background usage limits'**
  String get batteryDialogOemSamsungHint;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Sensor Diagnostics'**
  String get settingsDiagnostics;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @sensorLiveSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'What you\'re measuring'**
  String get sensorLiveSheetTitle;

  /// No description provided for @transparencyNothingElse.
  ///
  /// In en, this message translates to:
  /// **'No precise route. No microphone. No contacts. Nothing else.'**
  String get transparencyNothingElse;

  /// No description provided for @transparencyLastUpload.
  ///
  /// In en, this message translates to:
  /// **'Last upload'**
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
  /// **'Few readings'**
  String get tileQualityFair;

  /// No description provided for @tileQualityStaling.
  ///
  /// In en, this message translates to:
  /// **'Staling'**
  String get tileQualityStaling;

  /// No description provided for @permissionPrimingBattery.
  ///
  /// In en, this message translates to:
  /// **'Smart battery'**
  String get permissionPrimingBattery;

  /// No description provided for @permissionPrimingBatteryDesc.
  ///
  /// In en, this message translates to:
  /// **'Adapts automatically in the background.'**
  String get permissionPrimingBatteryDesc;

  /// No description provided for @permissionPrimingCollects.
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get permissionPrimingCollects;

  /// No description provided for @permissionPrimingCollectsDesc.
  ///
  /// In en, this message translates to:
  /// **'Light, movement and pressure only. Never your route or identity.'**
  String get permissionPrimingCollectsDesc;

  /// No description provided for @onboardingSocialProof.
  ///
  /// In en, this message translates to:
  /// **'{count} people already mapping their neighborhood'**
  String onboardingSocialProof(int count);

  /// No description provided for @statsCommunityLine.
  ///
  /// In en, this message translates to:
  /// **'{mappers} people mapping this month · {zones} places covered'**
  String statsCommunityLine(int mappers, int zones);

  /// No description provided for @sessionSummaryZonesClaimed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{place mapped} other{places mapped}}'**
  String sessionSummaryZonesClaimed(int count);

  /// No description provided for @statsWeeklyChartOffline.
  ///
  /// In en, this message translates to:
  /// **'Weekly chart loads once connected'**
  String get statsWeeklyChartOffline;

  /// No description provided for @uploadMilestone.
  ///
  /// In en, this message translates to:
  /// **'{count} uploads. Keep going!'**
  String uploadMilestone(int count);

  /// No description provided for @statsViewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get statsViewOnMap;

  /// No description provided for @statsSinceDate.
  ///
  /// In en, this message translates to:
  /// **'since {date}'**
  String statsSinceDate(String date);

  /// No description provided for @statsStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day in a row} other{{count} days in a row}}'**
  String statsStreakDays(int count);

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
  /// **'Monthly view appears after more active days'**
  String get statsChartMonthEmpty;

  /// No description provided for @statsTerritoryDetails.
  ///
  /// In en, this message translates to:
  /// **'See measurement details'**
  String get statsTerritoryDetails;

  /// No description provided for @statsTerritorySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Your measurements'**
  String get statsTerritorySheetTitle;

  /// No description provided for @statsTerritoryZones.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place} other{{count} places}}'**
  String statsTerritoryZones(int count);

  /// No description provided for @statsTerritoryWhatRecorded.
  ///
  /// In en, this message translates to:
  /// **'Sensors used'**
  String get statsTerritoryWhatRecorded;

  /// No description provided for @statsTerritoryLightLabel.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get statsTerritoryLightLabel;

  /// No description provided for @statsTerritoryMotionLabel.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get statsTerritoryMotionLabel;

  /// No description provided for @statsTerritoryPressureLabel.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get statsTerritoryPressureLabel;

  /// No description provided for @statsTerritoryMapCta.
  ///
  /// In en, this message translates to:
  /// **'Tap any place on the map to see its readings'**
  String get statsTerritoryMapCta;

  /// No description provided for @sessionSummaryShareText.
  ///
  /// In en, this message translates to:
  /// **'I mapped +{gained} new places today. {total} total · {km2}'**
  String sessionSummaryShareText(int gained, int total, String km2);

  /// No description provided for @sessionSummaryShareTextEmpty.
  ///
  /// In en, this message translates to:
  /// **'Mapped for {duration}. {total} places measured · {km2}'**
  String sessionSummaryShareTextEmpty(String duration, int total, String km2);

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
  /// **'Very bright'**
  String get sensorLuxDirect;

  /// No description provided for @sensorMovementLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get sensorMovementLow;

  /// No description provided for @sensorMovementMid.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get sensorMovementMid;

  /// No description provided for @sensorMovementHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get sensorMovementHigh;

  /// No description provided for @sensorMovementIntense.
  ///
  /// In en, this message translates to:
  /// **'Very high'**
  String get sensorMovementIntense;

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
  /// **'Waking the server · {seconds} s'**
  String serverWakingUp(int seconds);

  /// No description provided for @permissionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Location access off'**
  String get permissionLostTitle;

  /// No description provided for @permissionLostBody.
  ///
  /// In en, this message translates to:
  /// **'The map stopped updating. Tap to fix.'**
  String get permissionLostBody;

  /// No description provided for @permissionLostCta.
  ///
  /// In en, this message translates to:
  /// **'Fix in Settings'**
  String get permissionLostCta;

  /// No description provided for @referralNeighborhoodHook.
  ///
  /// In en, this message translates to:
  /// **'Help measure {neighborhood}.'**
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
  /// **'Start mapping'**
  String get onboardingActivateCta;

  /// No description provided for @onboardingPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to map your city.'**
  String get onboardingPermissionDenied;

  /// No description provided for @onboardingPermissionDeniedForeverTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get onboardingPermissionDeniedForeverTitle;

  /// No description provided for @onboardingPermissionDeniedForeverBody.
  ///
  /// In en, this message translates to:
  /// **'Location access was permanently denied. Open Settings and enable it under Permissions → Location.'**
  String get onboardingPermissionDeniedForeverBody;

  /// No description provided for @onboardingOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get onboardingOpenSettings;

  /// No description provided for @sessionSummaryBadge.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get sessionSummaryBadge;

  /// No description provided for @sessionSummaryZonesGainedLabel.
  ///
  /// In en, this message translates to:
  /// **'NEW PLACES'**
  String get sessionSummaryZonesGainedLabel;

  /// No description provided for @sessionSummarySubline.
  ///
  /// In en, this message translates to:
  /// **'added'**
  String get sessionSummarySubline;

  /// No description provided for @sessionSummaryNoZonesLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR READINGS'**
  String get sessionSummaryNoZonesLabel;

  /// No description provided for @sessionSummaryWatermark.
  ///
  /// In en, this message translates to:
  /// **'Mapped with GreenGains'**
  String get sessionSummaryWatermark;

  /// No description provided for @sessionSummaryShareCta.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get sessionSummaryShareCta;

  /// No description provided for @sessionMilestoneHit.
  ///
  /// In en, this message translates to:
  /// **'{milestone} places.'**
  String sessionMilestoneHit(int milestone);

  /// No description provided for @sessionStatArea.
  ///
  /// In en, this message translates to:
  /// **'AREA'**
  String get sessionStatArea;

  /// No description provided for @sessionStatDuration.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get sessionStatDuration;

  /// No description provided for @sessionStatTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get sessionStatTotal;

  /// No description provided for @sessionStatUploads.
  ///
  /// In en, this message translates to:
  /// **'SYNCS'**
  String get sessionStatUploads;

  /// No description provided for @profileStreakToMilestone.
  ///
  /// In en, this message translates to:
  /// **'{days} {unit} to {milestone}-{unit} streak'**
  String profileStreakToMilestone(int days, String unit, int milestone);

  /// No description provided for @statsMilestoneTarget.
  ///
  /// In en, this message translates to:
  /// **'{target} places'**
  String statsMilestoneTarget(int target);

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
  /// **'YOUR CONTRIBUTION'**
  String get statsTerritorySection;

  /// No description provided for @mapTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a place to explore'**
  String get mapTapHint;

  /// No description provided for @sessionPersonalBest.
  ///
  /// In en, this message translates to:
  /// **'Personal best'**
  String get sessionPersonalBest;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @streakResetBanner.
  ///
  /// In en, this message translates to:
  /// **'Streak reset.'**
  String get streakResetBanner;

  /// No description provided for @statsKm2Unit.
  ///
  /// In en, this message translates to:
  /// **'km²'**
  String get statsKm2Unit;

  /// No description provided for @statsHaUnit.
  ///
  /// In en, this message translates to:
  /// **'ha'**
  String get statsHaUnit;

  /// No description provided for @statsLast30DaysUnit.
  ///
  /// In en, this message translates to:
  /// **'/ 30'**
  String get statsLast30DaysUnit;

  /// No description provided for @referralWaiting.
  ///
  /// In en, this message translates to:
  /// **'Link shared. Nobody has joined yet.'**
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
  /// **'Join me on GreenGains: we measure light, pressure and movement in our streets. Invite code: {code}'**
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
  /// **'Your readings are being saved.'**
  String get profileUnlockTitle;

  /// No description provided for @profileUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep them across devices.'**
  String get profileUnlockBody;

  /// No description provided for @mapZeroStateTitle.
  ///
  /// In en, this message translates to:
  /// **'The first place is a few steps away'**
  String get mapZeroStateTitle;

  /// No description provided for @mapZeroStateBody.
  ///
  /// In en, this message translates to:
  /// **'Start tracking: the street appears on the map as soon as you move.'**
  String get mapZeroStateBody;

  /// No description provided for @statsInsightLabel.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get statsInsightLabel;

  /// No description provided for @statsInsightNewZones.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new place mapped this week} other{{count} new places mapped this week}}'**
  String statsInsightNewZones(int count);

  /// No description provided for @statsInsightSolo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place nobody else has measured} other{{count} places nobody else has measured}}'**
  String statsInsightSolo(int count);
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
