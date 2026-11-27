import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/appearance.dart';
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
              const SizedBox(height: 16),
              Text(vTexts.appearanceSample, style: Theme.of(pContext).textTheme.bodyLarge),
            ],
          );
        },
      ),
    );
  }
}
