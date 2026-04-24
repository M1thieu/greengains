// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get onboardingWelcomeTitle => 'Remplissez votre terrain.';

  @override
  String get onboardingWelcomeSubtitle =>
      'Bougez où vous voulez. Votre téléphone lit discrètement le monde — lumière, pression, mouvement — et le cartographie.';

  @override
  String get onboardingFeature1Title => 'Zéro interaction. Jamais.';

  @override
  String get onboardingFeature1Description =>
      'Lancez une fois, oubliez-le — votre carte se remplit pendant que vous bougez.';

  @override
  String get onboardingFeature2Title => 'Privé par défaut';

  @override
  String get onboardingFeature2Description =>
      'Votre trajet n\'est jamais conservé — les données sont anonymisées avant de quitter votre téléphone.';

  @override
  String get onboardingFeature3Title => 'Chaque rue, à vous.';

  @override
  String get onboardingFeature3Description =>
      'Chaque endroit visité se remplit sur votre carte — voyez jusqu\'où s\'étend votre terrain.';

  @override
  String get onboardingSignInTitle => 'Votre territoire commence ici';

  @override
  String get onboardingSignInSubtitle =>
      'Connectez-vous pour garder votre territoire synchronisé sur tous vos appareils.';

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
  String get statsTitle => 'Votre terrain';

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
  String get settingsLocationSharing => 'Partage de position';

  @override
  String get settingsMobileData => 'Envoi sur données mobiles';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get permissionLocationTitle => 'Autorisation de localisation';

  @override
  String get permissionLocationMessage =>
      'Autorisez la localisation pour commencer à cartographier votre terrain.';

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
      'Connectez-vous avec Google pour garder votre territoire synchronisé.';

  @override
  String get profileAnonymousNote =>
      'Utilisation anonyme. Connectez-vous pour sauvegarder votre territoire.';

  @override
  String get profileUserFallback => 'Utilisateur';

  @override
  String get profileViewStats => 'Voir les statistiques';

  @override
  String get profileContributionsHint => 'Voir votre territoire';

  @override
  String get profileSignedOut => 'Déconnecté';

  @override
  String get chipContributing => 'Cartographie';

  @override
  String get chipPaused => 'En pause';

  @override
  String get chipTapStart => 'Pas de suivi · Appuyer ▶';

  @override
  String chipDataPts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pts',
      one: '1 pt',
    );
    return '$_temp0';
  }

  @override
  String homeSessionZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count zones complétées',
      one: '+1 zone complétée',
      zero: 'Analyse en cours',
    );
    return '$_temp0';
  }

  @override
  String get homeYourMap => 'VOTRE CARTE';

  @override
  String homeCityPct(String pct) {
    return '$pct% de la ville explorée';
  }

  @override
  String get profileImpactSection => 'VOTRE IMPACT';

  @override
  String get profileAccountSection => 'COMPTE';

  @override
  String get homeFirstUseHint =>
      'Appuyez sur ▶ — regardez votre première zone apparaître';

  @override
  String get homeFirstTrackingHint =>
      'Capteur lumière, pression, mouvement — première zone après le premier envoi';

  @override
  String homeTrackingReadings(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString mesures capturées',
      one: '1 mesure capturée',
    );
    return '$_temp0';
  }

  @override
  String homeReturnHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones sur votre carte — appuyez sur ▶ pour continuer',
      one: '1 zone sur votre carte — appuyez sur ▶ pour continuer',
    );
    return '$_temp0';
  }

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
  String get statsThisWeek => 'Cette semaine';

  @override
  String get statsDaysActive => 'Jours actifs';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsCoverage => 'Zones';

  @override
  String get statsAreasLabel => 'zones cartographiées';

  @override
  String get statsDataPtsLabel => 'enregistrements';

  @override
  String get statsKmMapped => 'km² cartographiés';

  @override
  String get statsBestDay => 'Meilleur jour';

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
      'Chaque hexagone couvre ~0,1 km² — c\'est votre empreinte personnelle sur la carte.';

  @override
  String get infoDataPtsTitle => 'Envois';

  @override
  String get infoDataPtsBody =>
      'Chaque envoi capture lumière, pression et mouvement — plus d\'envois = carte plus dense.';

  @override
  String get infoTodayTitle => 'Enregistrements aujourd\'hui';

  @override
  String get infoTodayBody =>
      'Mesures envoyées aujourd\'hui — lumière, pression et mouvement à chaque arrêt.';

  @override
  String get infoThisWeekTitle => 'Cette semaine';

  @override
  String get infoThisWeekBody =>
      'Enregistrements des 7 derniers jours — la régularité enrichit la carte.';

  @override
  String get infoDaysActiveTitle => 'Jours actifs';

  @override
  String get infoDaysActiveBody =>
      'Jours où vous avez contribué — pas besoin d\'être actif tous les jours.';

  @override
  String get infoBestDayTitle => 'Meilleur jour';

  @override
  String get infoBestDayBody =>
      'Votre jour le plus actif cette semaine — souvent plus de temps en extérieur.';

  @override
  String get infoMilestoneTitle => 'Prochain palier';

  @override
  String get infoMilestoneBody =>
      'Chaque nouvelle zone cartographiée compte pour le prochain palier.';

  @override
  String get infoTileQualityTitle => 'Qualité de couverture';

  @override
  String get infoTileQualityBody =>
      'Vert = bien couvert, jaune = partiel, rouge = plus de passages nécessaires.';

  @override
  String get infoTilePersonalTitle => 'Votre zone';

  @override
  String get infoTilePersonalBody =>
      'Votre téléphone a enregistré ici — c\'est votre terrain.';

  @override
  String get infoTileCommunityTitle => 'Zone communautaire';

  @override
  String get infoTileCommunityBody =>
      'Cartographié par d\'autres — leur terrain, pas le vôtre. Pas encore.';

  @override
  String get statsTotalContributions => 'Total des contributions';

  @override
  String get statsActivityTrend => 'Cette semaine';

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
  String get statsStartContributing => 'Votre carte est vide.';

  @override
  String get statsEmptyDescription =>
      'Appuyez sur ▶. Votre première zone attend d\'être cartographiée.';

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
  String get mapCenterTooltip => 'Centrer sur la position';

  @override
  String get yourContributions => 'VOTRE TERRITOIRE';

  @override
  String get impactCardContext => 'zones cartographiées';

  @override
  String get loadingStatsLabel => 'Chargement des statistiques';

  @override
  String get noContributionsYet =>
      'Rien d\'enregistré — appuyez sur ▶ pour démarrer.';

  @override
  String get startContributingTitle => 'Commencer à cartographier';

  @override
  String get startContributingHint =>
      'Votre téléphone cartographie silencieusement pendant vos déplacements';

  @override
  String get areaCovered => 'Zone couverte';

  @override
  String get activeStreak => 'Territoire';

  @override
  String contributionStatsSemanticsLabel(String uploads, String area) {
    return 'Vos contributions : $uploads. Zone couverte : $area.';
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
  String get tileOnlyYouMapped => 'Seul(e) toi as cartographié cette zone';

  @override
  String get tickerMotionStill => 'immobile';

  @override
  String get tickerMotionMoving => 'en mouvement';

  @override
  String get tickerMotionActive => 'actif';

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
  String get sensorLiveSubtitle => 'Lectures en temps réel de votre téléphone.';

  @override
  String get sensorInactiveTitle => 'Rien n\'est enregistré';

  @override
  String get sensorInactiveSubtitle =>
      'Démarrez le suivi pour commencer à enregistrer';

  @override
  String get sensorPausedTitle => 'Enregistrement en pause';

  @override
  String get sensorPausedSubtitle =>
      'Reprenez le suivi pour continuer à enregistrer';

  @override
  String get sensorCollectingFirst => 'Démarrage…';

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
      'Envoyer via LTE/5G si nécessaire';

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
  String get settingsDataDeletionDesc =>
      'Effacer toutes vos données enregistrées';

  @override
  String get settingsDataSection => 'Données';

  @override
  String settingsConsentDate(String date) {
    return 'Consentement : $date';
  }

  @override
  String get settingsDataRetention => 'Données conservées 7 jours (Gratuit)';

  @override
  String get referralInviteTitle => 'Inviter des amis';

  @override
  String get referralInviteDescription =>
      'Chaque ami couvre un terrain que vous n\'avez pas encore atteint.';

  @override
  String get referralLinkCopied => 'Lien de parrainage copié';

  @override
  String get referralCopyLink => 'Copier le lien';

  @override
  String get referralShareLink => 'Partager le lien d\'invitation';

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
  String get statsHighlightsLabel => 'FAITS MARQUANTS';

  @override
  String get statsMappingSince => 'Cartographie depuis';

  @override
  String get statsFailedToLoad => 'Impossible de charger les statistiques';

  @override
  String get statsReadyToContribute => 'Votre terrain vous attend.';

  @override
  String get statsFirstContributionHint =>
      'Commencez le suivi pour cartographier votre première zone';

  @override
  String get statsWeeklyLabel => '7 JOURS';

  @override
  String statsWeeklyTotal(int count) {
    return '$count cette semaine';
  }

  @override
  String get statsMilestoneLabel => 'Niveau suivant';

  @override
  String get statsMilestoneHint =>
      'Cartographiez suffisamment de terrain pour atteindre ce niveau et débloquer le suivant';

  @override
  String get statsMilestoneElite => 'Tout cartographié · statut explorateur';

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
  String get batteryDialogTitle => 'Continuez à cartographier';

  @override
  String get batteryDialogBody =>
      'Désactivez l\'optimisation de la batterie pour que l\'appli continue de cartographier en arrière-plan.';

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
      'Choisissez \'Toujours autoriser\' pour cartographier en arrière-plan';

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
  String get permissionPrimingBattery => 'Batterie intelligente';

  @override
  String get permissionPrimingBatteryDesc =>
      'Moins d\'1 % par heure — s\'adapte automatiquement en arrière-plan';

  @override
  String get permissionPrimingCollects => 'Conçu pour la vie privée';

  @override
  String get permissionPrimingCollectsDesc =>
      'Lumière, pression et mouvement uniquement — jamais votre trajet ni votre identité';

  @override
  String get permissionPrimingCta => 'Activer la localisation';

  @override
  String get settingsBatteryMode => 'Batterie intelligente';

  @override
  String get settingsBatteryModeDesc =>
      'Discret à l\'arrêt, précis en mouvement — s\'adapte automatiquement';

  @override
  String get firstStartTitle => 'Cartographie en cours.';

  @override
  String get firstStartBody =>
      'Bougez — les zones apparaissent au fil de vos pas.';

  @override
  String get alwaysOnBannerBody =>
      'Définissez la localisation sur \'Toujours\' pour continuer à cartographier en arrière-plan';

  @override
  String get alwaysOnBannerFix => 'Corriger';

  @override
  String milestoneReachedTitle(int count) {
    return '$count zones cartographiées';
  }

  @override
  String get milestoneReachedBody => 'Jusqu\'où pouvez-vous aller ?';

  @override
  String get milestoneReachedCta => 'Continuer';

  @override
  String get firstUploadTitle => 'Première zone cartographiée.';

  @override
  String get firstUploadBody =>
      'Continuez à bouger — votre territoire grandit.';

  @override
  String get firstUploadCta => 'Voir ma carte';

  @override
  String onboardingSocialProof(int count) {
    return '$count personnes cartographient déjà leur terrain';
  }

  @override
  String sessionSummaryZonesClaimed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'zones cartographiées',
      one: 'zone cartographiée',
    );
    return '$_temp0';
  }

  @override
  String sessionSummaryTotal(int zones, String km2) {
    return 'Territoire total : $zones zones · $km2 km²';
  }

  @override
  String get sessionSummaryCta => 'Voir mon territoire';

  @override
  String get sessionSummaryDone => 'Terminé';

  @override
  String get statsMapGrowing => 'carte en cours — continuez à marcher';

  @override
  String get statsWeeklyChartOffline =>
      'Graphique hebdomadaire disponible une fois connecté';

  @override
  String uploadMilestone(int count) {
    return '$count envois — continuez !';
  }

  @override
  String get statsViewOnMap => 'Voir sur la carte';

  @override
  String statsCommunityMappers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributeurs actifs ce mois',
      one: '1 contributeur actif ce mois',
    );
    return '$_temp0';
  }

  @override
  String tileFirstMapped(String date) {
    return 'Cartographié le $date';
  }

  @override
  String statsSinceDate(String date) {
    return 'depuis $date';
  }

  @override
  String get statsStreakLabel => 'Série';

  @override
  String statsStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours de suite',
      one: '1 jour de suite',
    );
    return '$_temp0';
  }

  @override
  String get tileCommunityClaimCta =>
      'Cartographiez ici pour conquérir cette zone';

  @override
  String get tileLowQualityHint => 'Repassez ici pour renforcer cette zone.';

  @override
  String homeCommunityScopeHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones cartographiées dans votre secteur',
      one: '1 zone cartographiée dans votre secteur',
    );
    return '$_temp0';
  }

  @override
  String get tileCivicNote =>
      'Vos données enrichissent la carte environnementale.';

  @override
  String sessionSummaryShareText(int gained, int total, String km2) {
    return 'J\'ai cartographié +$gained zones aujourd\'hui — $total zones au total · $km2 km²';
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
    return 'mouvement $val';
  }

  @override
  String get sensorLuxDark => 'sombre';

  @override
  String get sensorLuxIndoor => 'lumière intérieure';

  @override
  String get sensorLuxBright => 'lumineux';

  @override
  String get sensorLuxDirect => 'plein soleil';

  @override
  String get sensorMovementLow => 'immobile';

  @override
  String get sensorMovementMid => 'actif';

  @override
  String get sensorMovementHigh => 'fort trafic';

  @override
  String get sensorHpaLow => 'basse altitude';

  @override
  String get sensorHpaMid => 'altitude moyenne';

  @override
  String get sensorHpaHigh => 'haute altitude';

  @override
  String get tileSensorInsightsLabel => 'Ce que vos capteurs ont enregistré';

  @override
  String territoryHeroLabel(String neighborhood, int count) {
    return '$neighborhood · $count zones';
  }

  @override
  String get serverWakingUp => 'Démarrage en cours — encore un instant…';

  @override
  String referralNeighborhoodHook(String neighborhood) {
    return 'Aidez à cartographier $neighborhood — chaque voisin couvre ce que vous n\'avez pas encore atteint.';
  }

  @override
  String get onboardingActivateTitle => 'Presque là';

  @override
  String get onboardingActivateSubtitle =>
      'Autorisez la localisation — votre téléphone cartographie pendant vos déplacements.';

  @override
  String get onboardingActivateCta => 'Commencer à cartographier';

  @override
  String homeMaxClusterHint(int count) {
    return 'territoire de $count zones';
  }

  @override
  String get firstUploadBadge => 'PREMIÈRE ZONE TÉLÉCHARGÉE';

  @override
  String get firstUploadHeadline => 'Votre première zone est sur la carte.';

  @override
  String get firstUploadSubtext =>
      'Elle rejoint un registre de lumière, pression et mouvement — anonymisé, agrégé.';

  @override
  String get firstUploadSensorsLabel => 'CAPTEURS';

  @override
  String get firstUploadSensorsValue => 'lumière · mouvement · pression';

  @override
  String get firstUploadPrivacyLabel => 'CONFIDENTIALITÉ';

  @override
  String get firstUploadPrivacyValue => 'anonymisé';

  @override
  String get firstUploadKeepMappingCta => 'Continuer à cartographier';

  @override
  String get liveSensorsHeader => 'CAPTEURS EN DIRECT';

  @override
  String get liveSensorMotionLabel => 'Mouvement';

  @override
  String get liveSensorPressureLabel => 'Pression';

  @override
  String get sessionSummaryBadge => 'SESSION TERMINÉE';

  @override
  String get sessionSummaryZonesGainedLabel => 'ZONES GAGNÉES';

  @override
  String get sessionSummarySubline => 'nouveau terrain, tracé en';

  @override
  String get sessionSummaryWatermark => 'Cartographié avec GreenGains';

  @override
  String get sessionSummaryShareCta => 'Partager';

  @override
  String get sessionStatArea => 'SURFACE';

  @override
  String get sessionStatDuration => 'DURÉE';

  @override
  String get sessionStatTotal => 'TOTAL';

  @override
  String statsMilestoneTarget(int target) {
    return '$target zones';
  }
}
