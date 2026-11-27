import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home/l10n/gen/app_localizations.dart';
import 'package:home/ui/theme.dart';

/// Enveloppe un widget dans le thème et les textes de l'appli, en français.
Widget localized(Widget pChild) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('fr'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: pChild,
);
