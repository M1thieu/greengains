// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get onboardingWelcomeTitle => 'Bienvenue sur GreenGains';

  @override
  String get onboardingWelcomeSubtitle =>
      'Aidez à créer des villes plus vertes en collectant passivement des données environnementales.';

  @override
  String get onboardingFeature1Title => 'Collection passive';

  @override
  String get onboardingFeature1Description =>
      'Fonctionne en arrière-plan pendant vos activités. Aucune interaction nécessaire.';

  @override
  String get onboardingFeature2Title => 'Confidentialité d\'abord';

  @override
  String get onboardingFeature2Description =>
      'Le partage de position est optionnel et utilise uniquement une localisation approximative.';

  @override
  String get onboardingFeature3Title => 'Suivez votre impact';

  @override
  String get onboardingFeature3Description =>
      'Visualisez vos contributions et aidez à cartographier les données environnementales de votre ville.';

  @override
  String get onboardingSignInTitle => 'Débloquez des récompenses';

  @override
  String get onboardingSignInSubtitle =>
      'Connectez-vous pour accéder aux récompenses quotidiennes et synchroniser vos données.';

  @override
  String get onboardingDailyPotRewards => 'Pot quotidien';

  @override
  String get onboardingDailyPotDescription =>
      'Gagnez 10 à 100 crédits chaque jour';

  @override
  String get onboardingCloudSync => 'Synchronisation cloud';

  @override
  String get onboardingCloudSyncDescription =>
      'Accédez à vos données depuis n\'importe quel appareil';

  @override
  String get onboardingFutureFeatures => 'Fonctionnalités futures';

  @override
  String get onboardingFutureDescription => 'Classements et compétitions';

  @override
  String onboardingPrivacyNotice(String privacyPolicy, String termsOfService) {
    return 'En continuant, vous acceptez notre $privacyPolicy et nos $termsOfService.';
  }

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get buttonPrevious => 'Précédent';

  @override
  String get buttonNext => 'Suivant';

  @override
  String get signInSuccess => 'Connexion réussie';

  @override
  String get signInError => 'Connexion annulée ou échouée';

  @override
  String get navHome => 'Accueil';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get homeTitle => 'GreenGains';

  @override
  String get startTracking => 'Démarrer le suivi';

  @override
  String get stopTracking => 'Arrêter le suivi';

  @override
  String get trackingActive => 'Suivi actif';

  @override
  String get trackingPaused => 'Suivi en pause';

  @override
  String get trackingStopped => 'Suivi arrêté';

  @override
  String get uploadSuccess => 'Envoi réussi';

  @override
  String get uploadFailed => 'Échec de l\'envoi';

  @override
  String lastUpload(String time) {
    return 'Dernier envoi : $time';
  }

  @override
  String get noUploadYet => 'Aucun envoi pour le moment';

  @override
  String get dailyPotTitle => 'Pot quotidien';

  @override
  String dailyPotClaimButton(int amount) {
    return 'Récupérer $amount crédits';
  }

  @override
  String dailyPotClaimed(int amount) {
    return '+$amount crédits ! 🍯';
  }

  @override
  String get dailyPotAlreadyClaimed =>
      'Déjà récupéré aujourd\'hui ! Revenez demain';

  @override
  String dailyPotNeedMoreUploads(int count, String s) {
    return 'Encore $count envoi$s pour débloquer';
  }

  @override
  String dailyPotProgress(int current, int required) {
    return '$current / $required envois';
  }

  @override
  String credits(int count) {
    return '$count crédits';
  }

  @override
  String get totalCredits => 'Total de crédits';

  @override
  String get creditsEarned => 'Crédits gagnés';

  @override
  String get statsTitle => 'Votre impact';

  @override
  String get totalUploads => 'Total d\'envois';

  @override
  String get todayUploads => 'Envois du jour';

  @override
  String get coverageTiles => 'Tuiles couvertes';

  @override
  String get dataCollected => 'Données collectées';

  @override
  String timesContributed(int count) {
    return '$count contributions';
  }

  @override
  String get mapTitle => 'Carte de couverture';

  @override
  String get mapRecenter => 'Recentrer';

  @override
  String get mapZoomIn => 'Zoomer';

  @override
  String get mapZoomOut => 'Dézoomer';

  @override
  String get mapYourLocation => 'Votre position';

  @override
  String get mapCoverageLegend => 'Couverture';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileSignOut => 'Se déconnecter';

  @override
  String get profileSignedInAs => 'Connecté en tant que';

  @override
  String profileMemberSince(String date) {
    return 'Membre depuis le $date';
  }

  @override
  String get profileDeleteAccount => 'Supprimer le compte';

  @override
  String get profileDeleteConfirm =>
      'Êtes-vous sûr ? Cette action est irréversible.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsGeneral => 'Général';

  @override
  String get settingsPrivacy => 'Confidentialité et données';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Système';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsLocationSharing => 'Partage de position';

  @override
  String get settingsLocationEnabled => 'Partage de position activé';

  @override
  String get settingsLocationDisabled => 'Partage de position désactivé';

  @override
  String get settingsMobileData => 'Envoi sur données mobiles';

  @override
  String get settingsMobileDataEnabled => 'Envoyer sur données mobiles';

  @override
  String get settingsMobileDataDisabled => 'Envoyer uniquement en WiFi';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get permissionLocationTitle => 'Autorisation de localisation';

  @override
  String get permissionLocationMessage =>
      'GreenGains a besoin d\'accéder à votre position pour collecter des données environnementales.';

  @override
  String get permissionLocationButton => 'Autoriser';

  @override
  String get permissionBatteryTitle => 'Optimisation de la batterie';

  @override
  String get permissionBatteryMessage =>
      'Veuillez désactiver l\'optimisation de la batterie pour un suivi en arrière-plan fiable.';

  @override
  String get permissionBatteryButton => 'Ouvrir les paramètres';

  @override
  String get errorGeneric => 'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get errorNetwork => 'Pas de connexion internet';

  @override
  String get errorLocationUnavailable => 'Position indisponible';

  @override
  String get errorUploadFailed =>
      'Échec de l\'envoi. Nouvelle tentative plus tard.';

  @override
  String get errorSignInRequired => 'Veuillez vous connecter pour continuer';

  @override
  String get buttonOk => 'OK';

  @override
  String get buttonCancel => 'Annuler';

  @override
  String get buttonYes => 'Oui';

  @override
  String get buttonNo => 'Non';

  @override
  String get buttonSave => 'Enregistrer';

  @override
  String get buttonDelete => 'Supprimer';

  @override
  String get buttonClose => 'Fermer';

  @override
  String get buttonRetry => 'Réessayer';

  @override
  String get loading => 'Chargement...';

  @override
  String get saving => 'Enregistrement...';

  @override
  String get success => 'Succès';

  @override
  String get error => 'Erreur';

  @override
  String get profileNotSignedIn => 'Non connecté';

  @override
  String get profileSignInPrompt =>
      'Connectez-vous avec Google pour débloquer les récompenses quotidiennes et synchroniser vos données sur tous vos appareils.';

  @override
  String get profileAnonymousNote =>
      'Utilisation anonyme. Les récompenses quotidiennes ne sont pas disponibles.';

  @override
  String get profileUserFallback => 'Utilisateur';

  @override
  String get profileViewStats => 'Voir les statistiques';

  @override
  String get profileContributionsHint => 'Suivez vos contributions';

  @override
  String get profileSignedOut => 'Déconnecté';

  @override
  String get chipContributing => 'En cours';

  @override
  String get chipPaused => 'En pause';

  @override
  String get chipTapStart => 'Démarrer';

  @override
  String get uploadSuccessMessage => 'Contribution envoyée avec succès !';

  @override
  String get semanticsRefreshMap => 'Actualiser les données de la carte';

  @override
  String get semanticsToggleTracking => 'Activer/désactiver le suivi';

  @override
  String get semanticsCenterOnMe => 'Centrer la carte sur ma position';

  @override
  String get tipViewLiveDataTitle => 'Voir les données en direct';

  @override
  String get tipViewLiveDataMessage =>
      'Appuyez ci-dessous pour voir les données que vous contribuez actuellement';

  @override
  String get statsScreenTitle => 'Statistiques';

  @override
  String get statsToday => 'Aujourd\'hui';

  @override
  String get statsStreak => 'Série';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsTotalContributions => 'Total des contributions';

  @override
  String get statsKeepContributing =>
      'Continuez à contribuer pour suivre les tendances';

  @override
  String get statsActivityTrend => 'Tendance d\'activité';

  @override
  String get statsLast7Days => '7 derniers jours';

  @override
  String get statsContributionTimeline => 'Historique des contributions';

  @override
  String get statsAchievements => 'Réalisations';

  @override
  String get statsEarnings => 'Gains';

  @override
  String get statsVisualizationNote =>
      'Visualisation basée sur votre activité actuelle';

  @override
  String get statsAchievementsDescription =>
      'Débloquez des badges et jalons en contribuant';

  @override
  String get statsEarningsTracking => 'Suivi des gains';

  @override
  String get statsEarningsDescription =>
      'Suivez vos gains et l\'historique des paiements une fois la monétisation lancée';

  @override
  String get statsStartContributing => 'Commencer à contribuer';

  @override
  String get statsEmptyDescription =>
      'Vos statistiques apparaîtront ici une fois que vous aurez commencé le suivi';

  @override
  String get statsUpdatedPrefix => 'Mis à jour ';

  @override
  String get statsDayMon => 'Lun';

  @override
  String get statsDayTue => 'Mar';

  @override
  String get statsDayWed => 'Mer';

  @override
  String get statsDayThu => 'Jeu';

  @override
  String get statsDayFri => 'Ven';

  @override
  String get statsDaySat => 'Sam';

  @override
  String get statsDayToday => 'Aujourd\'hui';

  @override
  String get mapLoadingText => 'Chargement de la carte...';

  @override
  String get mapComingSoonTitle => 'Carte de couverture bientôt disponible';

  @override
  String get mapComingSoonDescription =>
      'Visualisation de la couverture en cours';

  @override
  String get mapCenterTooltip => 'Centrer sur la position';

  @override
  String get yourContributions => 'VOS CONTRIBUTIONS';

  @override
  String get loadingStatsLabel => 'Chargement des statistiques';

  @override
  String get noContributionsYet =>
      'Aucune contribution pour le moment. Commencez le suivi.';

  @override
  String get startContributingTitle => 'Commencer à contribuer';

  @override
  String get startContributingHint =>
      'Suivez votre environnement pour construire votre carte de couverture';

  @override
  String get areaCovered => 'Zone couverte';

  @override
  String get activeStreak => 'Série active';

  @override
  String contributionStatsSemanticsLabel(
      String uploads, String area, String streak) {
    return 'Vos contributions : $uploads. Zone couverte : $area. Série active : $streak.';
  }

  @override
  String get noCoverageYet => 'Aucune couverture';

  @override
  String get startTrackingToMap =>
      'Commencez le suivi pour cartographier votre zone';

  @override
  String tilesCount(int count) {
    return '$count tuiles';
  }

  @override
  String get sensorLiveReadings => 'Lectures en direct';

  @override
  String get sensorLiveSubtitle =>
      'Voir les données que vous contribuez en ce moment';

  @override
  String get sensorInactiveTitle => 'Capteurs inactifs';

  @override
  String get sensorInactiveSubtitle =>
      'Démarrez le suivi ci-dessus pour commencer à collecter des données';

  @override
  String get sensorPausedTitle => 'Capteurs en pause';

  @override
  String get sensorPausedSubtitle =>
      'Reprenez le suivi pour continuer à collecter des données';

  @override
  String get sensorCollectingFirst => 'Collecte des premières lectures…';

  @override
  String get sensorAroundYou => 'Autour de vous';

  @override
  String get sensorMovement => 'Mouvement';

  @override
  String get sensorLight => 'Lumière';

  @override
  String get sensorMagneticField => 'Champ magnétique';

  @override
  String get sensorOrientation => 'Orientation';

  @override
  String get sensorAirPressure => 'Pression de l\'air';

  @override
  String get sensorAccelerationIntensity => 'Intensité d\'accélération';

  @override
  String get sensorRotationSpeed => 'Vitesse de rotation';

  @override
  String get sensorAtmosphericPressure => 'Pression atmosphérique';

  @override
  String get sensorStatusPaused => 'En pause';

  @override
  String get sensorStatusConnecting => 'Connexion…';

  @override
  String get sensorStatusLive => 'En direct';

  @override
  String get lightDark => 'Sombre';

  @override
  String get lightDim => 'Faible';

  @override
  String get lightNormal => 'Normal';

  @override
  String get lightBright => 'Lumineux';

  @override
  String get lightVeryBright => 'Très lumineux';

  @override
  String get magnetVeryLow => 'Très faible';

  @override
  String get magnetNormal => 'Normal';

  @override
  String get magnetElevated => 'Élevé';

  @override
  String get magnetHighNearMetal => 'Élevé — près d\'un métal';

  @override
  String daysActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get trackingFabStarting => 'Démarrage…';

  @override
  String get trackingFabPause => 'Mettre en pause';

  @override
  String get trackingFabResume => 'Reprendre le suivi';

  @override
  String get trackingFabStart => 'Démarrer le suivi';

  @override
  String get trackingErrorUpdateFailed =>
      'Impossible de mettre à jour le suivi — veuillez réessayer.';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsThemeAuto => 'Auto';

  @override
  String get settingsLocationDescription =>
      'Activer la localisation pour la carte de couverture et les tuiles H3';

  @override
  String get settingsMobileDataDescription =>
      'Envoyer les contributions via LTE/5G si nécessaire';

  @override
  String get settingsLegal => 'Légal';

  @override
  String get settingsPrivacyPolicyDesc => 'Comment nous gérons vos données';

  @override
  String get settingsTermsOfServiceDesc =>
      'Conditions générales d\'utilisation';

  @override
  String get settingsDataDeletion => 'Demande de suppression des données';

  @override
  String get settingsDataDeletionDesc => 'Supprimer vos contributions';

  @override
  String get referralInviteTitle => 'Inviter un ami';

  @override
  String get referralInviteDescription =>
      'Gagnez des crédits bonus lorsque vos amis contribuent des données.';

  @override
  String get referralLinkCopied => 'Lien de parrainage copié';

  @override
  String get referralCopyLink => 'Copier le lien';

  @override
  String get tooltipRefresh => 'Actualiser';

  @override
  String get tooltipDismiss => 'Fermer';

  @override
  String get statsFailedToLoad => 'Impossible de charger les statistiques';

  @override
  String get statsReadyToContribute => 'Prêt à contribuer ?';

  @override
  String get statsFirstContributionHint =>
      'Commencez le suivi pour faire votre première contribution';

  @override
  String get statsDayStreak => 'Jours de suite';
}
