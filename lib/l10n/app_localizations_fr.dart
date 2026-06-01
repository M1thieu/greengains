// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get onboardingWelcomeTitle => 'Enfin connaître son quartier.';

  @override
  String get onboardingWelcomeSubtitle =>
      'Votre téléphone lit la lumière, la pression et le mouvement pendant que vous marchez. Il construit une carte de tous les endroits où vous êtes allé.';

  @override
  String get onboardingFeature1Title => 'Rien à faire.';

  @override
  String get onboardingFeature1Description =>
      'Lancez une fois, gardez votre téléphone. La carte se construit seule.';

  @override
  String get onboardingFeature2Title => 'Privé par défaut';

  @override
  String get onboardingFeature2Description =>
      'Votre trajet n\'est jamais conservé. Les données sont anonymisées avant de quitter votre téléphone.';

  @override
  String get onboardingFeature3Title => 'Voyez jusqu\'où vous êtes allé.';

  @override
  String get onboardingFeature3Description =>
      'Chaque endroit visité apparaît sur votre carte. Repassez par les mêmes rues, regardez-les se remplir.';

  @override
  String get onboardingSignInTitle => 'Votre carte commence ici.';

  @override
  String get onboardingSignInSubtitle =>
      'Connectez-vous pour garder votre carte synchronisée sur tous vos appareils.';

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
  String get homeIdleTagline => 'Ton quartier, cartographié par toi';

  @override
  String get homeIdleSubtitle =>
      'Marche où tu veux — ton téléphone lit la lumière, la pression et le mouvement.';

  @override
  String homeStatPlaces(int count) {
    return '$count endroits';
  }

  @override
  String homeStatStreak(int count) {
    return '$count jours d\'affilée';
  }

  @override
  String get homeActionStart => 'Démarrer';

  @override
  String get homeActionStop => 'Arrêter';

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
  String get statsTitle => 'Votre carte';

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
  String profileLastMapped(String ago) {
    return 'Dernière cartographie $ago';
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
  String get settingsDisplay => 'Affichage';

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
      'Autorisez la localisation pour que votre téléphone cartographie pendant vos déplacements.';

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
      'Synchronisation impossible. Nouvelle tentative plus tard.';

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
  String get profileUserFallback => 'Utilisateur';

  @override
  String get chipContributing => 'Cartographie';

  @override
  String get chipPaused => 'En pause';

  @override
  String get chipTapStart => 'Appuie sur ▶ pour commencer';

  @override
  String get chipTapStartFirst => 'Commence à cartographier ton quartier';

  @override
  String chipDataPts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scans',
      one: '1 scan',
    );
    return '$_temp0';
  }

  @override
  String homeSessionZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count nouveaux endroits',
      one: '+1 nouvel endroit',
      zero: 'Cartographie',
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
  String get profileImpactSection => 'VOTRE CARTE';

  @override
  String get homeFirstUseHint =>
      'Appuyez sur ▶ pour voir votre premier endroit apparaître';

  @override
  String get homeFirstTrackingHint =>
      'Mesure la luminosité, l\'activité et la météo. Premier endroit après l\'envoi.';

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
      other: '$count endroits sur ta carte. Appuie sur ▶ pour explorer plus',
      one: '1 endroit sur ta carte. Appuie sur ▶ pour explorer plus',
    );
    return '$_temp0';
  }

  @override
  String get uploadSuccessMessage => 'Carte mise à jour !';

  @override
  String uploadSuccessNewZone(int count) {
    return 'Nouvel endroit ajouté · $count sur ta carte';
  }

  @override
  String get semanticsRefreshMap => 'Actualiser les données de la carte';

  @override
  String get semanticsToggleTracking => 'Activer/désactiver le suivi';

  @override
  String get semanticsCenterOnMe => 'Centrer la carte sur ma position';

  @override
  String semanticsZoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits : voir les stats',
      one: '1 endroit : voir les stats',
    );
    return '$_temp0';
  }

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
  String get statsCoverage => 'Endroits';

  @override
  String get statsAreasLabel => 'endroits couverts';

  @override
  String get statsDataPtsLabel => 'fois cartographié';

  @override
  String get statsKmMapped => 'surface couverte';

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
  String get statsBarCalloutToday => 'Aujourd\'hui';

  @override
  String get statsBarCalloutBest => 'Meilleur jour';

  @override
  String get statsBestDayLabel => 'Meilleur jour';

  @override
  String get statsAvgPerDay => 'Moy. / jour';

  @override
  String get statsVerdictStrong => 'Excellente semaine';

  @override
  String get statsVerdictGood => 'Bonne semaine';

  @override
  String get statsVerdictSlow => 'Semaine calme';

  @override
  String get statsVerdictNone => 'Pas encore';

  @override
  String statsVerdictSubStrong(int days) {
    return 'Tu as cartographié $days jours sur 7 — continue comme ça.';
  }

  @override
  String statsVerdictSubGood(int days) {
    return 'Tu as cartographié $days jours sur 7.';
  }

  @override
  String statsVerdictSubSlow(int days) {
    return 'Seulement $days jour cette semaine. Une petite marche aide.';
  }

  @override
  String get statsVerdictSubNone =>
      'Ouvre la carte et appuie sur Commencer pour contribuer.';

  @override
  String get statsWeeklyTargetLabel => 'CETTE SEMAINE';

  @override
  String get statsWeeklyTargetComplete => 'Objectif atteint';

  @override
  String statsWeeklyTargetRemaining(int count) {
    return '$count de plus';
  }

  @override
  String get statsDetailTitle => 'Tes données';

  @override
  String statsCityBlocks(int count) {
    return '~$count pâtés de maisons couverts';
  }

  @override
  String get statsPersonalRecords => 'Records personnels';

  @override
  String get statsRecordBestDay => 'Meilleur jour';

  @override
  String get statsRecordLongestStreak => 'Série la plus longue';

  @override
  String get statsRecordTotalUploads => 'Total de scans';

  @override
  String get statsRecordFirstDay => 'Premier jour de cartographie';

  @override
  String get statsZoneExplainer => 'Un pâté de maisons scanné en passant.';

  @override
  String get statsUploadExplainer =>
      'Luminosité, mouvement et pression capturés à cet instant.';

  @override
  String get statsTabCore => 'Aperçu';

  @override
  String get statsTabInDepth => 'Détails';

  @override
  String get statsInDepth30Days => '30 derniers jours';

  @override
  String get statsHeatmapLess => 'moins';

  @override
  String get statsHeatmapMore => 'plus';

  @override
  String statsHeatmapDayDetail(String date, int count) {
    return '$date · $count passages';
  }

  @override
  String statsHeatmapNoUploads(String date) {
    return '$date · aucun envoi';
  }

  @override
  String get statsInDepthHabits => 'Vos habitudes';

  @override
  String get statsInDepthActiveDays => 'Jours actifs';

  @override
  String get statsInDepthAvgPerDay => 'Moy. / jour actif';

  @override
  String get statsInDepthBestWeekday => 'Meilleur jour';

  @override
  String get statsDaysUnit => 'jours';

  @override
  String get statsCurrentStreakLabel => 'Série actuelle';

  @override
  String get statsLongestLabel => 'Record';

  @override
  String get statsAllTimeSection => 'TOTAL';

  @override
  String get statsUploadsUnit => 'scans';

  @override
  String get statsBestWeekLabel => 'Meilleure semaine';

  @override
  String get statsQualitySection => 'QUALITÉ DU SIGNAL';

  @override
  String get statsQualityExcellent => 'Excellent';

  @override
  String get statsQualityGood => 'Bon';

  @override
  String get statsQualityFair => 'Correct';

  @override
  String get statsQualityLow => 'Faible';

  @override
  String get statsQualitySubtitle =>
      'La clarté de tes mesures — signal fort, moins d\'erreurs';

  @override
  String get statsAvgPrefix => 'moy.';

  @override
  String get infoKmTitle => 'Territoire cartographié';

  @override
  String get infoKmBody =>
      'Chaque endroit fait environ la taille d\'un pâté de maisons. C\'est la part de ton quartier scannée.';

  @override
  String get infoDataPtsTitle => 'Endroits cartographiés';

  @override
  String get infoDataPtsBody =>
      'Chaque passage enregistre ce que cet endroit est vraiment. Plus de passages, plus de précision.';

  @override
  String get infoTodayTitle => 'Aujourd\'hui';

  @override
  String get infoTodayBody =>
      'Lumière, météo et activité captées aujourd\'hui à chaque arrêt.';

  @override
  String get infoThisWeekTitle => 'Cette semaine';

  @override
  String get infoThisWeekBody => 'Enregistrements des 7 derniers jours.';

  @override
  String get infoDaysActiveTitle => 'Jours actifs';

  @override
  String get infoDaysActiveBody =>
      'Jours où vous avez contribué. Pas besoin d\'être actif tous les jours.';

  @override
  String get infoBestDayTitle => 'Meilleur jour';

  @override
  String get infoBestDayBody =>
      'Votre jour le plus actif cette semaine. Souvent plus de temps en extérieur.';

  @override
  String get infoMilestoneTitle => 'Prochain palier';

  @override
  String get infoMilestoneBody =>
      'Chaque nouvel endroit cartographié compte pour le prochain palier.';

  @override
  String get infoTileQualityTitle => 'Qualité de couverture';

  @override
  String get infoTileQualityBody =>
      'Vert = bien couvert, jaune = partiel, rouge = plus de passages nécessaires.';

  @override
  String get infoTilePersonalTitle => 'Votre endroit';

  @override
  String get infoTilePersonalBody => 'Votre téléphone a enregistré ici.';

  @override
  String get infoTileCommunityTitle => 'Endroit communautaire';

  @override
  String get infoTileCommunityBody =>
      'Cartographié par d\'autres. Passez ici pour vous l\'approprier.';

  @override
  String get statsTotalContributions => 'Fois où tu as cartographié';

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
  String get statsStartContributing => 'Rien de cartographié pour l\'instant.';

  @override
  String get statsEmptyDescription =>
      'Marche n\'importe où. Ton téléphone lit la lumière, le mouvement et la pression autour de toi.';

  @override
  String get statsEmptyGoMap => 'Commencer à cartographier';

  @override
  String get statsEmptyUnlockHint => 'Marche pour débloquer';

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
  String get impactCardContext => 'endroits cartographiés';

  @override
  String get loadingStatsLabel => 'Chargement des statistiques';

  @override
  String get noContributionsYet =>
      'Rien d\'enregistré. Appuyez sur ▶ pour démarrer.';

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
  String get chipZones => 'endroits';

  @override
  String get chipSensors => 'signaux';

  @override
  String homeZonesMapped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits sur ta carte',
      one: '1 endroit sur ta carte',
    );
    return '$_temp0';
  }

  @override
  String get tileInfoSamplesLabel => 'relevés';

  @override
  String get tileInfoDevicesLabel => 'personnes';

  @override
  String get tileInfoQualityLabel => 'Couverture';

  @override
  String get tileInfoAreaLabel => 'surface';

  @override
  String get tileInfoPersonal => 'Le tien';

  @override
  String get tileInfoCommunity => 'Pas encore le tien';

  @override
  String get tileOnlyYouMapped => 'Seul(e) toi es passé(e) ici';

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
      other: '$count relevés',
      one: '1 relevé',
    );
    return '$_temp0';
  }

  @override
  String get tileInfoNoSensorData =>
      'Localisation uniquement. Pas de mesures pour cet endroit.';

  @override
  String get tileInfoConfidence => 'Confiance';

  @override
  String get tileInfoQuality => 'Qualité de couverture';

  @override
  String tileInfoDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes',
      one: '1 personne',
    );
    return '$_temp0';
  }

  @override
  String get tileScanningNow => 'En cours de scan';

  @override
  String get noCoverageYet => 'Aucune couverture';

  @override
  String get startTrackingToMap =>
      'Commencez le suivi pour cartographier votre secteur';

  @override
  String tilesCount(int count) {
    return '$count tuiles';
  }

  @override
  String get sensorLiveReadings => 'Ce qui t\'entoure';

  @override
  String get sensorLiveSubtitle =>
      'Lumière, mouvement et pression — en direct depuis ton téléphone.';

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
  String get sensorPressure => 'Pression';

  @override
  String get sensorUnitLux => 'lx';

  @override
  String get sensorUnitHpa => 'hPa';

  @override
  String get sensorUnitMovement => 'm/s²';

  @override
  String get sensorUnitVibration => '%';

  @override
  String get sensorMovement => 'Mouvement';

  @override
  String get sensorAcceleration => 'Accélération';

  @override
  String get sensorLight => 'Lumière';

  @override
  String get sensorMagneticField => 'Interférences';

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
  String get sensorStatusLastReading => 'Dernière lecture';

  @override
  String get sensorStatusNoData => 'Aucune donnée';

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
  String get lightDarkHint => 'Quasi-obscurité — nuit ou ombre profonde';

  @override
  String get lightDimHint => 'Faible luminosité — loin des fenêtres';

  @override
  String get lightNormalHint =>
      'Lumière confortable — éclairage intérieur typique';

  @override
  String get lightBrightHint =>
      'Bien éclairé — près d\'une fenêtre ou en extérieur';

  @override
  String get lightVeryBrightHint => 'Soleil direct — exposition UV maximale';

  @override
  String get magnetVeryLow => 'Très faible';

  @override
  String get magnetNormal => 'Normal';

  @override
  String get magnetElevated => 'Élevé';

  @override
  String get magnetHighNearMetal => 'Élevé. Près d\'un métal.';

  @override
  String get magnetVeryLowHint => 'Interférences électromagnétiques minimales';

  @override
  String get magnetNormalHint => 'Champ électromagnétique ambiant normal';

  @override
  String get magnetElevatedHint =>
      'Possible infrastructure métallique à proximité';

  @override
  String get magnetHighHint =>
      'Près d\'équipements électriques ou de machinerie lourde';

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
  String get trackingFabStarting => 'Démarrage...';

  @override
  String get trackingFabRecording => 'Cartographie en arrière-plan';

  @override
  String get trackingFabResume => 'Appuyer pour reprendre';

  @override
  String get trackingFabStart => 'Appuyer pour démarrer';

  @override
  String get trackingFabStopInSettings =>
      'Cartographie active. Désactivez-la dans les réglages.';

  @override
  String get trackingErrorUpdateFailed =>
      'Impossible de mettre à jour le suivi. Veuillez réessayer.';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsThemeAuto => 'Auto';

  @override
  String get settingsTracking => 'Cartographie';

  @override
  String get settingsTrackingDesc =>
      'Désactivez pour arrêter toute cartographie en arrière-plan';

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
  String get settingsDataTransparency => 'Transparence des données';

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
      'Chaque voisin complète ce que tu n\'as pas encore atteint.';

  @override
  String get layerMine => 'Miennes';

  @override
  String get layerAll => 'Tout';

  @override
  String get referralLinkCopied => 'Lien copié';

  @override
  String get referralCopyLink => 'Copier le lien';

  @override
  String get referralShareLink => 'Partager';

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
  String get statsReadyToContribute =>
      'Commencez à marcher pour construire votre carte.';

  @override
  String get statsFirstContributionHint =>
      'Commencez le suivi pour cartographier votre premier endroit';

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
      'Cartographiez suffisamment d\'endroits pour atteindre ce niveau et débloquer le suivant';

  @override
  String get statsMilestoneElite => 'Tout cartographié · statut explorateur';

  @override
  String statsMilestoneRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits restants',
      one: '1 endroit restant',
    );
    return '$_temp0';
  }

  @override
  String milestoneNudge(int remaining, int target) {
    return '$remaining pour $target';
  }

  @override
  String statsCommunityAreas(int count) {
    return '$count endroits cartographiés par des gens près de toi';
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
  String get tileQualityExcellent => 'Bien couvert';

  @override
  String get tileQualityGood => 'Bonne couverture';

  @override
  String get tileQualityFair => 'Repasse ici';

  @override
  String get tileQualityStaling => 'Données vieillissantes';

  @override
  String tileDecayWarning(int days) {
    return 'Données vieilles de $days jours — repasse ici pour les rafraîchir.';
  }

  @override
  String tileDecayHint(int days) {
    return 'Cartographié il y a $days jours — le score va bientôt baisser.';
  }

  @override
  String get tileMeasuredWith => 'Enregistré avec';

  @override
  String get legendHighLabel => 'Qualité élevée';

  @override
  String get legendHighSub => 'Beaucoup de bonnes données ici';

  @override
  String get legendMidLabel => 'Qualité moyenne';

  @override
  String get legendMidSub => 'Quelques données. Repasse ici pour améliorer.';

  @override
  String get legendLowLabel => 'Qualité faible';

  @override
  String get legendLowSub => 'Presque rien. Il faut y repasser.';

  @override
  String get legendCommunitySub => 'Enregistré par d\'autres personnes';

  @override
  String get permissionPrimingTitle => 'Une chose avant de commencer';

  @override
  String get permissionPrimingBattery => 'Batterie intelligente';

  @override
  String get permissionPrimingBatteryDesc =>
      'Moins d\'1 % par heure. S\'adapte automatiquement en arrière-plan.';

  @override
  String get permissionPrimingCollects => 'Conçu pour la vie privée';

  @override
  String get permissionPrimingCollectsDesc =>
      'Luminosité, activité et météo uniquement. Jamais votre trajet ni votre identité.';

  @override
  String get permissionPrimingCta => 'Activer la localisation';

  @override
  String get settingsBatteryMode => 'Batterie intelligente';

  @override
  String get settingsBatteryModeDesc =>
      'Discret à l\'arrêt, précis en mouvement. S\'adapte automatiquement.';

  @override
  String get firstStartTitle => 'Votre carte se construit.';

  @override
  String get firstStartBody => 'De nouveaux endroits apparaissent en marchant.';

  @override
  String get alwaysOnBannerBody =>
      'Définissez la localisation sur \'Toujours\' pour continuer à cartographier en arrière-plan';

  @override
  String get alwaysOnBannerFix => 'Corriger';

  @override
  String milestoneReachedTitle(int count) {
    return '$count endroits cartographiés';
  }

  @override
  String get milestoneReachedBody => 'Continuez.';

  @override
  String get milestoneReachedCta => 'Continuer';

  @override
  String get firstUploadTitle => 'Premier endroit cartographié.';

  @override
  String get firstUploadBody => 'Continuez à bouger. Votre carte grandit.';

  @override
  String get firstUploadCta => 'Voir ma carte';

  @override
  String onboardingSocialProof(int count) {
    return '$count personnes cartographient déjà leur quartier';
  }

  @override
  String sessionSummaryZonesClaimed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'endroits cartographiés',
      one: 'endroit cartographié',
    );
    return '$_temp0';
  }

  @override
  String sessionSummaryTotal(int zones, String km2) {
    return 'Total : $zones endroits · $km2 km²';
  }

  @override
  String get sessionSummaryCta => 'Voir ma carte';

  @override
  String get sessionSummaryDone => 'Top';

  @override
  String get statsMapGrowing => 'carte en cours. continuez à marcher';

  @override
  String get statsWeeklyChartOffline =>
      'Graphique hebdomadaire disponible une fois connecté';

  @override
  String uploadMilestone(int count) {
    return '$count envois. Continuez !';
  }

  @override
  String get statsViewOnMap => 'Voir sur la carte';

  @override
  String statsCommunityMappers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes cartographient ce mois',
      one: '1 personne cartographie ce mois',
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
  String get statsStreakAtRisk =>
      'Cartographie aujourd\'hui ou ta série repart à zéro';

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
  String get statsStreakNewRecord => 'Nouveau record';

  @override
  String statsStreakPersonalBest(int count) {
    return 'Record : $count jours';
  }

  @override
  String get statsChartWeekTab => 'Semaine';

  @override
  String get statsChartMonthTab => 'Mois';

  @override
  String get statsChartMonthEmpty =>
      'Marche plus de jours pour débloquer la vue mensuelle';

  @override
  String statsBarCalloutDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scans',
      one: '1 scan',
    );
    return '~$_temp0 · luminosité · activité · météo';
  }

  @override
  String get statsTerritoryDetails => 'Voir les détails du territoire';

  @override
  String get statsTerritorySheetTitle => 'Ton territoire';

  @override
  String statsTerritoryZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits',
      one: '1 endroit',
    );
    return '$_temp0';
  }

  @override
  String get statsTerritoryWhatRecorded => 'Ce que ton téléphone a mesuré ici';

  @override
  String get statsTerritoryLightLabel => 'Lumière';

  @override
  String get statsTerritoryLightDesc =>
      'À quel point cet endroit est lumineux ou sombre : intérieur, extérieur, à l\'ombre';

  @override
  String get statsTerritoryMotionLabel => 'Activité';

  @override
  String get statsTerritoryMotionDesc =>
      'L\'animation habituelle de cet endroit : personnes, trafic, mouvement';

  @override
  String get statsTerritoryPressureLabel => 'Météo';

  @override
  String get statsTerritoryPressureDesc =>
      'La pression atmosphérique enregistrée ici. Reflète les conditions météo locales.';

  @override
  String get statsTerritoryMapCta =>
      'Touche un endroit sur la carte pour voir ses mesures';

  @override
  String get tileCommunityClaimCta => 'Passe par ici pour te l\'approprier';

  @override
  String get tileLowQualityHint =>
      'Repasse par ici. Plus tu y vas, plus les données s\'améliorent.';

  @override
  String homeZonesOnYourMap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits sur ta carte',
      one: '1 endroit sur ta carte',
    );
    return '$_temp0';
  }

  @override
  String homeCommunityScopeHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits cartographiés dans votre secteur',
      one: '1 endroit cartographié dans votre secteur',
    );
    return '$_temp0';
  }

  @override
  String get tileCivicNote => 'Mesuré par toi.';

  @override
  String get tileShareButton => 'Partager ce lieu';

  @override
  String tileShareText(String condition) {
    return 'J\'ai mesuré cet endroit : $condition. Viens voir sur la carte.';
  }

  @override
  String sessionSummaryShareText(int gained, int total, String km2) {
    return 'J\'ai cartographié +$gained nouveaux endroits aujourd\'hui. $total au total · $km2 km²';
  }

  @override
  String sessionSummaryShareTextEmpty(String duration, int total, String km2) {
    return 'Cartographié pendant $duration. $total endroits sur ma carte · $km2 km²';
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
    return '$val';
  }

  @override
  String get sensorLuxDark => 'Sombre';

  @override
  String get sensorLuxIndoor => 'Tamisé';

  @override
  String get sensorLuxBright => 'Lumineux';

  @override
  String get sensorLuxDirect => 'Plein soleil';

  @override
  String get sensorMovementLow => 'Calme';

  @override
  String get sensorMovementMid => 'Actif';

  @override
  String get sensorMovementHigh => 'Animé';

  @override
  String get sensorMovementIntense => 'Très fréquenté';

  @override
  String get sensorMovementLowHint =>
      'Zone calme — peu de passages ou vibrations';

  @override
  String get sensorMovementMidHint => 'Activité légère — zone piétonne';

  @override
  String get sensorMovementHighHint =>
      'Environnement animé — transports ou foule';

  @override
  String get sensorMovementIntenseHint =>
      'Fortes vibrations — trafic dense ou machinerie';

  @override
  String get sensorHpaLow => 'Air dégagé';

  @override
  String get sensorHpaMid => 'Stable';

  @override
  String get sensorHpaHigh => 'Air lourd';

  @override
  String get sensorHpaLowHint =>
      'Haute pression — temps stable et sec probable';

  @override
  String get sensorHpaMidHint =>
      'Pression atmosphérique normale à cette altitude';

  @override
  String get sensorHpaHighHint => 'Basse pression — temps instable possible';

  @override
  String get sensorAccelStill => 'À peine en mouvement';

  @override
  String get sensorAccelWalk => 'Marche';

  @override
  String get sensorAccelActive => 'Course / vélo';

  @override
  String get sensorAccelHeavy => 'Mouvement intense';

  @override
  String get sensorGyroStill => 'Tenu immobile';

  @override
  String get sensorGyroSlow => 'Légère rotation';

  @override
  String get sensorGyroFast => 'Rotation rapide';

  @override
  String get tileSensorInsightsLabel => 'Ce qu\'on y trouve';

  @override
  String get tileVibrationCalm => 'Très calme';

  @override
  String get tileVibrationLight => 'Activité légère';

  @override
  String get tileVibrationActive => 'Surface animée';

  @override
  String get tileVibrationHeavy => 'Trafic intense';

  @override
  String tileConditionSummary(String light, String movement, String pressure) {
    return 'Généralement $light, $movement, sous $pressure.';
  }

  @override
  String tileConditionSummaryNoHpa(String light, String movement) {
    return 'Généralement $light et $movement.';
  }

  @override
  String territoryHeroLabel(String neighborhood, int count) {
    return '$neighborhood · $count endroits';
  }

  @override
  String get serverWakingUp => 'Démarrage en cours. Encore un instant...';

  @override
  String get ambientHereLabel => 'Ici';

  @override
  String get ambientNearbyLabel => 'À proximité';

  @override
  String get ambientUnmappedLabel => 'Passe par ici pour révéler les données';

  @override
  String get permissionLostTitle => 'Accès à la localisation désactivé';

  @override
  String get permissionLostBody =>
      'Votre carte ne se met plus à jour. Appuyez pour corriger.';

  @override
  String get permissionLostCta => 'Corriger dans les réglages';

  @override
  String referralNeighborhoodHook(String neighborhood) {
    return 'Aidez à cartographier $neighborhood. Chaque voisin couvre ce que vous n\'avez pas encore atteint.';
  }

  @override
  String get onboardingActivateTitle => 'Presque là';

  @override
  String get onboardingActivateSubtitle =>
      'Autorisez la localisation. Votre téléphone cartographie pendant vos déplacements.';

  @override
  String get onboardingActivateCta => 'Commencer à cartographier';

  @override
  String get onboardingPermissionDenied =>
      'L\'accès à la localisation est nécessaire pour cartographier votre ville.';

  @override
  String get onboardingPermissionDeniedForeverTitle => 'Permission requise';

  @override
  String get onboardingPermissionDeniedForeverBody =>
      'L\'accès à la localisation a été refusé définitivement. Ouvrez les Réglages et activez-le sous Autorisations → Localisation.';

  @override
  String get onboardingOpenSettings => 'Ouvrir les réglages';

  @override
  String homeMaxClusterHint(int count) {
    return 'plus grande zone : $count endroits';
  }

  @override
  String get firstUploadBadge => 'PREMIER ENDROIT CARTOGRAPHIÉ';

  @override
  String get firstUploadHeadline => 'Ton premier endroit est sur la carte.';

  @override
  String get firstUploadSubtext =>
      'Continue à marcher. Chaque endroit par où tu passes s\'ajoute automatiquement.';

  @override
  String get firstUploadSensorsLabel => 'CAPTEURS';

  @override
  String get firstUploadSensorsValue => 'luminosité · activité · météo';

  @override
  String get firstUploadPrivacyLabel => 'CONFIDENTIALITÉ';

  @override
  String get firstUploadPrivacyValue => 'anonyme · trajet non enregistré';

  @override
  String get firstUploadKeepMappingCta => 'Continuer à cartographier';

  @override
  String get liveSensorsHeader => 'CAPTEURS EN DIRECT';

  @override
  String get liveSensorMotionLabel => 'Mouvement';

  @override
  String get liveSensorPressureLabel => 'Pression';

  @override
  String get sessionSummaryBadge => 'TERMINÉ';

  @override
  String get sessionSummaryZonesGainedLabel => 'NOUVEAUX ENDROITS';

  @override
  String get sessionSummarySubline => 'ajoutés';

  @override
  String get sessionSummaryNoZonesLabel => 'TA CARTE';

  @override
  String get sessionSummaryNoZonesSubline =>
      'Essaie un autre itinéraire la prochaine fois.';

  @override
  String get sessionSummaryWatermark => 'Cartographié avec GreenGains';

  @override
  String get sessionSummaryShareCta => 'Partager';

  @override
  String sessionMilestoneHit(int milestone) {
    return '$milestone endroits.';
  }

  @override
  String get sessionSummaryNextHook => 'Reviens demain.';

  @override
  String get sessionSummaryNextHookEmpty =>
      'De nouveaux endroits apparaissent en marchant.';

  @override
  String get sessionStatArea => 'SURFACE';

  @override
  String get sessionStatDuration => 'TEMPS';

  @override
  String get sessionStatTotal => 'TOTAL';

  @override
  String get sessionStatUploads => 'SYNCS';

  @override
  String get sessionStatAreaExplain =>
      'Surface totale cartographiée cette session, selon les zones couvertes.';

  @override
  String get sessionStatDurationExplain =>
      'Durée pendant laquelle le suivi était actif lors de cette session.';

  @override
  String get sessionStatUploadsExplain =>
      'Nombre d\'envois de données pendant cette session.';

  @override
  String get sessionStatTotalExplain =>
      'Total des zones uniques cartographiées sur toutes tes sessions.';

  @override
  String homeSessionPill(int uploads) {
    return '$uploads synchros';
  }

  @override
  String homeSessionPillWithZones(int uploads, int zones) {
    return '$uploads synchros · +$zones zones';
  }

  @override
  String get statsUploadsHint => 'envois';

  @override
  String get statsKpiTodayExplain => 'Syncs envoyés aujourd\'hui.';

  @override
  String get statsKpiWeekExplain => 'Syncs envoyés cette semaine.';

  @override
  String get statsKpiBestDayExplain => 'Maximum de syncs en une journée.';

  @override
  String get statsKpiAvgExplain => 'Moyenne de syncs les jours actifs.';

  @override
  String get profileTileUploadsExplain =>
      'Total des syncs envoyés à nos serveurs.';

  @override
  String get profileTileDaysExplain => 'Jours avec au moins une contribution.';

  @override
  String profileTileAreaExplain(String area) {
    return 'Surface cartographiée sur toutes tes sessions.';
  }

  @override
  String get profileTileAreaCells => 'zones explorées';

  @override
  String get profileStatCityBlocks => 'îlots de ville';

  @override
  String get profileStreakExplain => 'Jours consécutifs avec au moins un sync.';

  @override
  String profileStreakToMilestone(int days, String unit, int milestone) {
    return '$days $unit avant le cap des $milestone $unit';
  }

  @override
  String get profileUploadsExplanation =>
      'Chaque envoi regroupe ~100 lectures de capteurs capturées à un endroit. Vos données enrichissent la carte environnementale partagée.';

  @override
  String get profileDaysExplanation =>
      'Jours où votre téléphone a contribué au moins un envoi de données. Plus vous êtes actif, plus votre couverture est récente et riche.';

  @override
  String get profileZonesExplanation =>
      'Chaque zone fait environ la taille d\'un pâté de maisons. Consultez la carte pour voir les endroits couverts.';

  @override
  String get profileSeeInStats => 'Voir dans les stats';

  @override
  String get profileViewOnMap => 'Voir sur la carte';

  @override
  String statsMilestoneTarget(int target) {
    return '$target endroits';
  }

  @override
  String get statsActivitySection => 'ACTIVITÉ';

  @override
  String get statsTerritorySection => 'TERRITOIRE';

  @override
  String get mapTapHint => 'Touchez un endroit pour explorer';

  @override
  String get sessionPersonalBest => 'Record personnel';

  @override
  String returnDeltaTitle(int zones) {
    return '$zones nouveaux endroits pendant ton absence.';
  }

  @override
  String get returnDeltaDismiss => 'OK';

  @override
  String get settingsAccount => 'Compte';

  @override
  String get settingsSignOut => 'Se déconnecter';

  @override
  String get settingsSignOutConfirmTitle => 'Se déconnecter ?';

  @override
  String get settingsSignOutConfirmBody =>
      'Tu devras te reconnecter pour voir ta carte.';

  @override
  String get settingsSignOutConfirm => 'Se déconnecter';

  @override
  String get settingsSignOutCancel => 'Annuler';

  @override
  String get mappingActiveSheetTitle => 'En cours de cartographie';

  @override
  String get mappingActiveSheetBody =>
      'Continuez à bouger pour découvrir de nouveaux endroits. Votre carte grandit automatiquement.';

  @override
  String mappingActiveSheetZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux endroits cette session',
      one: '1 nouvel endroit cette session',
      zero: 'Aucun nouvel endroit',
    );
    return '$_temp0';
  }

  @override
  String get mappingActiveSheetCta => 'Ouvrir la carte';

  @override
  String get mappingActiveSheetStop => 'Arrêter la cartographie';

  @override
  String homeStreakBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours de suite',
      one: '1 jour de suite',
    );
    return '$_temp0';
  }

  @override
  String get streakResetBanner =>
      'Série réinitialisée. Recommence aujourd’hui.';

  @override
  String get sessionSummaryNextHookStreak => 'Série en vie.';

  @override
  String get sessionSummaryNextHookFirst =>
      'Marche demain pour commencer une série.';

  @override
  String get weeklyGoalTitle => 'Semaine complète.';

  @override
  String get weeklyGoalBody => 'À la semaine prochaine.';

  @override
  String get weeklyGoalDismiss => 'Super';

  @override
  String get statsEmptyLockLight => 'Lumière';

  @override
  String get statsEmptyLockMovement => 'Mouvement';

  @override
  String get statsEmptyLockPressure => 'Pression atmosphérique';

  @override
  String get statsKm2Unit => 'km²';

  @override
  String get statsLast30DaysUnit => '/ 30';

  @override
  String get referralWaiting =>
      'Lien envoyé. En attente de ton premier voisin.';

  @override
  String get referralFirstJoined => 'Premier voisin rejoint.';

  @override
  String get referralShareAgain => 'Partager à nouveau';

  @override
  String referralShareText(String code) {
    return 'Rejoins-moi sur GreenGains — on cartographie notre quartier. Utilise mon code d\'invitation $code quand tu t\'inscris.';
  }

  @override
  String get onboardingHaveCode => 'Tu as un code d\'invitation ?';

  @override
  String get onboardingCodeHint => 'Entrer le code (ex. GG-XXXXX)';

  @override
  String get onboardingCodeApplied => 'Code d\'invitation appliqué.';

  @override
  String get profileUnlockTitle => 'Ta carte est en train d\'être sauvegardée.';

  @override
  String get profileUnlockBody =>
      'Connecte-toi pour la conserver et la synchroniser sur tous tes appareils.';

  @override
  String get profileUnlockCta => 'Me connecter pour garder ma carte';

  @override
  String get mapZeroStateTitle => 'Tourne en arrière-plan';

  @override
  String get mapZeroStateBody =>
      'Active le suivi une fois et vis ta journée. Ton trajet et ses données environnementales apparaissent à ton retour.';

  @override
  String get snapshotCardTitle => 'TON QUARTIER';

  @override
  String snapshotReadings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesures',
      one: '1 mesure',
    );
    return '$_temp0';
  }

  @override
  String snapshotAcrossZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones',
      one: '1 zone',
    );
    return 'sur $_temp0';
  }

  @override
  String get snapshotLightDark => 'Sombre';

  @override
  String get snapshotLightDim => 'Peu éclairé';

  @override
  String get snapshotLightNormal => 'Bien éclairé';

  @override
  String get snapshotLightBright => 'Lumineux';

  @override
  String get snapshotLightVeryBright => 'Très lumineux';

  @override
  String get snapshotMovementCalm => 'Calme';

  @override
  String get snapshotMovementActive => 'Actif';

  @override
  String get snapshotMovementBusy => 'Animé';

  @override
  String get snapshotPressureLow => 'Basse pression';

  @override
  String get snapshotPressureStable => 'Stable';

  @override
  String get snapshotPressureHigh => 'Haute pression';

  @override
  String get insightNoData => 'Pas encore assez de données pour cette zone.';

  @override
  String get insightLightPristine =>
      'Presque aucune lumière artificielle. L\'obscurité naturelle est préservée ici.';

  @override
  String get insightLightLow =>
      'Faible pollution lumineuse. Les étoiles restent visibles par temps clair.';

  @override
  String get insightLightModerate =>
      'Pollution lumineuse modérée. Le halo lumineux est perceptible.';

  @override
  String get insightLightHigh =>
      'Forte pollution lumineuse. La plupart des étoiles sont masquées ici.';

  @override
  String get insightLightSevere =>
      'Pollution lumineuse sévère. Le ciel nocturne est presque invisible.';

  @override
  String get insightSunShaded =>
      'Zone très ombragée. Peu de soleil direct ici.';

  @override
  String get insightSunPartial =>
      'Partiellement ombragé. Lumière filtrée, plus frais que les rues ouvertes.';

  @override
  String get insightSunBright =>
      'Bonne luminosité naturelle. Zone ouverte et bien éclairée en journée.';

  @override
  String get insightSunIntense =>
      'Fort ensoleillement direct. Risque de chaleur en été.';

  @override
  String get insightSurfaceSmooth =>
      'Surface très lisse. Bonnes conditions de marche.';

  @override
  String get insightSurfaceNormal => 'Qualité de surface normale.';

  @override
  String get insightSurfaceRough =>
      'Surface irrégulière. Revêtement inégal détecté.';

  @override
  String get insightSurfacePoor =>
      'Mauvaise qualité de surface. Dégradations importantes.';

  @override
  String get insightHeatExposed =>
      'Exposé au soleil et à la pression. Plus chaud que les zones voisines.';

  @override
  String get insightSessionDarkSky =>
      'Votre trajet avait très peu de pollution lumineuse ce soir.';

  @override
  String get insightSessionBrightCity =>
      'Éclairage urbain intense tout au long de votre trajet ce soir.';

  @override
  String get insightSessionRoughRoute =>
      'Surface plus accidentée que la plupart de vos trajets.';

  @override
  String get insightSessionHotRoute =>
      'Fort ensoleillement sur ce trajet. Pensez à vous hydrater.';
}
