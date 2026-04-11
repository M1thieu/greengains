// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get onboardingWelcomeTitle => 'Votre ville, cartographiée rue par rue';

  @override
  String get onboardingWelcomeSubtitle =>
      'Votre téléphone mesure silencieusement lumière, pression et mouvement pendant vos déplacements. Aucune interaction nécessaire — vous marchez, il cartographie.';

  @override
  String get onboardingFeature1Title => 'Fonctionne silencieusement';

  @override
  String get onboardingFeature1Description =>
      'Actif en arrière-plan pendant vos trajets, promenades ou sommeil. Aucune interaction nécessaire, jamais.';

  @override
  String get onboardingFeature2Title => 'Anonymisé par conception';

  @override
  String get onboardingFeature2Description =>
      'Vos données sont regroupées avec des milliers d\'autres avant de quitter votre appareil. Aucun historique de position, aucune donnée personnelle — jamais.';

  @override
  String get onboardingFeature3Title => 'Des données réelles, un impact réel';

  @override
  String get onboardingFeature3Description =>
      'Vos trajets apparaissent sur une carte en direct utilisée par des chercheurs et des urbanistes. Chaque rue parcourue ajoute une donnée qui n\'existait pas avant.';

  @override
  String get onboardingSignInTitle => 'Rejoindre le réseau';

  @override
  String get onboardingSignInSubtitle =>
      'Une seule connexion — votre carte et vos progrès vous suivent partout.';

  @override
  String get onboardingCloudSync => 'Carte de couverture en direct';

  @override
  String get onboardingCloudSyncDescription =>
      'Regardez votre zone de couverture personnelle s\'agrandir en temps réel';

  @override
  String get onboardingFutureFeatures => 'Bientôt disponible';

  @override
  String get onboardingFutureDescription =>
      'Jalons contributeurs, rapports d\'impact et bien plus';

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
  String get navStats => 'Stats';

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
      'Autorisez la localisation pour commencer à cartographier votre ville.';

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
      'Connectez-vous avec Google pour suivre votre progression et synchroniser vos contributions.';

  @override
  String get profileAnonymousNote =>
      'Utilisation anonyme. Connectez-vous pour suivre votre progression.';

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
  String get chipTapStart => 'Appuyer ▶';

  @override
  String get homeFirstUseHint =>
      'Cartographie la ville silencieusement pendant vos déplacements';

  @override
  String get uploadSuccessMessage => 'Carte mise à jour !';

  @override
  String uploadSuccessNewZone(int count) {
    return 'Nouvelle zone · $count sur votre carte';
  }

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
  String statsStreakBest(int days) {
    return 'RECORD ${days}J';
  }

  @override
  String get statsDaysActive => 'Jours actifs';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsCoverage => 'Zones';

  @override
  String get statsAreasLabel => 'zones cartographiées';

  @override
  String get statsDataPtsLabel => 'envois';

  @override
  String get statsKmMapped => 'km² cartographiés';

  @override
  String get statsBestDay => 'meilleur jour';

  @override
  String get statsStreakLabel => 'série';

  @override
  String get statsRecordStreak => 'record';

  @override
  String statsBarCalloutUploads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count envois',
      one: '1 envoi',
    );
    return '$_temp0';
  }

  @override
  String get statsBarCalloutToday => 'Aujourd\'hui';

  @override
  String get statsBarCalloutBest => 'Meilleur jour';

  @override
  String get infoKmTitle => 'Territoire cartographié';

  @override
  String get infoKmBody =>
      'Chaque hexagone sur votre carte couvre environ 0,1 km². Cela représente la surface de votre ville que vous avez personnellement cartographiée.';

  @override
  String get infoDataPtsTitle => 'Points de données';

  @override
  String get infoDataPtsBody =>
      'Chaque envoi transmet un lot de mesures capteurs — lumière, pression, mouvement. Plus il y a de points, plus la couverture est riche.';

  @override
  String get infoDaysActiveTitle => 'Jours actifs';

  @override
  String get infoDaysActiveBody =>
      'Le nombre de jours distincts où vous avez contribué. Pas besoin de contribuer tous les jours.';

  @override
  String get infoBestDayTitle => 'Meilleur jour';

  @override
  String get infoBestDayBody =>
      'Votre jour le plus actif cette semaine, mesuré en points de données envoyés. Un chiffre élevé signifie généralement plus de temps en extérieur.';

  @override
  String get infoMilestoneTitle => 'Prochain palier';

  @override
  String get infoMilestoneBody =>
      'Les paliers mesurent la croissance de votre territoire. Chaque nouvel hexagone cartographié compte pour le niveau suivant.';

  @override
  String get infoTileQualityTitle => 'Qualité de couverture';

  @override
  String get infoTileQualityBody =>
      'La qualité reflète le nombre et la cohérence des mesures collectées dans cette zone. Vert = données solides, jaune = partiel, rouge = sparse.';

  @override
  String get infoTilePersonalTitle => 'Votre zone';

  @override
  String get infoTilePersonalBody =>
      'Vous avez cartographié cette zone. Votre téléphone a enregistré ici lors de vos déplacements.';

  @override
  String get infoTileCommunityTitle => 'Zone communautaire';

  @override
  String get infoTileCommunityBody =>
      'Cette zone a été cartographiée par d\'autres utilisateurs. Ensemble vous construisez une carte à l\'échelle de la ville.';

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
  String get statsTodayLabel => 'AUJOURD\'HUI';

  @override
  String get statsHistoryNote =>
      'L\'historique hebdomadaire apparaîtra après plusieurs jours de données';

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
  String get statsStartContributing => 'Rien à afficher pour l\'instant';

  @override
  String get statsEmptyDescription =>
      'Allez sur la carte et appuyez sur ▶ — vos stats apparaîtront après votre premier envoi.';

  @override
  String get statsEmptyGoMap => 'Aller sur la carte';

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
  String get impactCardContext => 'envois — partagés anonymement';

  @override
  String get loadingStatsLabel => 'Chargement des statistiques';

  @override
  String get noContributionsYet =>
      'Aucune contribution pour le moment. Commencez le suivi.';

  @override
  String get startContributingTitle => 'Commencer à contribuer';

  @override
  String get startContributingHint =>
      'Votre téléphone cartographie silencieusement la ville pendant vos déplacements';

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
  String get chipZones => 'zones';

  @override
  String get chipSensors => 'signaux';

  @override
  String homeZonesMapped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones cartographiées',
      one: '1 zone cartographiée',
    );
    return '$_temp0';
  }

  @override
  String get tileInfoSamplesLabel => 'mesures';

  @override
  String get tileInfoDevicesLabel => 'contributeurs';

  @override
  String get tileInfoQualityLabel => 'Qualité des données';

  @override
  String get tileInfoAreaLabel => 'surface';

  @override
  String get tileInfoPersonal => 'Personnel';

  @override
  String get tileInfoCommunity => 'Communauté';

  @override
  String tileInfoSamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesures',
      one: '1 mesure',
    );
    return '$_temp0';
  }

  @override
  String get tileInfoConfidence => 'Confiance';

  @override
  String get tileInfoQuality => 'Qualité de l\'air';

  @override
  String tileInfoDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributeurs',
      one: '1 contributeur',
    );
    return '$_temp0';
  }

  @override
  String get tileScanningNow => 'En cours de scan';

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
  String get sensorAcceleration => 'Accélération';

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
      'Nécessaire pour la carte de couverture en direct';

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
  String get settingsDataSection => 'Données';

  @override
  String settingsConsentDate(String date) {
    return 'Consentement : $date';
  }

  @override
  String get settingsDataRetention => 'Conservation : 7 jours (Gratuit)';

  @override
  String get onboardingDataCollectedTitle => 'Ce que nous collectons';

  @override
  String get onboardingDataCollectedDescription =>
      'Lumière, mouvement, pression et position anonyme — agrégés avec 100 000+ appareils avant toute analyse.';

  @override
  String get referralInviteTitle => 'Inviter des amis';

  @override
  String get referralInviteDescription =>
      'Invitez des amis à cartographier votre ville. Chaque personne ajoute des rues que vous n\'avez pas encore parcourues.';

  @override
  String get referralLinkCopied => 'Lien de parrainage copié';

  @override
  String get referralCopyLink => 'Copier le lien';

  @override
  String referralConversions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amis ont rejoint',
      one: '1 ami a rejoint',
      zero: 'Aucun ami rejoint pour l\'instant',
    );
    return '$_temp0';
  }

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

  @override
  String get offlineBannerMessage => 'Hors connexion · données en attente';

  @override
  String get statsWeeklyLabel => '7 JOURS';

  @override
  String statsWeeklyTotal(int count) {
    return '$count cette semaine';
  }

  @override
  String get statsMilestoneLabel => 'Prochain palier';

  @override
  String get statsMilestoneHint =>
      'Les récompenses se débloquent à ce palier — continuez à contribuer';

  @override
  String get statsMilestoneElite =>
      'Contributeur élite · tous les paliers atteints';

  @override
  String statsMilestoneRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones restantes',
      one: '1 zone restante',
    );
    return '$_temp0';
  }

  @override
  String statsCommunityAreas(int count) {
    return '$count zones cartographiées par la communauté';
  }

  @override
  String get batteryDialogTitle => 'Maximisez votre impact';

  @override
  String get batteryDialogBody =>
      'Pour contribuer 24h/24, GreenGains doit fonctionner en arrière-plan sans être arrêté par le système.';

  @override
  String get batteryDialogBodyBold =>
      'Veuillez désactiver l\'« Optimisation de la batterie » pour GreenGains dans l\'écran suivant.';

  @override
  String get batteryDialogDismissForever => 'Ne plus afficher';

  @override
  String get batteryDialogLater => 'Plus tard';

  @override
  String get batteryDialogAllow => 'Autoriser l\'exécution en arrière-plan';

  @override
  String get batteryDialogError =>
      'Impossible d\'ouvrir les paramètres de la batterie';

  @override
  String get locationPermBannerBody =>
      'Choisissez \'Toujours autoriser\' pour collecter en continu';

  @override
  String get locationPermBannerFix => 'Corriger';

  @override
  String get legendYou => 'Vous';

  @override
  String get legendCommunity => 'Communauté';

  @override
  String get referralStepShare => 'Partager';

  @override
  String get referralStepJoin => 'Ils rejoignent';

  @override
  String get referralStepEarn => 'Carte grandit';

  @override
  String get settingsDiagnostics => 'Diagnostics capteurs';

  @override
  String get settingsDiagnosticsDesc =>
      'Lectures en temps réel de vos capteurs';

  @override
  String get sensorLiveSheetTitle => 'Ce que vous mesurez';

  @override
  String get tileQualityExcellent => 'Excellente couverture — bien enregistrée';

  @override
  String get tileQualityGood => 'Bonnes données — couverture utile';

  @override
  String get tileQualityFair =>
      'Données partielles — plus de passages nécessaires';

  @override
  String get tileMeasuredWith => 'Capteurs actifs';

  @override
  String get legendHighLabel => 'Qualité élevée';

  @override
  String get legendHighSub => '≥75% de lectures valides';

  @override
  String get legendMidLabel => 'Qualité moyenne';

  @override
  String get legendMidSub => '50–74% de lectures valides';

  @override
  String get legendLowLabel => 'Qualité faible';

  @override
  String get legendLowSub => 'Moins de 50% — besoin de plus de données';

  @override
  String get legendCommunitySub => 'Cartographié par d\'autres contributeurs';

  @override
  String get permissionPrimingTitle => 'Une chose avant de commencer';

  @override
  String get permissionPrimingBattery =>
      'Moins de 1 % de batterie par heure — comme une appli météo';

  @override
  String get permissionPrimingCollects =>
      'Nous collectons la lumière ambiante, la pression et le mouvement — jamais votre identité';

  @override
  String get permissionPrimingCta => 'Activer la localisation';

  @override
  String get firstStartTitle => 'Vous êtes en direct';

  @override
  String get firstStartBody =>
      'Marchez, navettez, vivez normalement — votre première zone apparaîtra bientôt sur la carte';

  @override
  String get alwaysOnBannerBody =>
      'Définissez la localisation sur \'Toujours\' pour la collecte en arrière-plan';

  @override
  String get alwaysOnBannerFix => 'Corriger';

  @override
  String milestoneReachedTitle(int count) {
    return '$count zones cartographiées';
  }

  @override
  String get milestoneReachedBody =>
      'Vous construisez une vraie carte de votre ville. Continuez.';

  @override
  String get milestoneReachedCta => 'Continuer à cartographier';
}
