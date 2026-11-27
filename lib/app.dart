import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'background/background_control.dart';
import 'l10n/gen/app_localizations.dart';
import 'state/ac_controller.dart';
import 'state/sensors_controller.dart';
import 'storage/background_files.dart';
import 'ui/sensors_screen.dart';
import 'ui/theme.dart';

class HomeApp extends StatefulWidget {
  const HomeApp({
    super.key,
    required this.controller,
    this.acController,
    this.background,
    this.files,
  });

  final SensorsController controller;
  final AcController? acController;

  /// Service de relevé en arrière-plan et fichiers qu'il partage avec l'appli.
  final BackgroundControl? background;
  final BackgroundFiles? files;

  @override
  State<HomeApp> createState() => _HomeAppState();
}

class _HomeAppState extends State<HomeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncPending();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Les relevés pris en arrière-plan sont rangés à l'ouverture et à chaque retour dans l'appli.
  @override
  void didChangeAppLifecycleState(AppLifecycleState pState) {
    if (pState == AppLifecycleState.resumed) {
      _syncPending();
    }
  }

  void _syncPending() {
    final vFiles = widget.files;
    if (vFiles != null) {
      unawaited(widget.controller.syncPending(vFiles.takePending));
    }
  }

  @override
  Widget build(BuildContext pContext) => MaterialApp(
    onGenerateTitle: (pContext) => AppLocalizations.of(pContext).appTitle,
    theme: buildTheme(),
    locale: const Locale('fr'),
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
      background: widget.background,
      files: widget.files,
    ),
  );
}
