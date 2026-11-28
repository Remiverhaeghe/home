/// Réglages d'affichage : thème clair, sombre ou celui du téléphone, et taille du texte.
library;

import 'dart:convert';

import 'units.dart';

enum ThemeChoice { system, light, dark }

/// Facteurs de taille du texte proposés : normale, grande, très grande, maximale.
const textScales = [1.0, 1.15, 1.3, 1.5];

class AppearanceSettings {
  const AppearanceSettings({
    this.theme = ThemeChoice.dark,
    this.textScale = 1.0,
    this.temperatureUnit = TemperatureUnit.celsius,
  });

  final ThemeChoice theme;

  /// Un des [textScales].
  final double textScale;

  /// Unité d'affichage des températures (les données restent en °C).
  final TemperatureUnit temperatureUnit;

  AppearanceSettings copyWith({
    ThemeChoice? theme,
    double? textScale,
    TemperatureUnit? temperatureUnit,
  }) => AppearanceSettings(
    theme: theme ?? this.theme,
    textScale: textScale ?? this.textScale,
    temperatureUnit: temperatureUnit ?? this.temperatureUnit,
  );
}

/// Fichier `apparence.json`, version 1.
String appearanceJson(AppearanceSettings pSettings) => jsonEncode({
  'version': 1,
  'theme': pSettings.theme.name,
  'textScale': pSettings.textScale,
  'temperatureUnit': pSettings.temperatureUnit.name,
});

/// Relit le fichier ; une valeur inconnue ou un fichier abîmé redonnent les réglages de départ.
AppearanceSettings parseAppearance(String pText) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pText);
  } on FormatException {
    return const AppearanceSettings();
  }
  if (vRoot is! Map<String, dynamic> || vRoot['version'] != 1) {
    return const AppearanceSettings();
  }
  final vThemeName = vRoot['theme'];
  final vTheme = ThemeChoice.values.where((pChoice) => pChoice.name == vThemeName);
  final vScale = vRoot['textScale'];
  final vUnit = TemperatureUnit.values.where((pUnit) => pUnit.name == vRoot['temperatureUnit']);

  return AppearanceSettings(
    theme: vTheme.isEmpty ? ThemeChoice.dark : vTheme.first,
    textScale: vScale is num && textScales.contains(vScale.toDouble()) ? vScale.toDouble() : 1.0,
    temperatureUnit: vUnit.isEmpty ? TemperatureUnit.celsius : vUnit.first,
  );
}
