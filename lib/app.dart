import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/gen/app_localizations.dart';
import 'state/ac_controller.dart';
import 'state/sensors_controller.dart';
import 'ui/sensors_screen.dart';
import 'ui/theme.dart';

class HomeApp extends StatelessWidget {
  const HomeApp({super.key, required this.controller, this.acController});

  final SensorsController controller;
  final AcController? acController;

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
    home: SensorsScreen(controller: controller, acController: acController),
  );
}
