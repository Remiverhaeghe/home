import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/appearance.dart';
import '../logic/units.dart';
import '../state/appearance_controller.dart';

/// Thème (clair, sombre, celui du téléphone) et taille du texte.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key, required this.controller});

  final AppearanceController controller;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.appearanceTitle)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (pContext, _) {
          final vSettings = controller.settings;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(vTexts.appearanceTheme, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<ThemeChoice>(
                segments: [
                  ButtonSegment(value: ThemeChoice.system, label: Text(vTexts.themeSystem)),
                  ButtonSegment(value: ThemeChoice.light, label: Text(vTexts.themeLight)),
                  ButtonSegment(value: ThemeChoice.dark, label: Text(vTexts.themeDark)),
                ],
                selected: {vSettings.theme},
                onSelectionChanged: (pChoice) => controller.setTheme(pChoice.first),
              ),
              const SizedBox(height: 24),
              Text(vTexts.appearanceTextSize, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<double>(
                segments: [
                  ButtonSegment(value: textScales[0], label: Text(vTexts.textSizeNormal)),
                  ButtonSegment(value: textScales[1], label: Text(vTexts.textSizeLarge)),
                  ButtonSegment(value: textScales[2], label: Text(vTexts.textSizeLarger)),
                  ButtonSegment(value: textScales[3], label: Text(vTexts.textSizeLargest)),
                ],
                selected: {vSettings.textScale},
                onSelectionChanged: (pScale) => controller.setTextScale(pScale.first),
              ),
              const SizedBox(height: 24),
              Text(vTexts.appearanceLanguage, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<AppLanguage>(
                segments: [
                  ButtonSegment(value: AppLanguage.french, label: Text(vTexts.languageFrench)),
                  ButtonSegment(value: AppLanguage.english, label: Text(vTexts.languageEnglish)),
                ],
                selected: {vSettings.language},
                onSelectionChanged: (pLanguage) => controller.setLanguage(pLanguage.first),
              ),
              const SizedBox(height: 24),
              Text(vTexts.appearanceUnit, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<TemperatureUnit>(
                segments: [
                  ButtonSegment(value: TemperatureUnit.celsius, label: Text(vTexts.unitCelsius)),
                  ButtonSegment(
                    value: TemperatureUnit.fahrenheit,
                    label: Text(vTexts.unitFahrenheit),
                  ),
                ],
                selected: {vSettings.temperatureUnit},
                onSelectionChanged: (pUnit) => controller.setTemperatureUnit(pUnit.first),
              ),
              const SizedBox(height: 16),
              Text(
                vTexts.appearanceSample(Units(temperature: vSettings.temperatureUnit).temp(21.5)),
                style: Theme.of(pContext).textTheme.bodyLarge,
              ),
            ],
          );
        },
      ),
    );
  }
}
