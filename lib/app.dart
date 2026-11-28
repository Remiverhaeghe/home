import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'background/alert_notifier.dart';
import 'background/background_control.dart';
import 'l10n/gen/app_localizations.dart';
import 'state/ac_controller.dart';
import 'state/plan_controller.dart';
import 'state/house_controller.dart';
import 'ble/tp357_link.dart';
import 'logic/appearance.dart';
import 'logic/units.dart';
import 'state/appearance_controller.dart';
import 'state/notes_controller.dart';
import 'state/pellet_controller.dart';
import 'storage/backup_files.dart';
import 'state/weather_controller.dart';
import 'state/relay_controller.dart';
import 'state/sensors_controller.dart';
import 'storage/background_files.dart';
import 'storage/detail_log.dart';
import 'storage/error_log_store.dart';
import 'ui/sensors_screen.dart';
import 'ui/theme.dart';
import 'ui/units_scope.dart';

class HomeApp extends StatefulWidget {
  const HomeApp({
    super.key,
    required this.controller,
    this.acController,
    this.planController,
    this.relayController,
    this.pelletController,
    this.errorLog,
    this.detailLog,
    this.houseController,
    this.weatherController,
    this.backupFiles,
    this.appearance,
    this.notes,
    this.onRestored,
    this.notifier,
    this.background,
    this.files,
    this.link,
  });

  final SensorsController controller;
  final AcController? acController;
  final PlanController? planController;

  /// Garage et Velux à relais Wi-Fi.
  final RelayController? relayController;
  final PelletController? pelletController;
  final ErrorLogStore? errorLog;
  final DetailLog? detailLog;
  final HouseController? houseController;
  final WeatherController? weatherController;
  final BackupFiles? backupFiles;

  /// Thème et taille du texte ; sans lui, thème sombre et texte normal.
  final AppearanceController? appearance;
  final NotesController? notes;
  final Future<void> Function()? onRestored;

  /// Notifications d'alerte ; sans elles, les alertes restent visibles dans l'écran Pilotage.
  final AlertNotifier? notifier;

  /// Service de relevé en arrière-plan et fichiers qu'il partage avec l'appli.
  final BackgroundControl? background;
  final BackgroundFiles? files;

  /// Liaison Bluetooth ; remplacée par une fausse dans les tests.
  final Tp357Link? link;

  @override
  State<HomeApp> createState() => _HomeAppState();
}

/// Intervalle entre deux passages du plan tant que l'appli est ouverte.
const planInterval = Duration(minutes: 5);

class _HomeAppState extends State<HomeApp> with WidgetsBindingObserver {
  /// Écouté à la place du contrôleur d'apparence quand il n'y en a pas.
  final _noAppearance = ValueNotifier<int>(0);

  Timer? _planTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncPending();
    if (widget.acController != null && widget.planController != null) {
      _planTimer = Timer.periodic(planInterval, (_) => unawaited(_runPlan()));
      unawaited(_runPlan());
    }
  }

  /// Relit les climatisations puis applique le plan.
  Future<void> _runPlan() async {
    final vNow = DateTime.now();
    // Le service d'arrière-plan s'efface tant que l'appli se signale
    await widget.files?.markAppOpen(vNow);
    final vFiles = widget.files;
    if (vFiles != null) {
      widget.planController!.watched = {
        for (final vDevice in await vFiles.loadFollowed()) vDevice.name,
      };
    }
    final vPellet = widget.pelletController;
    if (vPellet != null) {
      final vOn = await vPellet.refreshAndStopIfAway(widget.planController!.vacation, vNow);
      widget.planController!.stoveRunning = vOn;
    }
    await widget.acController!.refresh();
    final vFresh = await widget.planController!.tick(vNow);
    await widget.notifier?.show(vFresh);
  }

  @override
  void dispose() {
    _planTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Les relevés pris en arrière-plan sont rangés à l'ouverture et à chaque retour dans l'appli.
  @override
  void didChangeAppLifecycleState(AppLifecycleState pState) {
    if (pState == AppLifecycleState.resumed) {
      _syncPending();
      unawaited(_refreshOnResume());
    }
  }

  /// Au retour dans l'appli, relève les capteurs à portée si la dernière relève date. Seulement
  /// quand des capteurs sont suivis en arrière-plan : l'accord Bluetooth est alors déjà donné.
  Future<void> _refreshOnResume() async {
    final vFiles = widget.files;
    if (vFiles == null || (await vFiles.loadFollowed()).isEmpty) {
      return;
    }
    try {
      await widget.controller.refreshIfStale(widget.link ?? BleTp357Link(), DateTime.now());
    } on Object {
      // Bluetooth coupé : la relève manuelle reste possible
    }
  }

  void _syncPending() {
    final vFiles = widget.files;
    if (vFiles != null) {
      unawaited(widget.controller.syncPending(vFiles.takePending));
    }
  }

  @override
  Widget build(BuildContext pContext) => ListenableBuilder(
    listenable: widget.appearance ?? _noAppearance,
    builder: (pContext, _) => _app(widget.appearance?.settings ?? const AppearanceSettings()),
  );

  Widget _app(AppearanceSettings pLook) => MaterialApp(
    onGenerateTitle: (pContext) => AppLocalizations.of(pContext).appTitle,
    theme: buildTheme(pBrightness: Brightness.light),
    darkTheme: buildTheme(),
    themeMode: switch (pLook.theme) {
      ThemeChoice.system => ThemeMode.system,
      ThemeChoice.light => ThemeMode.light,
      ThemeChoice.dark => ThemeMode.dark,
    },
    builder: (pContext, pChild) => MediaQuery(
      data: MediaQuery.of(pContext).copyWith(
        textScaler: TextScaler.linear(MediaQuery.textScalerOf(pContext).scale(1) * pLook.textScale),
      ),
      child: UnitsScope(
        units: Units(temperature: pLook.temperatureUnit),
        child: pChild!,
      ),
    ),
    locale: Locale(pLook.language.code),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: SensorsScreen(
      controller: widget.controller,
      acController: widget.acController,
      planController: widget.planController,
      relayController: widget.relayController,
      pelletController: widget.pelletController,
      errorLog: widget.errorLog,
      detailLog: widget.detailLog,
      houseController: widget.houseController,
      weatherController: widget.weatherController,
      backupFiles: widget.backupFiles,
      appearance: widget.appearance,
      notes: widget.notes,
      onRestored: widget.onRestored,
      background: widget.background,
      files: widget.files,
    ),
  );
}
