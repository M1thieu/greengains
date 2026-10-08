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
      'Le téléphone mesure la lumière, la pression et le mouvement des rues traversées.';

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
  String get onboardingFeature3Title => 'Voyez votre environnement.';

  @override
  String get onboardingFeature3Description =>
      'Lumière, pression et mouvement, mesurés partout où vous passez.';

  @override
  String get onboardingSignInTitle => 'Vos mesures commencent ici.';

  @override
  String get onboardingSignInSubtitle =>
      'Connectez-vous pour retrouver vos mesures sur tous vos appareils.';

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
  String homeStatArea(String area) {
    return '$area de couverture';
  }

  @override
  String homeStatToday(int count) {
    return '+$count aujourd\'hui';
  }

  @override
  String get homeActionStart => 'Démarrer';

  @override
  String get homeActionStop => 'Arrêter';

  @override
  String get homeActionResume => 'Reprendre';

  @override
  String get trackingPaused => 'Suivi en pause';

  @override
  String lastUpload(String time) {
    return 'Dernier envoi : $time';
  }

  @override
  String get totalUploads => 'Total d\'envois';

  @override
  String profileMemberSince(String date) {
    return 'Membre depuis le $date';
  }

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsLanguageSystem => 'Système';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsMobileData => 'Envoi sur données mobiles';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get permissionLocationMessage =>
      'Autorisez la localisation pour que votre téléphone cartographie pendant vos déplacements.';

  @override
  String get errorGeneric => 'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get buttonClose => 'Fermer';

  @override
  String get loading => 'Chargement...';

  @override
  String get success => 'Succès';

  @override
  String get error => 'Erreur';

  @override
  String get profileUserFallback => 'Utilisateur';

  @override
  String get chipPaused => 'En pause';

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
  String get uploadSuccessMessage => 'Carte mise à jour !';

  @override
  String uploadSuccessNewZone(int count) {
    return 'Nouvel endroit mesuré · $count au total';
  }

  @override
  String get semanticsCenterOnMe => 'Centrer la carte sur ma position';

  @override
  String get statsToday => 'Aujourd\'hui';

  @override
  String get statsThisWeek => 'Cette semaine';

  @override
  String get statsDaysActive => 'Jours actifs';

  @override
  String get statsAreasLabel => 'endroits couverts';

  @override
  String get statsDataPtsLabel => 'données collectées';

  @override
  String get statsKmMapped => 'Surface couverte';

  @override
  String get statsBestDayLabel => 'Meilleur jour';

  @override
  String get statsAvgPerDay => 'Moy. / jour';

  @override
  String get statsWeeklyTargetComplete => 'Objectif atteint';

  @override
  String get statsImpactLabel => 'VOTRE IMPACT';

  @override
  String statsImpactSolo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits que personne d\'autre n\'a mesurés',
      one: '1 endroit que personne d\'autre n\'a mesuré',
    );
    return '$_temp0';
  }

  @override
  String get statsDetailTitle => 'Vos données';

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
  String get statsRecordBestSession => 'Meilleure session';

  @override
  String statsZoneExplainer(String area) {
    return '1 endroit ≈ $area';
  }

  @override
  String get statsTabInDepth => 'Détails';

  @override
  String get statsOpenDetails => 'En détail';

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
  String get statsInDepthWhenYouMap => 'Quand vous cartographiez';

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
      'Précision GPS, stabilité et exposition des capteurs';

  @override
  String get statsAvgPrefix => 'moy.';

  @override
  String get statsActivityTrend => 'Cette semaine';

  @override
  String get statsTodayLabel => 'AUJOURD\'HUI';

  @override
  String get statsStartContributing => 'Pas encore de données.';

  @override
  String get statsEmptyDescription =>
      'Les mesures apparaissent ici après le premier envoi.';

  @override
  String get statsEmptyGoMap => 'Activer le suivi';

  @override
  String get tileInfoQualityLabel => 'Couverture';

  @override
  String get tileInfoPersonal => 'Mesuré par vous';

  @override
  String get tileInfoCommunity => 'Mesuré par la communauté';

  @override
  String get tileOnlyYouMapped => 'Personne d\'autre n\'est passé ici';

  @override
  String get mapLayerTitle => 'Couche de la carte';

  @override
  String get mapLayerQuality => 'Qualité des données';

  @override
  String tileContributors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributeurs',
      one: '1 contributeur',
    );
    return '$_temp0';
  }

  @override
  String tileMeasurements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesures',
      one: '1 mesure',
    );
    return '$_temp0';
  }

  @override
  String get tileInfoNoSensorData =>
      'Localisation uniquement. Pas de mesures pour cet endroit.';

  @override
  String get noCoverageYet => 'Aucune couverture';

  @override
  String get startTrackingToMap =>
      'Démarrez le suivi pour mesurer votre secteur';

  @override
  String tilesCount(int count) {
    return '$count tuiles';
  }

  @override
  String get sensorLiveReadings => 'Autour de vous';

  @override
  String get sensorLiveSubtitle => 'Lumière, mouvement et pression, en direct.';

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
  String get sensorWifi => 'Wi-Fi';

  @override
  String get sensorTemperature => 'Température';

  @override
  String get sensorHumidity => 'Humidité';

  @override
  String get sensorOrientation => 'Orientation';

  @override
  String get sensorAirPressure => 'Pression de l\'air';

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
  String get lightDarkHint => 'Nuit, ou capteur couvert';

  @override
  String get lightDimHint => 'Faible luminosité ambiante';

  @override
  String get lightNormalHint => 'Éclairage intérieur typique';

  @override
  String get lightBrightHint => 'Près d\'une fenêtre ou en extérieur';

  @override
  String get lightVeryBrightHint => 'Plein jour, dehors';

  @override
  String get magnetVeryLow => 'Très faible';

  @override
  String get magnetNormal => 'Normal';

  @override
  String get magnetElevated => 'Élevé';

  @override
  String get magnetHighNearMetal => 'Très élevé';

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
  String get trackingErrorUpdateFailed =>
      'Impossible de mettre à jour le suivi. Veuillez réessayer.';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsThemeAuto => 'Auto';

  @override
  String get settingsMobileDataDescription =>
      'Envoyer via LTE/5G si nécessaire';

  @override
  String get settingsLegal => 'Légal';

  @override
  String get settingsDataTransparency => 'Transparence des données';

  @override
  String get settingsDataDeletion => 'Demande de suppression des données';

  @override
  String get settingsExportData => 'Exporter mes données';

  @override
  String get settingsExportDataPreparing => 'Préparation de l\'export…';

  @override
  String get settingsExportDataFailed =>
      'Export impossible. Réessayez plus tard.';

  @override
  String get referralInviteDescription =>
      'Chaque personne invitée mesure d\'autres endroits.';

  @override
  String get layerMine => 'Moi';

  @override
  String get layerAll => 'Tous';

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
  String statsWeeklyTotal(int count) {
    return '$count cette semaine';
  }

  @override
  String get statsMilestoneLabel => 'Prochain palier';

  @override
  String get statsMilestoneElite => 'Tous les paliers atteints.';

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
  String get batteryDialogOemXiaomiHint =>
      'Sur Xiaomi/Redmi : activez aussi le démarrage auto dans Paramètres → Applications → Gérer les apps → GreenGains → Démarrage auto';

  @override
  String get batteryDialogOemHuaweiHint =>
      'Sur Huawei/Honor : dans Paramètres → Batterie → Lancement des apps, réglez GreenGains en manuel avec tous les interrupteurs activés';

  @override
  String get batteryDialogOemSamsungHint =>
      'Sur Samsung : réglez GreenGains sur Sans restriction dans Paramètres → Batterie → Limites d\'utilisation en arrière-plan';

  @override
  String get settingsDiagnostics => 'Diagnostics capteurs';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get sensorLiveSheetTitle => 'Mesures en direct';

  @override
  String get transparencyNothingElse =>
      'Pas de trajet précis. Pas de micro. Pas de contacts. Rien d\'autre.';

  @override
  String get transparencyLastUpload => 'Dernier envoi';

  @override
  String get transparencyNoUploadYet => 'Rien d\'envoyé pour l\'instant.';

  @override
  String get tileQualityExcellent => 'Bien couvert';

  @override
  String get tileQualityGood => 'Bonne couverture';

  @override
  String get tileQualityFair => 'Peu de mesures';

  @override
  String get tileQualityStaling => 'Données vieillissantes';

  @override
  String get permissionPrimingBattery => 'Batterie intelligente';

  @override
  String get permissionPrimingBatteryDesc =>
      'S\'adapte automatiquement en arrière-plan.';

  @override
  String get permissionPrimingCollects => 'Conçu pour la vie privée';

  @override
  String get permissionPrimingCollectsDesc =>
      'Lumière, mouvement et pression uniquement. Jamais votre trajet ni votre identité.';

  @override
  String onboardingSocialProof(int count) {
    return '$count personnes cartographient déjà leur quartier';
  }

  @override
  String statsCommunityLine(int mappers, int zones) {
    return '$mappers cartographes ce mois-ci · $zones endroits couverts';
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
  String get statsWeeklyChartOffline =>
      'Graphique hebdomadaire disponible une fois connecté';

  @override
  String uploadMilestone(int count) {
    return '$count envois. Continuez !';
  }

  @override
  String get statsViewOnMap => 'Voir sur la carte';

  @override
  String statsSinceDate(String date) {
    return 'depuis $date';
  }

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
  String get statsChartWeekTab => 'Semaine';

  @override
  String get statsChartMonthTab => 'Mois';

  @override
  String get statsChartMonthEmpty =>
      'Vue mensuelle disponible après plus de jours actifs';

  @override
  String get statsTerritoryDetails => 'Voir le détail des mesures';

  @override
  String get statsTerritorySheetTitle => 'Vos mesures';

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
  String get statsTerritoryWhatRecorded => 'Capteurs utilisés';

  @override
  String get statsTerritoryLightLabel => 'Lumière';

  @override
  String get statsTerritoryMotionLabel => 'Mouvement';

  @override
  String get statsTerritoryPressureLabel => 'Pression';

  @override
  String get statsTerritoryMapCta =>
      'Touchez un endroit sur la carte pour voir ses mesures';

  @override
  String sessionSummaryShareText(int gained, int total, String km2) {
    return 'J\'ai cartographié +$gained nouveaux endroits aujourd\'hui. $total au total · $km2';
  }

  @override
  String sessionSummaryShareTextEmpty(String duration, int total, String km2) {
    return 'Cartographié pendant $duration. $total endroits mesurés · $km2';
  }

  @override
  String get sensorLuxDark => 'Sombre';

  @override
  String get sensorLuxIndoor => 'Tamisé';

  @override
  String get sensorLuxBright => 'Lumineux';

  @override
  String get sensorLuxDirect => 'Très lumineux';

  @override
  String get sensorMovementLow => 'Faible';

  @override
  String get sensorMovementMid => 'Moyen';

  @override
  String get sensorMovementHigh => 'Fort';

  @override
  String get sensorMovementIntense => 'Très fort';

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
  String get mapperRoleContributor => 'Contributeur';

  @override
  String get mapperRolePioneer => 'Pionnier';

  @override
  String get mapperRoleExplorer => 'Explorateur';

  @override
  String get mapperRoleCartographer => 'Cartographe';

  @override
  String get mapperRoleCityMapper => 'Cartographe urbain';

  @override
  String get mapperRoleUrbanScientist => 'Scientifique urbain';

  @override
  String serverWakingUp(int seconds) {
    return 'Réveil du serveur · $seconds s';
  }

  @override
  String get permissionLostTitle => 'Accès à la localisation désactivé';

  @override
  String get permissionLostBody =>
      'La carte ne se met plus à jour. Appuyez pour corriger.';

  @override
  String get permissionLostCta => 'Corriger dans les réglages';

  @override
  String referralNeighborhoodHook(String neighborhood) {
    return 'Aidez à mesurer $neighborhood.';
  }

  @override
  String get onboardingActivateTitle => 'Presque là';

  @override
  String get onboardingActivateSubtitle =>
      'Votre téléphone mesure l\'environnement autour de vous en déplacement. Votre trajet n\'est jamais enregistré.';

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
  String get sessionSummaryBadge => 'TERMINÉ';

  @override
  String get sessionSummaryZonesGainedLabel => 'NOUVEAUX ENDROITS';

  @override
  String get sessionSummarySubline => 'ajoutés';

  @override
  String get sessionSummaryNoZonesLabel => 'VOS MESURES';

  @override
  String get sessionSummaryWatermark => 'Cartographié avec GreenGains';

  @override
  String get sessionSummaryShareCta => 'Partager';

  @override
  String sessionMilestoneHit(int milestone) {
    return '$milestone endroits.';
  }

  @override
  String get sessionStatArea => 'SURFACE';

  @override
  String get sessionStatDuration => 'TEMPS';

  @override
  String get sessionStatTotal => 'TOTAL';

  @override
  String get sessionStatUploads => 'SYNCS';

  @override
  String profileStreakToMilestone(int days, String unit, int milestone) {
    return '$days $unit avant le cap des $milestone $unit';
  }

  @override
  String statsMilestoneTarget(int target) {
    return '$target endroits';
  }

  @override
  String get statsActivitySection => 'VOTRE SEMAINE';

  @override
  String statsVsPrevWeek(String delta) {
    return '$delta% vs sem. préc.';
  }

  @override
  String get statsTerritorySection => 'VOTRE CONTRIBUTION';

  @override
  String get mapTapHint => 'Touchez un endroit pour explorer';

  @override
  String get sessionPersonalBest => 'Record personnel';

  @override
  String get settingsSignOut => 'Se déconnecter';

  @override
  String get streakResetBanner => 'Série réinitialisée.';

  @override
  String get statsKm2Unit => 'km²';

  @override
  String get statsHaUnit => 'ha';

  @override
  String get statsLast30DaysUnit => '/ 30';

  @override
  String get referralWaiting => 'Lien partagé. Personne n\'a encore rejoint.';

  @override
  String get referralFirstJoined => 'Première personne rejointe.';

  @override
  String get referralShareAgain => 'Partager à nouveau';

  @override
  String referralShareText(String code) {
    return 'Rejoins-moi sur GreenGains : on mesure la lumière, la pression et le mouvement de nos rues. Code d\'invitation : $code';
  }

  @override
  String get onboardingHaveCode => 'Un code d\'invitation ?';

  @override
  String get onboardingCodeHint => 'Entrer le code (ex. GG-XXXXX)';

  @override
  String get profileUnlockTitle => 'Vos mesures sont en cours de sauvegarde.';

  @override
  String get profileUnlockBody =>
      'Connectez-vous pour les conserver sur tous vos appareils.';

  @override
  String get mapZeroStateTitle => 'Le premier endroit est à quelques pas';

  @override
  String get mapZeroStateBody =>
      'Démarrez le suivi : la rue apparaît sur la carte dès le premier déplacement.';

  @override
  String get statsInsightLabel => 'CETTE SEMAINE';

  @override
  String statsInsightNewZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux endroits cartographiés cette semaine',
      one: '1 nouvel endroit cartographié cette semaine',
    );
    return '$_temp0';
  }

  @override
  String statsInsightSolo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits que personne d\'autre n\'a mesurés',
      one: '1 endroit que personne d\'autre n\'a mesuré',
    );
    return '$_temp0';
  }
}
