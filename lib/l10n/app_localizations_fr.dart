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
  String get onboardingFeature1Title => 'Rien à faire.';

  @override
  String get onboardingFeature2Title => 'Privé par défaut';

  @override
  String get onboardingFeature3Title => 'Vois ton environnement.';

  @override
  String get onboardingSignInTitle => 'Ta carte commence ici.';

  @override
  String onboardingPrivacyNotice(String privacyPolicy, String termsOfService) {
    return 'En continuant, tu acceptes notre $privacyPolicy et nos $termsOfService.';
  }

  @override
  String get signInWithGoogleLabel => 'Continuer avec Google';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get buttonNext => 'Suivant';

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
    return '$area cartographié';
  }

  @override
  String get homeActionStart => 'Démarrer';

  @override
  String get homeActionStop => 'Arrêter';

  @override
  String get homeActionResume => 'Reprendre';

  @override
  String get startTracking => 'Démarrer le suivi';

  @override
  String get stopTracking => 'Arrêter le suivi';

  @override
  String get trackingPaused => 'Suivi en pause';

  @override
  String lastUpload(String time) {
    return 'Dernière mise à jour : $time';
  }

  @override
  String get totalUploads => 'Total de scans';

  @override
  String profileMemberSince(String date) {
    return 'Membre depuis le $date';
  }

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsLanguageSystem => 'Système';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsDisplay => 'Affichage';

  @override
  String get settingsMobileData => 'Utiliser les données mobiles';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get permissionLocationMessage =>
      'Autorise la localisation pour que ton téléphone cartographie pendant tes déplacements.';

  @override
  String get errorGeneric => 'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get buttonCancel => 'Annuler';

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
  String get chipPaused => 'En pause';

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
  String get statsDataPtsLabel => 'mesures';

  @override
  String get statsKmMapped => 'km² couverts';

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
  String get statsWeeklyTargetLabel => 'CETTE SEMAINE';

  @override
  String get statsWeeklyTargetComplete => 'Objectif atteint';

  @override
  String get statsLocalLegendLabel => 'TON QUARTIER';

  @override
  String get statsLocalLegendLeader =>
      'Tu es le plus actif de ton quartier cette semaine';

  @override
  String statsLocalLegendRank(int rank, int total) {
    return '${rank}e sur $total dans ton quartier cette semaine';
  }

  @override
  String statsLocalLegendGap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits pour passer en tête',
      one: '1 endroit pour passer en tête',
    );
    return '$_temp0';
  }

  @override
  String get statsImpactLabel => 'TON IMPACT';

  @override
  String statsImpactSolo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tu es le seul à être passé par $count de tes endroits',
      one: 'Tu es le seul à être passé par 1 de tes endroits',
    );
    return '$_temp0';
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
  String get statsRecordBestSession => 'Meilleure session';

  @override
  String get statsZoneExplainer =>
      'Un endroit, c\'est à peu près un pâté de maisons.';

  @override
  String get statsUploadExplainer =>
      'Lumière, chaleur et sol au moment du scan.';

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
    return '$date · aucun scan';
  }

  @override
  String get statsInDepthHabits => 'Tes habitudes';

  @override
  String get statsInDepthActiveDays => 'Jours actifs';

  @override
  String get statsInDepthAvgPerDay => 'Moy. / jour actif';

  @override
  String get statsInDepthBestWeekday => 'Meilleur jour';

  @override
  String get statsInDepthWhenYouMap => 'Quand tu scannes';

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
  String get statsQualitySection => 'FIABILITÉ';

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
      'Plus c\'est haut, plus tes mesures sont fiables.';

  @override
  String get statsAvgPrefix => 'moy.';

  @override
  String get infoTileQualityTitle => 'Fiabilité';

  @override
  String get infoTilePersonalTitle => 'Ton endroit';

  @override
  String get statsActivityTrend => 'Cette semaine';

  @override
  String get statsTodayLabel => 'AUJOURD\'HUI';

  @override
  String get statsStartContributing => 'Pas encore de données.';

  @override
  String get statsEmptyGoMap => 'Activer le suivi';

  @override
  String get statsLoadErrorTitle => 'Impossible de charger tes stats';

  @override
  String get statsCollectingTitle => 'Collecte en cours';

  @override
  String get tileInfoSamplesLabel => 'relevés';

  @override
  String get tileInfoDevicesLabel => 'personnes';

  @override
  String get tileInfoQualityLabel => 'Fiabilité';

  @override
  String get tileInfoAreaLabel => 'surface';

  @override
  String get tileInfoPersonal => 'Le tien';

  @override
  String get tileInfoCommunity => 'Pas encore le tien';

  @override
  String get tileOnlyYouMapped => 'Seul(e) toi es passé(e) ici';

  @override
  String get tileInfoNoSensorData =>
      'Position seulement, pas encore de mesures ici.';

  @override
  String get noCoverageYet => 'Rien ici pour l\'instant';

  @override
  String get startTrackingToMap => 'Lance le suivi pour remplir ta carte';

  @override
  String tilesCount(int count) {
    return '$count tuiles';
  }

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
  String get sensorStatusConnecting => 'Connexion…';

  @override
  String get sensorStatusLive => 'En direct';

  @override
  String get sensorStatusLastReading => 'Dernière lecture';

  @override
  String get sensorStatusNoData => 'Aucune donnée';

  @override
  String get lightDark => 'Ciel noir';

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
  String get magnetHighNearMetal => 'Élevé. Près d\'un métal.';

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
  String get settingsTracking => 'Cartographie';

  @override
  String get settingsLegal => 'Légal';

  @override
  String get settingsDataTransparency => 'Transparence des données';

  @override
  String get settingsExportData => 'Exporter mes données';

  @override
  String get settingsExportDataFailed =>
      'Impossible d\'exporter tes données. Réessaie plus tard.';

  @override
  String get referralInviteDescription =>
      'Chaque ami qui rejoint ajoute des endroits à la carte.';

  @override
  String get layerMine => 'Miennes';

  @override
  String get layerAll => 'Tout';

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
  String get statsMilestoneElite => 'Tous les paliers atteints.';

  @override
  String statsMilestoneRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore $count endroits',
      one: 'Encore 1 endroit',
    );
    return '$_temp0';
  }

  @override
  String get batteryDialogTitle => 'Laisser tourner en arrière-plan';

  @override
  String get settingsDiagnostics => 'Diagnostics capteurs';

  @override
  String get settingsDiagnosticsDesc =>
      'Lectures en temps réel de tes capteurs';

  @override
  String get sensorLiveSheetTitle => 'Autour de toi';

  @override
  String get transparencyNothingElse =>
      'Pas de trajet précis. Pas de micro. Pas de contacts. Rien d\'autre.';

  @override
  String get transparencyLastUpload => 'Dernière mise à jour';

  @override
  String get transparencyNoUploadYet => 'Rien d\'envoyé pour l\'instant.';

  @override
  String get tileQualityExcellent => 'Bien couvert';

  @override
  String get tileQualityGood => 'Bonne couverture';

  @override
  String get tileQualityFair => 'Repasse ici';

  @override
  String get tileQualityStaling => 'Infos anciennes';

  @override
  String tileDecayWarning(int days) {
    return 'Infos d\'il y a $days jours. Repasse ici pour les mettre à jour.';
  }

  @override
  String tileDecayHint(int days) {
    return 'Mis à jour il y a $days jours.';
  }

  @override
  String get legendHighLabel => 'Très fiable';

  @override
  String get legendHighSub => 'Beaucoup de mesures ici';

  @override
  String get legendMidLabel => 'Assez fiable';

  @override
  String get legendMidSub => 'Quelques mesures. Repasse ici pour en ajouter.';

  @override
  String get legendLowLabel => 'Peu fiable';

  @override
  String get legendLowSub => 'Presque rien. Il faut y repasser.';

  @override
  String get legendCommunitySub => 'Enregistré par d\'autres personnes';

  @override
  String get permissionPrimingBattery => 'Batterie intelligente';

  @override
  String get permissionPrimingCollects => 'Conçu pour la vie privée';

  @override
  String onboardingSocialProof(int count) {
    return '$count personnes remplissent déjà la carte de leur quartier';
  }

  @override
  String get statsWeeklyChartOffline =>
      'Graphique hebdomadaire disponible une fois connecté';

  @override
  String get statsViewOnMap => 'Voir sur la carte';

  @override
  String tileFirstMapped(String date) {
    return 'Premier passage le $date';
  }

  @override
  String statsSinceDate(String date) {
    return 'depuis $date';
  }

  @override
  String get statsStreakNewRecord => 'Nouveau record';

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
    return '~$_temp0 · lumière · mouvement · météo';
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
      'La pression de l\'air ici. Elle suit la météo.';

  @override
  String get statsTerritoryMapCta =>
      'Touche un endroit sur la carte pour voir ses mesures';

  @override
  String get tileCommunityClaimCta => 'Passe par ici pour te l\'approprier';

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
  String get sensorHpaLow => 'Air dégagé';

  @override
  String get sensorHpaMid => 'Stable';

  @override
  String get sensorHpaHigh => 'Air lourd';

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
  String get tileVibrationCalm => 'Très calme';

  @override
  String get tileVibrationLight => 'Activité légère';

  @override
  String get tileVibrationActive => 'Ça bouge beaucoup';

  @override
  String get tileVibrationHeavy => 'Trafic intense';

  @override
  String get tileSurfaceSmooth => 'sol lisse';

  @override
  String get tileSurfaceRough => 'sol irrégulier';

  @override
  String get tileSurfaceHeavy => 'très dégradée';

  @override
  String get tileCondLightDark => 'sombre';

  @override
  String get tileCondLightDim => 'peu éclairé';

  @override
  String get tileCondLightBright => 'éclairé';

  @override
  String get tileCondLightShaded => 'à l\'ombre';

  @override
  String get tileCondLightPartial => 'nuageux';

  @override
  String get tileCondLightIntense => 'très lumineux';

  @override
  String get tileCondActivityCalm => 'calme';

  @override
  String get tileCondActivityModerate => 'modéré';

  @override
  String get tileCondActivityActive => 'animé';

  @override
  String get tileCondActivityBusy => 'très animé';

  @override
  String get sessionCharacterDarkSky => 'CIEL NOIR';

  @override
  String get sessionCharacterBrightCity => 'NUIT ÉCLAIRÉE';

  @override
  String get sessionCharacterHotRoute => 'SORTIE CHAUDE';

  @override
  String get sessionCharacterRoughRoad => 'SOL IRRÉGULIER';

  @override
  String get sessionCharacterSunExposed => 'CIEL OUVERT';

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
  String get serverWakingUp => 'Chargement…';

  @override
  String get permissionLostTitle => 'Accès à la localisation désactivé';

  @override
  String get permissionLostCta => 'Corriger dans les réglages';

  @override
  String referralNeighborhoodHook(String neighborhood) {
    return 'Invite tes voisins à remplir la carte de $neighborhood.';
  }

  @override
  String get onboardingActivateTitle => 'Presque là';

  @override
  String get onboardingActivateSubtitle =>
      'Ton téléphone mesure l\'environnement autour de toi pendant tes déplacements. Ton trajet n\'est jamais enregistré.';

  @override
  String get onboardingActivateCta => 'Commencer';

  @override
  String get onboardingPermissionDenied =>
      'La localisation est nécessaire pour remplir ta carte.';

  @override
  String get profileTileAreaCells => 'endroits';

  @override
  String get profileStatCityBlocks => 'îlots de ville';

  @override
  String profileStreakToMilestone(int days, String unit, int milestone) {
    return '$days $unit avant le cap des $milestone $unit';
  }

  @override
  String get profileUploadsExplanation =>
      'Un scan, c\'est ce que ton téléphone mesure à un endroit.';

  @override
  String get profileDaysExplanation =>
      'Jours où ton téléphone a scanné au moins une fois.';

  @override
  String get profileZonesExplanation =>
      'Un endroit, c\'est à peu près un pâté de maisons. Touche la carte pour les voir.';

  @override
  String get profileSeeInStats => 'Voir dans les stats';

  @override
  String get profileViewOnMap => 'Voir sur la carte';

  @override
  String get statsActivitySection => 'TA SEMAINE';

  @override
  String statsVsPrevWeek(String delta) {
    return '$delta% vs sem. préc.';
  }

  @override
  String get statsTerritorySection => 'TON QUARTIER';

  @override
  String get mapTapHint => 'Touchez un endroit pour explorer';

  @override
  String get settingsSignOut => 'Se déconnecter';

  @override
  String get settingsDeleteAccount => 'Supprimer mon compte';

  @override
  String get settingsDeleteAccountWarning =>
      'Ton compte et toutes tes données seront effacés. C\'est définitif.';

  @override
  String get settingsDeleteAccountConfirm => 'Supprimer';

  @override
  String get streakResetBanner =>
      'Série réinitialisée. Recommence aujourd’hui.';

  @override
  String get statsEmptyLockLight =>
      'Lumière : ciel noir la nuit, soleil le jour';

  @override
  String get statsEmptyLockMovement =>
      'Activité : l\'animation de chaque endroit';

  @override
  String get statsEmptyLockPressure =>
      'Météo : chaleur et pression autour de toi';

  @override
  String get statsKm2Unit => 'km²';

  @override
  String get statsLast30DaysUnit => '/ 30';

  @override
  String get referralWaiting =>
      'Lien partagé. Personne pour l\'instant. Tu es peut-être le premier de ton quartier.';

  @override
  String get referralFirstJoined => 'Première personne rejointe.';

  @override
  String get referralShareAgain => 'Partager à nouveau';

  @override
  String referralShareText(String code) {
    return 'Rejoins-moi sur GreenGains : on cartographie la lumière, la météo et l\'état des rues autour de nous. Mon code : $code';
  }

  @override
  String get onboardingHaveCode => 'Tu as un code d\'invitation ?';

  @override
  String get onboardingCodeHint => 'Entrer le code (ex. GG-XXXXX)';

  @override
  String get profileUnlockTitle => 'Ta carte est en train d\'être sauvegardée.';

  @override
  String get mapZeroStateTitle => 'Ton premier endroit est à une marche';

  @override
  String get insightNoData => 'Pas encore assez de mesures ici.';

  @override
  String get insightNormal => 'Rien d\'inhabituel détecté ici.';

  @override
  String get insightRouteHeader => 'TA SORTIE';

  @override
  String get insightLightPristine => 'Très peu de lumière artificielle ici.';

  @override
  String get insightLightLow =>
      'Naturellement sombre ici. Bon pour décompresser si tu rentres par là.';

  @override
  String get insightLightModerate =>
      'Un peu de halo lumineux. Assez pour affecter ton horloge biologique à la longue.';

  @override
  String get insightLightHigh =>
      'Lumineux la nuit, comme une pièce allumée. Pas idéal avant de dormir.';

  @override
  String get insightLightSevere =>
      'Très lumineux la nuit. Ton corps pense qu\'il fait encore jour ici.';

  @override
  String get insightSunShaded => 'Endroit ombragé et frais.';

  @override
  String get insightSunPartial => 'Conditions extérieures normales.';

  @override
  String get insightSunBright => 'Endroit bien ensoleillé.';

  @override
  String get insightSunIntense =>
      'Fort soleil direct. Pense à t\'hydrater ou chercher de l\'ombre en été.';

  @override
  String get insightSurfaceSmooth => 'Sol lisse.';

  @override
  String get insightSurfaceNormal => 'Sol normal.';

  @override
  String get insightSurfaceRough => 'Sol irrégulier.';

  @override
  String get insightSurfacePoor => 'Sol très irrégulier.';

  @override
  String get insightHeatExposed => 'Plus chaud que les rues autour.';

  @override
  String get insightSessionDarkSky =>
      'Peu de lumière artificielle pendant ta sortie.';

  @override
  String get insightSessionBrightCity =>
      'Très éclairé la nuit pendant ta sortie.';

  @override
  String get insightSessionRoughRoute => 'Sol irrégulier pendant ta sortie.';

  @override
  String get insightSessionHotRoute => 'Il faisait chaud pendant ta sortie.';

  @override
  String get statsInsightLabel => 'CETTE SEMAINE';

  @override
  String statsInsightRoughest(String street, int pct) {
    return 'Rue la plus irrégulière : $street (plus que $pct % de tes sorties)';
  }

  @override
  String statsInsightNewZones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux endroits cette semaine',
      one: '1 nouvel endroit cette semaine',
    );
    return '$_temp0';
  }

  @override
  String statsInsightSolo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits où tu es le seul à être passé',
      one: '1 endroit où tu es le seul à être passé',
    );
    return '$_temp0';
  }

  @override
  String statsInsightBrightest(String street) {
    return 'Endroit le plus lumineux : $street';
  }
}
