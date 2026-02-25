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
  /// **'Your phone earns while you live'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Install once, forget about it. We passively map environmental data in the background — you get rewarded for helping build a better picture of the world.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingFeature1Title.
  ///
  /// In en, this message translates to:
  /// **'Runs silently'**
  String get onboardingFeature1Title;

  /// No description provided for @onboardingFeature1Description.
  ///
  /// In en, this message translates to:
  /// **'Works in the background while you commute, walk, or sleep. No tapping, no setup — ever again.'**
  String get onboardingFeature1Description;

  /// No description provided for @onboardingFeature2Title.
  ///
  /// In en, this message translates to:
  /// **'Anonymized by design'**
  String get onboardingFeature2Title;

  /// No description provided for @onboardingFeature2Description.
  ///
  /// In en, this message translates to:
  /// **'Sensor readings are bundled with thousands of others before leaving your device. No personal data, ever.'**
  String get onboardingFeature2Description;

  /// No description provided for @onboardingFeature3Title.
  ///
  /// In en, this message translates to:
  /// **'Watch your impact grow'**
  String get onboardingFeature3Title;

  /// No description provided for @onboardingFeature3Description.
  ///
  /// In en, this message translates to:
  /// **'Your coverage map expands with every trip. Every contribution helps researchers and cities understand their environment.'**
  String get onboardingFeature3Description;

  /// No description provided for @onboardingSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock your rewards'**
  String get onboardingSignInTitle;

  /// No description provided for @onboardingSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in once to sync your progress and start earning daily rewards.'**
  String get onboardingSignInSubtitle;

  /// No description provided for @onboardingDailyPotRewards.
  ///
  /// In en, this message translates to:
  /// **'Daily Rewards'**
  String get onboardingDailyPotRewards;

  /// No description provided for @onboardingDailyPotDescription.
  ///
  /// In en, this message translates to:
  /// **'Earn credits every day you contribute'**
  String get onboardingDailyPotDescription;

  /// No description provided for @onboardingCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get onboardingCloudSync;

  /// No description provided for @onboardingCloudSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Access your stats on any device'**
  String get onboardingCloudSyncDescription;

  /// No description provided for @onboardingFutureFeatures.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get onboardingFutureFeatures;

  /// No description provided for @onboardingFutureDescription.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards, milestones, and competitions'**
  String get onboardingFutureDescription;

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

  /// No description provided for @dailyPotTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Pot'**
  String get dailyPotTitle;

  /// No description provided for @dailyPotClaimButton.
  ///
  /// In en, this message translates to:
  /// **'Claim {amount} Credits'**
  String dailyPotClaimButton(int amount);

  /// No description provided for @dailyPotClaimed.
  ///
  /// In en, this message translates to:
  /// **'+{amount} credits! 🍯'**
  String dailyPotClaimed(int amount);

  /// No description provided for @dailyPotAlreadyClaimed.
  ///
  /// In en, this message translates to:
  /// **'Already claimed today! Come back tomorrow'**
  String get dailyPotAlreadyClaimed;

  /// No description provided for @dailyPotNeedMoreUploads.
  ///
  /// In en, this message translates to:
  /// **'Need {count} more upload{s} to unlock'**
  String dailyPotNeedMoreUploads(int count, String s);

  /// No description provided for @dailyPotProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {required} uploads'**
  String dailyPotProgress(int current, int required);

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'{count} credits'**
  String credits(int count);

  /// No description provided for @totalCredits.
  ///
  /// In en, this message translates to:
  /// **'Total Credits'**
  String get totalCredits;

  /// No description provided for @creditsEarned.
  ///
  /// In en, this message translates to:
  /// **'Credits Earned'**
  String get creditsEarned;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Impact'**
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

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsLocationSharing.
  ///
  /// In en, this message translates to:
  /// **'Location Sharing'**
  String get settingsLocationSharing;

  /// No description provided for @settingsLocationEnabled.
  ///
  /// In en, this message translates to:
  /// **'Location sharing enabled'**
  String get settingsLocationEnabled;

  /// No description provided for @settingsLocationDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location sharing disabled'**
  String get settingsLocationDisabled;

  /// No description provided for @settingsMobileData.
  ///
  /// In en, this message translates to:
  /// **'Mobile Data Upload'**
  String get settingsMobileData;

  /// No description provided for @settingsMobileDataEnabled.
  ///
  /// In en, this message translates to:
  /// **'Upload on mobile data'**
  String get settingsMobileDataEnabled;

  /// No description provided for @settingsMobileDataDisabled.
  ///
  /// In en, this message translates to:
  /// **'Upload on WiFi only'**
  String get settingsMobileDataDisabled;

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
  /// **'GreenGains needs location access to collect environmental data.'**
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
  /// **'Sign in with Google to unlock daily pot rewards and sync your data across devices.'**
  String get profileSignInPrompt;

  /// No description provided for @profileAnonymousNote.
  ///
  /// In en, this message translates to:
  /// **'Using anonymously. Daily pot rewards unavailable.'**
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
  /// **'Track your contributions'**
  String get profileContributionsHint;

  /// No description provided for @profileSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get profileSignedOut;

  /// No description provided for @chipContributing.
  ///
  /// In en, this message translates to:
  /// **'Contributing'**
  String get chipContributing;

  /// No description provided for @chipPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get chipPaused;

  /// No description provided for @chipTapStart.
  ///
  /// In en, this message translates to:
  /// **'Tap Start'**
  String get chipTapStart;

  /// No description provided for @uploadSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Contribution uploaded successfully!'**
  String get uploadSuccessMessage;

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

  /// No description provided for @statsStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get statsStreak;

  /// No description provided for @statsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get statsTotal;

  /// No description provided for @statsTotalContributions.
  ///
  /// In en, this message translates to:
  /// **'Total Contributions'**
  String get statsTotalContributions;

  /// No description provided for @statsKeepContributing.
  ///
  /// In en, this message translates to:
  /// **'Keep contributing to track trends'**
  String get statsKeepContributing;

  /// No description provided for @statsActivityTrend.
  ///
  /// In en, this message translates to:
  /// **'Activity Trend'**
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
  /// **'Achievements'**
  String get statsAchievements;

  /// No description provided for @statsEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get statsEarnings;

  /// No description provided for @statsVisualizationNote.
  ///
  /// In en, this message translates to:
  /// **'Visualization based on your current activity'**
  String get statsVisualizationNote;

  /// No description provided for @statsAchievementsDescription.
  ///
  /// In en, this message translates to:
  /// **'Unlock badges and milestones as you contribute'**
  String get statsAchievementsDescription;

  /// No description provided for @statsEarningsTracking.
  ///
  /// In en, this message translates to:
  /// **'Earnings Tracking'**
  String get statsEarningsTracking;

  /// No description provided for @statsEarningsDescription.
  ///
  /// In en, this message translates to:
  /// **'Track your earnings and payout history once monetization begins'**
  String get statsEarningsDescription;

  /// No description provided for @statsStartContributing.
  ///
  /// In en, this message translates to:
  /// **'Start Contributing'**
  String get statsStartContributing;

  /// No description provided for @statsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your statistics will appear here once you begin tracking'**
  String get statsEmptyDescription;

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

  /// No description provided for @mapComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Coverage Heatmap Coming Soon'**
  String get mapComingSoonTitle;

  /// No description provided for @mapComingSoonDescription.
  ///
  /// In en, this message translates to:
  /// **'Tile coverage visualization in progress'**
  String get mapComingSoonDescription;

  /// No description provided for @mapCenterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Center on location'**
  String get mapCenterTooltip;

  /// No description provided for @yourContributions.
  ///
  /// In en, this message translates to:
  /// **'YOUR CONTRIBUTIONS'**
  String get yourContributions;

  /// No description provided for @loadingStatsLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading contribution stats'**
  String get loadingStatsLabel;

  /// No description provided for @noContributionsYet.
  ///
  /// In en, this message translates to:
  /// **'No contributions yet. Start tracking to begin.'**
  String get noContributionsYet;

  /// No description provided for @startContributingTitle.
  ///
  /// In en, this message translates to:
  /// **'Start contributing'**
  String get startContributingTitle;

  /// No description provided for @startContributingHint.
  ///
  /// In en, this message translates to:
  /// **'Track your environment to build your coverage map'**
  String get startContributingHint;

  /// No description provided for @areaCovered.
  ///
  /// In en, this message translates to:
  /// **'Area covered'**
  String get areaCovered;

  /// No description provided for @activeStreak.
  ///
  /// In en, this message translates to:
  /// **'Active streak'**
  String get activeStreak;

  /// No description provided for @contributionStatsSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Your contributions: {uploads}. Area covered: {area}. Active streak: {streak}.'**
  String contributionStatsSemanticsLabel(
      String uploads, String area, String streak);

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
  /// **'See what data you\'re contributing right now'**
  String get sensorLiveSubtitle;

  /// No description provided for @sensorInactiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Sensors inactive'**
  String get sensorInactiveTitle;

  /// No description provided for @sensorInactiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start tracking above to begin collecting data'**
  String get sensorInactiveSubtitle;

  /// No description provided for @sensorPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sensors paused'**
  String get sensorPausedTitle;

  /// No description provided for @sensorPausedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Resume tracking to continue collecting data'**
  String get sensorPausedSubtitle;

  /// No description provided for @sensorCollectingFirst.
  ///
  /// In en, this message translates to:
  /// **'Collecting first readings…'**
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
  /// **'Enable location for coverage map and H3 tiles'**
  String get settingsLocationDescription;

  /// No description provided for @settingsMobileDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload contributions over LTE/5G when needed'**
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
  /// **'Remove your contributions'**
  String get settingsDataDeletionDesc;

  /// No description provided for @referralInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get referralInviteTitle;

  /// No description provided for @referralInviteDescription.
  ///
  /// In en, this message translates to:
  /// **'Earn bonus credits when friends contribute data.'**
  String get referralInviteDescription;

  /// No description provided for @referralLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral link copied'**
  String get referralLinkCopied;

  /// No description provided for @referralCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get referralCopyLink;

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

  /// No description provided for @statsFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stats'**
  String get statsFailedToLoad;

  /// No description provided for @statsReadyToContribute.
  ///
  /// In en, this message translates to:
  /// **'Ready to contribute?'**
  String get statsReadyToContribute;

  /// No description provided for @statsFirstContributionHint.
  ///
  /// In en, this message translates to:
  /// **'Start tracking to make your first contribution'**
  String get statsFirstContributionHint;

  /// No description provided for @statsDayStreak.
  ///
  /// In en, this message translates to:
  /// **'Day Streak'**
  String get statsDayStreak;

  /// No description provided for @offlineBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'No connection · data queued locally'**
  String get offlineBannerMessage;

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

  /// No description provided for @batteryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Maximize Your Earnings'**
  String get batteryDialogTitle;

  /// No description provided for @batteryDialogBody.
  ///
  /// In en, this message translates to:
  /// **'To earn 24/7, GreenGains needs to run in the background without being killed by the system.'**
  String get batteryDialogBody;

  /// No description provided for @batteryDialogBodyBold.
  ///
  /// In en, this message translates to:
  /// **'Please disable \"Battery Optimization\" for GreenGains in the next screen.'**
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
  /// **'Set to \'Allow all the time\' for 24/7 collection'**
  String get locationPermBannerBody;

  /// No description provided for @locationPermBannerFix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get locationPermBannerFix;
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
