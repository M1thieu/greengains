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
  /// **'Your phone reads light, pressure, and motion as you walk — and builds a map of everywhere you\'ve been.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingFeature1Title.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do.'**
  String get onboardingFeature1Title;

  /// No description provided for @onboardingFeature1Description.
  ///
  /// In en, this message translates to:
  /// **'Start once, carry your phone. That\'s it — your map builds itself.'**
  String get onboardingFeature1Description;

  /// No description provided for @onboardingFeature2Title.
  ///
  /// In en, this message translates to:
  /// **'Private by default'**
  String get onboardingFeature2Title;

  /// No description provided for @onboardingFeature2Description.
  ///
  /// In en, this message translates to:
  /// **'Your route is never stored — readings are anonymized before they leave your phone.'**
  String get onboardingFeature2Description;

  /// No description provided for @onboardingFeature3Title.
  ///
  /// In en, this message translates to:
  /// **'See how far you\'ve been.'**
  String get onboardingFeature3Title;

  /// No description provided for @onboardingFeature3Description.
  ///
  /// In en, this message translates to:
  /// **'Every place you visit shows up on your map. Walk the same streets, watch them fill in.'**
  String get onboardingFeature3Description;

  /// No description provided for @onboardingSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Your map starts here.'**
  String get onboardingSignInTitle;

  /// No description provided for @onboardingSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your map synced across devices.'**
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

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'GreenGains'**
  String get homeTitle;

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

  /// No description provided for @trackingActive.
  ///
  /// In en, this message translates to:
  /// **'Tracking Active'**
  String get trackingActive;

  /// No description provided for @trackingPaused.
  ///
  /// In en, this message translates to:
  /// **'Tracking Paused'**
  String get trackingPaused;

  /// No description provided for @trackingStopped.
  ///
  /// In en, this message translates to:
  /// **'Tracking Stopped'**
  String get trackingStopped;

  /// No description provided for @uploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Upload successful'**
  String get uploadSuccess;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @lastUpload.
  ///
  /// In en, this message translates to:
  /// **'Last upload: {time}'**
  String lastUpload(String time);

  /// No description provided for @noUploadYet.
  ///
  /// In en, this message translates to:
  /// **'No upload yet'**
  String get noUploadYet;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Map'**
  String get statsTitle;

  /// No description provided for @totalUploads.
  ///
  /// In en, this message translates to:
  /// **'Total Uploads'**
  String get totalUploads;

  /// No description provided for @todayUploads.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Uploads'**
  String get todayUploads;

  /// No description provided for @coverageTiles.
  ///
  /// In en, this message translates to:
  /// **'Coverage Tiles'**
  String get coverageTiles;

  /// No description provided for @dataCollected.
  ///
  /// In en, this message translates to:
  /// **'Data Collected'**
  String get dataCollected;

  /// No description provided for @timesContributed.
  ///
  /// In en, this message translates to:
  /// **'{count} times contributed'**
  String timesContributed(int count);

  /// No description provided for @mapTitle.
  ///
  /// In en, this message translates to:
  /// **'Coverage Map'**
  String get mapTitle;

  /// No description provided for @mapRecenter.
  ///
  /// In en, this message translates to:
  /// **'Recenter'**
  String get mapRecenter;

  /// No description provided for @mapZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get mapZoomOut;

  /// No description provided for @mapYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your Location'**
  String get mapYourLocation;

  /// No description provided for @mapCoverageLegend.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get mapCoverageLegend;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @profileSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get profileSignedInAs;

  /// No description provided for @profileMemberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String profileMemberSince(String date);

  /// No description provided for @profileLastMapped.
  ///
  /// In en, this message translates to:
  /// **'Last mapped {ago}'**
  String profileLastMapped(String ago);

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? This cannot be undone.'**
  String get profileDeleteConfirm;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data'**
  String get settingsPrivacy;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

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

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsLocationSharing.
  ///
  /// In en, this message translates to:
  /// **'Location Sharing'**
  String get settingsLocationSharing;

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

  /// No description provided for @permissionLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Permission'**
  String get permissionLocationTitle;

  /// No description provided for @permissionLocationMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow location so your phone can map as you walk.'**
  String get permissionLocationMessage;

  /// No description provided for @permissionLocationButton.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get permissionLocationButton;

  /// No description provided for @permissionBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery Optimization'**
  String get permissionBatteryTitle;

  /// No description provided for @permissionBatteryMessage.
  ///
  /// In en, this message translates to:
  /// **'Please disable battery optimization for reliable background tracking.'**
  String get permissionBatteryMessage;

  /// No description provided for @permissionBatteryButton.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get permissionBatteryButton;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNetwork;

  /// No description provided for @errorLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get errorLocationUnavailable;

  /// No description provided for @errorUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Will retry later.'**
  String get errorUploadFailed;

  /// No description provided for @errorSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue'**
  String get errorSignInRequired;

  /// No description provided for @buttonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get buttonOk;

  /// No description provided for @buttonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get buttonCancel;

  /// No description provided for @buttonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get buttonYes;

  /// No description provided for @buttonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get buttonNo;

  /// No description provided for @buttonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get buttonSave;

  /// No description provided for @buttonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get buttonDelete;

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

  /// No description provided for @profileNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not Signed In'**
  String get profileNotSignedIn;

  /// No description provided for @profileSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google to keep your map synced across devices.'**
  String get profileSignInPrompt;

  /// No description provided for @profileAnonymousNote.
  ///
  /// In en, this message translates to:
  /// **'Using anonymously. Sign in to save your map.'**
  String get profileAnonymousNote;

  /// No description provided for @profileUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileUserFallback;

  /// No description provided for @profileViewStats.
  ///
  /// In en, this message translates to:
  /// **'View Statistics'**
  String get profileViewStats;

  /// No description provided for @profileContributionsHint.
  ///
  /// In en, this message translates to:
  /// **'See your map'**
  String get profileContributionsHint;

  /// No description provided for @profileSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get profileSignedOut;

  /// No description provided for @chipContributing.
  ///
  /// In en, this message translates to:
  /// **'Mapping'**
  String get chipContributing;

  /// No description provided for @chipPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get chipPaused;

  /// No description provided for @chipTapStart.
  ///
  /// In en, this message translates to:
  /// **'Tap ▶ to start mapping'**
  String get chipTapStart;

  /// No description provided for @chipTapStartFirst.
  ///
  /// In en, this message translates to:
  /// **'Start mapping your neighborhood'**
  String get chipTapStartFirst;

  /// No description provided for @chipDataPts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pt} other{{count} pts}}'**
  String chipDataPts(int count);

  /// No description provided for @homeSessionZones.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Mapping} =1{+1 zone} other{+{count} zones}}'**
  String homeSessionZones(int count);

  /// No description provided for @homeYourMap.
  ///
  /// In en, this message translates to:
  /// **'YOUR MAP'**
  String get homeYourMap;

  /// No description provided for @homeCityPct.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of city filled'**
  String homeCityPct(String pct);

  /// No description provided for @profileImpactSection.
  ///
  /// In en, this message translates to:
  /// **'YOUR MAP'**
  String get profileImpactSection;

  /// No description provided for @profileAccountSection.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get profileAccountSection;

  /// No description provided for @homeFirstUseHint.
  ///
  /// In en, this message translates to:
  /// **'Tap ▶ — watch your first zone appear on the map'**
  String get homeFirstUseHint;

  /// No description provided for @homeFirstTrackingHint.
  ///
  /// In en, this message translates to:
  /// **'Scanning light, pressure and motion — first zone after first upload'**
  String get homeFirstTrackingHint;

  /// No description provided for @homeTrackingReadings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reading captured} other{{count} readings captured}}'**
  String homeTrackingReadings(num count);

  /// No description provided for @homeReturnHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 zone on your map — tap ▶ to keep growing} other{{count} zones on your map — tap ▶ to keep growing}}'**
  String homeReturnHint(int count);

  /// No description provided for @uploadSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Map updated!'**
  String get uploadSuccessMessage;

  /// No description provided for @uploadSuccessNewZone.
  ///
  /// In en, this message translates to:
  /// **'New area · {count} zones on your map'**
  String uploadSuccessNewZone(int count);

  /// No description provided for @semanticsRefreshMap.
  ///
  /// In en, this message translates to:
  /// **'Refresh map data'**
  String get semanticsRefreshMap;

  /// No description provided for @semanticsToggleTracking.
  ///
  /// In en, this message translates to:
  /// **'Toggle tracking'**
  String get semanticsToggleTracking;

  /// No description provided for @semanticsCenterOnMe.
  ///
  /// In en, this message translates to:
  /// **'Center map on my location'**
  String get semanticsCenterOnMe;

  /// No description provided for @semanticsZoneCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 zone — view stats} other{{count} zones — view stats}}'**
  String semanticsZoneCount(int count);

  /// No description provided for @tipViewLiveDataTitle.
  ///
  /// In en, this message translates to:
  /// **'View live data'**
  String get tipViewLiveDataTitle;

  /// No description provided for @tipViewLiveDataMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap below to see what data you\'re contributing right now'**
  String get tipViewLiveDataMessage;

  /// No description provided for @statsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsScreenTitle;

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

  /// No description provided for @statsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get statsTotal;

  /// No description provided for @statsCoverage.
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get statsCoverage;

  /// No description provided for @statsAreasLabel.
  ///
  /// In en, this message translates to:
  /// **'zones mapped'**
  String get statsAreasLabel;

  /// No description provided for @statsDataPtsLabel.
  ///
  /// In en, this message translates to:
  /// **'recordings'**
  String get statsDataPtsLabel;

  /// No description provided for @statsKmMapped.
  ///
  /// In en, this message translates to:
  /// **'km² mapped'**
  String get statsKmMapped;

  /// No description provided for @statsBarCalloutUploads.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 upload} other{{count} uploads}}'**
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
  /// **'Total uploads'**
  String get statsRecordTotalUploads;

  /// No description provided for @statsRecordFirstDay.
  ///
  /// In en, this message translates to:
  /// **'First mapping day'**
  String get statsRecordFirstDay;

  /// No description provided for @statsZoneExplainer.
  ///
  /// In en, this message translates to:
  /// **'Each zone is ~0.1 km² — a city block of sensor data'**
  String get statsZoneExplainer;

  /// No description provided for @statsUploadExplainer.
  ///
  /// In en, this message translates to:
  /// **'Each upload = light + motion + pressure readings from one spot'**
  String get statsUploadExplainer;

  /// No description provided for @statsTabCore.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statsTabCore;

  /// No description provided for @statsTabInDepth.
  ///
  /// In en, this message translates to:
  /// **'In depth'**
  String get statsTabInDepth;

  /// No description provided for @statsInDepth30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get statsInDepth30Days;

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
  /// **'ALL-TIME'**
  String get statsAllTimeSection;

  /// No description provided for @statsUploadsUnit.
  ///
  /// In en, this message translates to:
  /// **'uploads'**
  String get statsUploadsUnit;

  /// No description provided for @statsBestWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Best week'**
  String get statsBestWeekLabel;

  /// No description provided for @statsQualitySection.
  ///
  /// In en, this message translates to:
  /// **'DATA QUALITY'**
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
  /// **'Valid readings out of all recorded samples'**
  String get statsQualitySubtitle;

  /// No description provided for @statsAvgPrefix.
  ///
  /// In en, this message translates to:
  /// **'avg'**
  String get statsAvgPrefix;

  /// No description provided for @infoKmTitle.
  ///
  /// In en, this message translates to:
  /// **'Territory mapped'**
  String get infoKmTitle;

  /// No description provided for @infoKmBody.
  ///
  /// In en, this message translates to:
  /// **'Each hexagon covers ~0.1 km² — this is your personal footprint on the map.'**
  String get infoKmBody;

  /// No description provided for @infoDataPtsTitle.
  ///
  /// In en, this message translates to:
  /// **'Uploads'**
  String get infoDataPtsTitle;

  /// No description provided for @infoDataPtsBody.
  ///
  /// In en, this message translates to:
  /// **'Each upload captures light, pressure, and movement — more uploads means a denser map.'**
  String get infoDataPtsBody;

  /// No description provided for @infoTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Recordings today'**
  String get infoTodayTitle;

  /// No description provided for @infoTodayBody.
  ///
  /// In en, this message translates to:
  /// **'Sensor readings uploaded today — light, pressure, and movement at each stop.'**
  String get infoTodayBody;

  /// No description provided for @infoThisWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get infoThisWeekTitle;

  /// No description provided for @infoThisWeekBody.
  ///
  /// In en, this message translates to:
  /// **'Recordings over the last 7 days — consistency builds richer map data.'**
  String get infoThisWeekBody;

  /// No description provided for @infoDaysActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Days active'**
  String get infoDaysActiveTitle;

  /// No description provided for @infoDaysActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Days you contributed — no need to be active every day.'**
  String get infoDaysActiveBody;

  /// No description provided for @infoBestDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Best day'**
  String get infoBestDayTitle;

  /// No description provided for @infoBestDayBody.
  ///
  /// In en, this message translates to:
  /// **'Your most active day this week — usually means more time outdoors.'**
  String get infoBestDayBody;

  /// No description provided for @infoMilestoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Next milestone'**
  String get infoMilestoneTitle;

  /// No description provided for @infoMilestoneBody.
  ///
  /// In en, this message translates to:
  /// **'Each new area you map counts toward the next milestone.'**
  String get infoMilestoneBody;

  /// No description provided for @infoTileQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Coverage quality'**
  String get infoTileQualityTitle;

  /// No description provided for @infoTileQualityBody.
  ///
  /// In en, this message translates to:
  /// **'Green = well covered, yellow = partial, red = needs more passes.'**
  String get infoTileQualityBody;

  /// No description provided for @infoTilePersonalTitle.
  ///
  /// In en, this message translates to:
  /// **'Your area'**
  String get infoTilePersonalTitle;

  /// No description provided for @infoTilePersonalBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone recorded here.'**
  String get infoTilePersonalBody;

  /// No description provided for @infoTileCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community area'**
  String get infoTileCommunityTitle;

  /// No description provided for @infoTileCommunityBody.
  ///
  /// In en, this message translates to:
  /// **'Mapped by others — walk here to make it yours.'**
  String get infoTileCommunityBody;

  /// No description provided for @statsTotalContributions.
  ///
  /// In en, this message translates to:
  /// **'Total Contributions'**
  String get statsTotalContributions;

  /// No description provided for @statsActivityTrend.
  ///
  /// In en, this message translates to:
  /// **'Your week'**
  String get statsActivityTrend;

  /// No description provided for @statsLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get statsLast7Days;

  /// No description provided for @statsTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get statsTodayLabel;

  /// No description provided for @statsHistoryNote.
  ///
  /// In en, this message translates to:
  /// **'Weekly history will appear once you have multiple days of data'**
  String get statsHistoryNote;

  /// No description provided for @statsContributionTimeline.
  ///
  /// In en, this message translates to:
  /// **'Contribution Timeline'**
  String get statsContributionTimeline;

  /// No description provided for @statsAchievements.
  ///
  /// In en, this message translates to:
  /// **''**
  String get statsAchievements;

  /// No description provided for @statsEarnings.
  ///
  /// In en, this message translates to:
  /// **''**
  String get statsEarnings;

  /// No description provided for @statsVisualizationNote.
  ///
  /// In en, this message translates to:
  /// **''**
  String get statsVisualizationNote;

  /// No description provided for @statsAchievementsDescription.
  ///
  /// In en, this message translates to:
  /// **''**
  String get statsAchievementsDescription;

  /// No description provided for @statsEarningsTracking.
  ///
  /// In en, this message translates to:
  /// **''**
  String get statsEarningsTracking;

  /// No description provided for @statsEarningsDescription.
  ///
  /// In en, this message translates to:
  /// **''**
  String get statsEarningsDescription;

  /// No description provided for @statsStartContributing.
  ///
  /// In en, this message translates to:
  /// **'Your map is blank.'**
  String get statsStartContributing;

  /// No description provided for @statsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap ▶. Your first zone is waiting to be mapped.'**
  String get statsEmptyDescription;

  /// No description provided for @statsEmptyGoMap.
  ///
  /// In en, this message translates to:
  /// **'Go to map'**
  String get statsEmptyGoMap;

  /// No description provided for @statsUpdatedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Updated '**
  String get statsUpdatedPrefix;

  /// No description provided for @statsDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get statsDayMon;

  /// No description provided for @statsDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get statsDayTue;

  /// No description provided for @statsDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get statsDayWed;

  /// No description provided for @statsDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get statsDayThu;

  /// No description provided for @statsDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get statsDayFri;

  /// No description provided for @statsDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get statsDaySat;

  /// No description provided for @statsDayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statsDayToday;

  /// No description provided for @mapLoadingText.
  ///
  /// In en, this message translates to:
  /// **'Loading map...'**
  String get mapLoadingText;

  /// No description provided for @mapCenterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Center on location'**
  String get mapCenterTooltip;

  /// No description provided for @yourContributions.
  ///
  /// In en, this message translates to:
  /// **'YOUR TERRITORY'**
  String get yourContributions;

  /// No description provided for @impactCardContext.
  ///
  /// In en, this message translates to:
  /// **'zones mapped'**
  String get impactCardContext;

  /// No description provided for @loadingStatsLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading your stats'**
  String get loadingStatsLabel;

  /// No description provided for @noContributionsYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet — tap ▶ to start.'**
  String get noContributionsYet;

  /// No description provided for @startContributingTitle.
  ///
  /// In en, this message translates to:
  /// **'Start mapping'**
  String get startContributingTitle;

  /// No description provided for @startContributingHint.
  ///
  /// In en, this message translates to:
  /// **'Your phone maps your world silently while you go about your day'**
  String get startContributingHint;

  /// No description provided for @areaCovered.
  ///
  /// In en, this message translates to:
  /// **'Area covered'**
  String get areaCovered;

  /// No description provided for @activeStreak.
  ///
  /// In en, this message translates to:
  /// **'Territory'**
  String get activeStreak;

  /// No description provided for @contributionStatsSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Your contributions: {uploads}. Area covered: {area}.'**
  String contributionStatsSemanticsLabel(String uploads, String area);

  /// No description provided for @chipZones.
  ///
  /// In en, this message translates to:
  /// **'zones'**
  String get chipZones;

  /// No description provided for @chipSensors.
  ///
  /// In en, this message translates to:
  /// **'signals'**
  String get chipSensors;

  /// No description provided for @homeZonesMapped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 zone mapped} other{{count} zones mapped}}'**
  String homeZonesMapped(int count);

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
  /// **'Coverage'**
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

  /// No description provided for @tickerMotionStill.
  ///
  /// In en, this message translates to:
  /// **'still'**
  String get tickerMotionStill;

  /// No description provided for @tickerMotionMoving.
  ///
  /// In en, this message translates to:
  /// **'moving'**
  String get tickerMotionMoving;

  /// No description provided for @tickerMotionActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get tickerMotionActive;

  /// No description provided for @tileInfoSamples.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reading} other{{count} readings}}'**
  String tileInfoSamples(int count);

  /// No description provided for @tileInfoConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get tileInfoConfidence;

  /// No description provided for @tileInfoQuality.
  ///
  /// In en, this message translates to:
  /// **'Coverage quality'**
  String get tileInfoQuality;

  /// No description provided for @tileInfoDevices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String tileInfoDevices(int count);

  /// No description provided for @tileScanningNow.
  ///
  /// In en, this message translates to:
  /// **'Scanning now'**
  String get tileScanningNow;

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
  /// **'Live readings'**
  String get sensorLiveReadings;

  /// No description provided for @sensorLiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Real-time sensor readings from your phone.'**
  String get sensorLiveSubtitle;

  /// No description provided for @sensorInactiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Not recording'**
  String get sensorInactiveTitle;

  /// No description provided for @sensorInactiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start tracking to see live readings.'**
  String get sensorInactiveSubtitle;

  /// No description provided for @sensorPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording paused'**
  String get sensorPausedTitle;

  /// No description provided for @sensorPausedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Resume to see live readings.'**
  String get sensorPausedSubtitle;

  /// No description provided for @sensorCollectingFirst.
  ///
  /// In en, this message translates to:
  /// **'Starting up…'**
  String get sensorCollectingFirst;

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
  /// **'Magnetic Field'**
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

  /// No description provided for @sensorAccelerationIntensity.
  ///
  /// In en, this message translates to:
  /// **'Acceleration intensity'**
  String get sensorAccelerationIntensity;

  /// No description provided for @sensorRotationSpeed.
  ///
  /// In en, this message translates to:
  /// **'Rotation speed'**
  String get sensorRotationSpeed;

  /// No description provided for @sensorAtmosphericPressure.
  ///
  /// In en, this message translates to:
  /// **'Atmospheric pressure'**
  String get sensorAtmosphericPressure;

  /// No description provided for @sensorStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get sensorStatusPaused;

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
  /// **'High — near metal'**
  String get magnetHighNearMetal;

  /// No description provided for @daysActive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysActive(int count);

  /// No description provided for @trackingFabStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get trackingFabStarting;

  /// No description provided for @trackingFabPause.
  ///
  /// In en, this message translates to:
  /// **'Pause tracking'**
  String get trackingFabPause;

  /// No description provided for @trackingFabResume.
  ///
  /// In en, this message translates to:
  /// **'Resume tracking'**
  String get trackingFabResume;

  /// No description provided for @trackingFabStart.
  ///
  /// In en, this message translates to:
  /// **'Start tracking'**
  String get trackingFabStart;

  /// No description provided for @trackingErrorUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update tracking — please try again.'**
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

  /// No description provided for @settingsLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Required for the live coverage map'**
  String get settingsLocationDescription;

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

  /// No description provided for @settingsPrivacyPolicyDesc.
  ///
  /// In en, this message translates to:
  /// **'How we handle your data'**
  String get settingsPrivacyPolicyDesc;

  /// No description provided for @settingsTermsOfServiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Usage terms and conditions'**
  String get settingsTermsOfServiceDesc;

  /// No description provided for @settingsDataDeletion.
  ///
  /// In en, this message translates to:
  /// **'Request Data Deletion'**
  String get settingsDataDeletion;

  /// No description provided for @settingsDataDeletionDesc.
  ///
  /// In en, this message translates to:
  /// **'Erase all your recorded data'**
  String get settingsDataDeletionDesc;

  /// No description provided for @settingsDataSection.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsDataSection;

  /// No description provided for @settingsConsentDate.
  ///
  /// In en, this message translates to:
  /// **'Consented: {date}'**
  String settingsConsentDate(String date);

  /// No description provided for @settingsDataRetention.
  ///
  /// In en, this message translates to:
  /// **'Data kept for 7 days (Free)'**
  String get settingsDataRetention;

  /// No description provided for @referralInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get referralInviteTitle;

  /// No description provided for @referralInviteDescription.
  ///
  /// In en, this message translates to:
  /// **'Every neighbor fills in what you haven\'t reached.'**
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

  /// No description provided for @referralLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get referralLinkCopied;

  /// No description provided for @referralCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get referralCopyLink;

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

  /// No description provided for @tooltipRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get tooltipRefresh;

  /// No description provided for @tooltipDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get tooltipDismiss;

  /// No description provided for @statsHighlightsLabel.
  ///
  /// In en, this message translates to:
  /// **'HIGHLIGHTS'**
  String get statsHighlightsLabel;

  /// No description provided for @statsMappingSince.
  ///
  /// In en, this message translates to:
  /// **'Mapping since'**
  String get statsMappingSince;

  /// No description provided for @statsFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stats'**
  String get statsFailedToLoad;

  /// No description provided for @statsReadyToContribute.
  ///
  /// In en, this message translates to:
  /// **'Start walking to build your map.'**
  String get statsReadyToContribute;

  /// No description provided for @statsFirstContributionHint.
  ///
  /// In en, this message translates to:
  /// **'Start tracking to map your first area'**
  String get statsFirstContributionHint;

  /// No description provided for @statsWeeklyLabel.
  ///
  /// In en, this message translates to:
  /// **'7 DAYS'**
  String get statsWeeklyLabel;

  /// No description provided for @statsWeeklyTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} this week'**
  String statsWeeklyTotal(int count);

  /// No description provided for @statsMilestoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Next level'**
  String get statsMilestoneLabel;

  /// No description provided for @statsMilestoneHint.
  ///
  /// In en, this message translates to:
  /// **'Map enough zones to reach this level and unlock the next one'**
  String get statsMilestoneHint;

  /// No description provided for @statsMilestoneElite.
  ///
  /// In en, this message translates to:
  /// **'Fully mapped · explorer status'**
  String get statsMilestoneElite;

  /// No description provided for @statsMilestoneRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 zone to go} other{{count} zones to go}}'**
  String statsMilestoneRemaining(int count);

  /// No description provided for @milestoneNudge.
  ///
  /// In en, this message translates to:
  /// **'{remaining} to {target}'**
  String milestoneNudge(int remaining, int target);

  /// No description provided for @statsCommunityAreas.
  ///
  /// In en, this message translates to:
  /// **'{count} areas mapped by community'**
  String statsCommunityAreas(int count);

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

  /// No description provided for @locationPermBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Set to \'Allow all the time\' to map in the background'**
  String get locationPermBannerBody;

  /// No description provided for @locationPermBannerFix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get locationPermBannerFix;

  /// No description provided for @legendYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get legendYou;

  /// No description provided for @legendCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get legendCommunity;

  /// No description provided for @referralStepShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get referralStepShare;

  /// No description provided for @referralStepJoin.
  ///
  /// In en, this message translates to:
  /// **'They join'**
  String get referralStepJoin;

  /// No description provided for @referralStepEarn.
  ///
  /// In en, this message translates to:
  /// **'Map grows'**
  String get referralStepEarn;

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
  /// **'What you\'re measuring'**
  String get sensorLiveSheetTitle;

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

  /// No description provided for @tileMeasuredWith.
  ///
  /// In en, this message translates to:
  /// **'Recorded with'**
  String get tileMeasuredWith;

  /// No description provided for @legendHighLabel.
  ///
  /// In en, this message translates to:
  /// **'High quality'**
  String get legendHighLabel;

  /// No description provided for @legendHighSub.
  ///
  /// In en, this message translates to:
  /// **'≥75% valid sensor readings'**
  String get legendHighSub;

  /// No description provided for @legendMidLabel.
  ///
  /// In en, this message translates to:
  /// **'Medium quality'**
  String get legendMidLabel;

  /// No description provided for @legendMidSub.
  ///
  /// In en, this message translates to:
  /// **'50–74% valid readings'**
  String get legendMidSub;

  /// No description provided for @legendLowLabel.
  ///
  /// In en, this message translates to:
  /// **'Low quality'**
  String get legendLowLabel;

  /// No description provided for @legendLowSub.
  ///
  /// In en, this message translates to:
  /// **'Below 50% — needs more data'**
  String get legendLowSub;

  /// No description provided for @legendCommunitySub.
  ///
  /// In en, this message translates to:
  /// **'Recorded by other people'**
  String get legendCommunitySub;

  /// No description provided for @permissionPrimingTitle.
  ///
  /// In en, this message translates to:
  /// **'One thing before we start'**
  String get permissionPrimingTitle;

  /// No description provided for @permissionPrimingBattery.
  ///
  /// In en, this message translates to:
  /// **'Smart battery'**
  String get permissionPrimingBattery;

  /// No description provided for @permissionPrimingBatteryDesc.
  ///
  /// In en, this message translates to:
  /// **'Less than 1% per hour — adapts automatically in background'**
  String get permissionPrimingBatteryDesc;

  /// No description provided for @permissionPrimingCollects.
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get permissionPrimingCollects;

  /// No description provided for @permissionPrimingCollectsDesc.
  ///
  /// In en, this message translates to:
  /// **'Light, pressure and motion only — never your route or identity'**
  String get permissionPrimingCollectsDesc;

  /// No description provided for @permissionPrimingCta.
  ///
  /// In en, this message translates to:
  /// **'Enable location'**
  String get permissionPrimingCta;

  /// No description provided for @settingsBatteryMode.
  ///
  /// In en, this message translates to:
  /// **'Smart battery'**
  String get settingsBatteryMode;

  /// No description provided for @settingsBatteryModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Quiet when still, precise when moving — adapts automatically'**
  String get settingsBatteryModeDesc;

  /// No description provided for @firstStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Building your map.'**
  String get firstStartTitle;

  /// No description provided for @firstStartBody.
  ///
  /// In en, this message translates to:
  /// **'Move — zones appear as you go.'**
  String get firstStartBody;

  /// No description provided for @alwaysOnBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Set location to \'Always\' to keep mapping in the background'**
  String get alwaysOnBannerBody;

  /// No description provided for @alwaysOnBannerFix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get alwaysOnBannerFix;

  /// No description provided for @milestoneReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count} zones mapped'**
  String milestoneReachedTitle(int count);

  /// No description provided for @milestoneReachedBody.
  ///
  /// In en, this message translates to:
  /// **'Keep pushing — your next goal is waiting.'**
  String get milestoneReachedBody;

  /// No description provided for @milestoneReachedCta.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get milestoneReachedCta;

  /// No description provided for @firstUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'First area mapped.'**
  String get firstUploadTitle;

  /// No description provided for @firstUploadBody.
  ///
  /// In en, this message translates to:
  /// **'Keep moving — your map is growing.'**
  String get firstUploadBody;

  /// No description provided for @firstUploadCta.
  ///
  /// In en, this message translates to:
  /// **'See my map'**
  String get firstUploadCta;

  /// No description provided for @onboardingSocialProof.
  ///
  /// In en, this message translates to:
  /// **'{count} people already mapping their neighborhood'**
  String onboardingSocialProof(int count);

  /// No description provided for @sessionSummaryZonesClaimed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{zone mapped} other{zones mapped}}'**
  String sessionSummaryZonesClaimed(int count);

  /// No description provided for @sessionSummaryTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {zones} zones · {km2} km²'**
  String sessionSummaryTotal(int zones, String km2);

  /// No description provided for @sessionSummaryCta.
  ///
  /// In en, this message translates to:
  /// **'See my map'**
  String get sessionSummaryCta;

  /// No description provided for @sessionSummaryDone.
  ///
  /// In en, this message translates to:
  /// **'Nice'**
  String get sessionSummaryDone;

  /// No description provided for @statsMapGrowing.
  ///
  /// In en, this message translates to:
  /// **'map growing — keep walking'**
  String get statsMapGrowing;

  /// No description provided for @statsWeeklyChartOffline.
  ///
  /// In en, this message translates to:
  /// **'Weekly chart loads once connected'**
  String get statsWeeklyChartOffline;

  /// No description provided for @uploadMilestone.
  ///
  /// In en, this message translates to:
  /// **'{count} uploads — keep going!'**
  String uploadMilestone(int count);

  /// No description provided for @statsViewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get statsViewOnMap;

  /// No description provided for @statsCommunityMappers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person mapping this month} other{{count} people mapping this month}}'**
  String statsCommunityMappers(int count);

  /// No description provided for @tileFirstMapped.
  ///
  /// In en, this message translates to:
  /// **'First mapped {date}'**
  String tileFirstMapped(String date);

  /// No description provided for @statsSinceDate.
  ///
  /// In en, this message translates to:
  /// **'since {date}'**
  String statsSinceDate(String date);

  /// No description provided for @statsStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get statsStreakLabel;

  /// No description provided for @statsStreakAtRisk.
  ///
  /// In en, this message translates to:
  /// **'Don\'t break the chain'**
  String get statsStreakAtRisk;

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

  /// No description provided for @statsStreakPersonalBest.
  ///
  /// In en, this message translates to:
  /// **'Best: {count} days'**
  String statsStreakPersonalBest(int count);

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
  /// **'~{count, plural, =1{1 zone mapped} other{{count} zones mapped}} · light · motion · pressure'**
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
  /// **'{count, plural, =1{1 zone} other{{count} zones}}'**
  String statsTerritoryZones(int count);

  /// No description provided for @statsTerritoryWhatRecorded.
  ///
  /// In en, this message translates to:
  /// **'What\'s recorded in each zone'**
  String get statsTerritoryWhatRecorded;

  /// No description provided for @statsTerritoryLightLabel.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get statsTerritoryLightLabel;

  /// No description provided for @statsTerritoryLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Ambient brightness — indoor, outdoor, shade, direct sun'**
  String get statsTerritoryLightDesc;

  /// No description provided for @statsTerritoryMotionLabel.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get statsTerritoryMotionLabel;

  /// No description provided for @statsTerritoryMotionDesc.
  ///
  /// In en, this message translates to:
  /// **'Movement intensity — foot traffic, vehicles, vibration'**
  String get statsTerritoryMotionDesc;

  /// No description provided for @statsTerritoryPressureLabel.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get statsTerritoryPressureLabel;

  /// No description provided for @statsTerritoryPressureDesc.
  ///
  /// In en, this message translates to:
  /// **'Air pressure — indicates altitude and weather conditions'**
  String get statsTerritoryPressureDesc;

  /// No description provided for @statsTerritoryMapCta.
  ///
  /// In en, this message translates to:
  /// **'Tap any zone on the map to see its readings'**
  String get statsTerritoryMapCta;

  /// No description provided for @tileCommunityClaimCta.
  ///
  /// In en, this message translates to:
  /// **'Walk through here to make it yours'**
  String get tileCommunityClaimCta;

  /// No description provided for @tileLowQualityHint.
  ///
  /// In en, this message translates to:
  /// **'Walk here again — more passes = stronger data.'**
  String get tileLowQualityHint;

  /// No description provided for @homeZonesOnYourMap.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 zone on your map} other{{count} zones on your map}}'**
  String homeZonesOnYourMap(int count);

  /// No description provided for @homeCommunityScopeHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 zone mapped in your area} other{{count} zones mapped in your area}}'**
  String homeCommunityScopeHint(int count);

  /// No description provided for @tileCivicNote.
  ///
  /// In en, this message translates to:
  /// **'You measured this.'**
  String get tileCivicNote;

  /// No description provided for @tileShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share this spot'**
  String get tileShareButton;

  /// No description provided for @tileShareText.
  ///
  /// In en, this message translates to:
  /// **'I measured this spot — {condition}. Check it out on the map.'**
  String tileShareText(String condition);

  /// No description provided for @sessionSummaryShareText.
  ///
  /// In en, this message translates to:
  /// **'I mapped +{gained} zones today — {total} zones total · {km2} km²'**
  String sessionSummaryShareText(int gained, int total, String km2);

  /// No description provided for @sessionSummaryShareTextEmpty.
  ///
  /// In en, this message translates to:
  /// **'Mapped for {duration} — {total} zones on my map · {km2} km²'**
  String sessionSummaryShareTextEmpty(String duration, int total, String km2);

  /// No description provided for @sensorLuxLabel.
  ///
  /// In en, this message translates to:
  /// **'{lux} lux'**
  String sensorLuxLabel(int lux);

  /// No description provided for @sensorHpaLabel.
  ///
  /// In en, this message translates to:
  /// **'{hpa} hPa'**
  String sensorHpaLabel(String hpa);

  /// No description provided for @sensorMovementLabel.
  ///
  /// In en, this message translates to:
  /// **'{val}'**
  String sensorMovementLabel(String val);

  /// No description provided for @sensorLuxDark.
  ///
  /// In en, this message translates to:
  /// **'Pitch dark'**
  String get sensorLuxDark;

  /// No description provided for @sensorLuxIndoor.
  ///
  /// In en, this message translates to:
  /// **'Dim · indoors'**
  String get sensorLuxIndoor;

  /// No description provided for @sensorLuxBright.
  ///
  /// In en, this message translates to:
  /// **'Bright outdoors'**
  String get sensorLuxBright;

  /// No description provided for @sensorLuxDirect.
  ///
  /// In en, this message translates to:
  /// **'Full sunlight'**
  String get sensorLuxDirect;

  /// No description provided for @sensorMovementLow.
  ///
  /// In en, this message translates to:
  /// **'Quiet zone'**
  String get sensorMovementLow;

  /// No description provided for @sensorMovementMid.
  ///
  /// In en, this message translates to:
  /// **'Active area'**
  String get sensorMovementMid;

  /// No description provided for @sensorMovementHigh.
  ///
  /// In en, this message translates to:
  /// **'Busy corridor'**
  String get sensorMovementHigh;

  /// No description provided for @sensorMovementIntense.
  ///
  /// In en, this message translates to:
  /// **'Transit / heavy traffic'**
  String get sensorMovementIntense;

  /// No description provided for @sensorHpaLow.
  ///
  /// In en, this message translates to:
  /// **'Clear skies'**
  String get sensorHpaLow;

  /// No description provided for @sensorHpaMid.
  ///
  /// In en, this message translates to:
  /// **'Stable pressure'**
  String get sensorHpaMid;

  /// No description provided for @sensorHpaHigh.
  ///
  /// In en, this message translates to:
  /// **'Unsettled weather'**
  String get sensorHpaHigh;

  /// No description provided for @tileSensorInsightsLabel.
  ///
  /// In en, this message translates to:
  /// **'What\'s usually here'**
  String get tileSensorInsightsLabel;

  /// No description provided for @tileConditionSummary.
  ///
  /// In en, this message translates to:
  /// **'Usually {light}, {movement}, under {pressure}.'**
  String tileConditionSummary(String light, String movement, String pressure);

  /// No description provided for @tileConditionSummaryNoHpa.
  ///
  /// In en, this message translates to:
  /// **'Usually {light} and {movement}.'**
  String tileConditionSummaryNoHpa(String light, String movement);

  /// No description provided for @territoryHeroLabel.
  ///
  /// In en, this message translates to:
  /// **'{neighborhood} · {count} zones'**
  String territoryHeroLabel(String neighborhood, int count);

  /// No description provided for @serverWakingUp.
  ///
  /// In en, this message translates to:
  /// **'Starting up — hang tight…'**
  String get serverWakingUp;

  /// No description provided for @ambientHereLabel.
  ///
  /// In en, this message translates to:
  /// **'Here'**
  String get ambientHereLabel;

  /// No description provided for @ambientNearbyLabel.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get ambientNearbyLabel;

  /// No description provided for @ambientUnmappedLabel.
  ///
  /// In en, this message translates to:
  /// **'Walk here to reveal data'**
  String get ambientUnmappedLabel;

  /// No description provided for @permissionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Location access off'**
  String get permissionLostTitle;

  /// No description provided for @permissionLostBody.
  ///
  /// In en, this message translates to:
  /// **'Your map stopped updating. Tap to fix.'**
  String get permissionLostBody;

  /// No description provided for @permissionLostCta.
  ///
  /// In en, this message translates to:
  /// **'Fix in Settings'**
  String get permissionLostCta;

  /// No description provided for @referralNeighborhoodHook.
  ///
  /// In en, this message translates to:
  /// **'Help map {neighborhood} — every neighbor fills in what you haven\'t reached.'**
  String referralNeighborhoodHook(String neighborhood);

  /// No description provided for @onboardingActivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get onboardingActivateTitle;

  /// No description provided for @onboardingActivateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow location access — your phone maps as you move.'**
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

  /// No description provided for @homeMaxClusterHint.
  ///
  /// In en, this message translates to:
  /// **'biggest area: {count} zones'**
  String homeMaxClusterHint(int count);

  /// No description provided for @firstUploadBadge.
  ///
  /// In en, this message translates to:
  /// **'FIRST ZONE UPLOADED'**
  String get firstUploadBadge;

  /// No description provided for @firstUploadHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your first zone is on the map.'**
  String get firstUploadHeadline;

  /// No description provided for @firstUploadSubtext.
  ///
  /// In en, this message translates to:
  /// **'Your first zone is live. Keep walking — every place you visit fills in.'**
  String get firstUploadSubtext;

  /// No description provided for @firstUploadSensorsLabel.
  ///
  /// In en, this message translates to:
  /// **'SENSORS'**
  String get firstUploadSensorsLabel;

  /// No description provided for @firstUploadSensorsValue.
  ///
  /// In en, this message translates to:
  /// **'light · motion · pressure'**
  String get firstUploadSensorsValue;

  /// No description provided for @firstUploadPrivacyLabel.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get firstUploadPrivacyLabel;

  /// No description provided for @firstUploadPrivacyValue.
  ///
  /// In en, this message translates to:
  /// **'anonymised'**
  String get firstUploadPrivacyValue;

  /// No description provided for @firstUploadKeepMappingCta.
  ///
  /// In en, this message translates to:
  /// **'Keep mapping'**
  String get firstUploadKeepMappingCta;

  /// No description provided for @liveSensorsHeader.
  ///
  /// In en, this message translates to:
  /// **'LIVE SENSORS'**
  String get liveSensorsHeader;

  /// No description provided for @liveSensorMotionLabel.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get liveSensorMotionLabel;

  /// No description provided for @liveSensorPressureLabel.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get liveSensorPressureLabel;

  /// No description provided for @sessionSummaryBadge.
  ///
  /// In en, this message translates to:
  /// **'WALK DONE'**
  String get sessionSummaryBadge;

  /// No description provided for @sessionSummaryZonesGainedLabel.
  ///
  /// In en, this message translates to:
  /// **'NEW ZONES'**
  String get sessionSummaryZonesGainedLabel;

  /// No description provided for @sessionSummarySubline.
  ///
  /// In en, this message translates to:
  /// **'added to your map'**
  String get sessionSummarySubline;

  /// No description provided for @sessionSummaryNoZonesLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR MAP'**
  String get sessionSummaryNoZonesLabel;

  /// No description provided for @sessionSummaryNoZonesSubline.
  ///
  /// In en, this message translates to:
  /// **'Familiar ground. Head somewhere new to grow it.'**
  String get sessionSummaryNoZonesSubline;

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
  /// **'{milestone} zones reached. You earned it.'**
  String sessionMilestoneHit(int milestone);

  /// No description provided for @sessionSummaryNextHook.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow — don\'t break the chain.'**
  String get sessionSummaryNextHook;

  /// No description provided for @sessionSummaryNextHookEmpty.
  ///
  /// In en, this message translates to:
  /// **'Walk more next time — zones fill in as you move.'**
  String get sessionSummaryNextHookEmpty;

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

  /// No description provided for @statsMilestoneTarget.
  ///
  /// In en, this message translates to:
  /// **'{target} zones'**
  String statsMilestoneTarget(int target);

  /// No description provided for @statsActivitySection.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY'**
  String get statsActivitySection;

  /// No description provided for @statsTerritorySection.
  ///
  /// In en, this message translates to:
  /// **'TERRITORY'**
  String get statsTerritorySection;

  /// No description provided for @mapTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a hex to explore'**
  String get mapTapHint;

  /// No description provided for @sessionPersonalBest.
  ///
  /// In en, this message translates to:
  /// **'Personal best'**
  String get sessionPersonalBest;

  /// No description provided for @returnDeltaTitle.
  ///
  /// In en, this message translates to:
  /// **'{zones} new zones while you were away.'**
  String returnDeltaTitle(int zones);

  /// No description provided for @returnDeltaDismiss.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get returnDeltaDismiss;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutConfirmTitle;

  /// No description provided for @settingsSignOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to sign back in to see your map.'**
  String get settingsSignOutConfirmBody;

  /// No description provided for @settingsSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOutConfirm;

  /// No description provided for @settingsSignOutCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsSignOutCancel;
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
