import 'dart:io';

import '../logic/appearance.dart';

/// Où vivent les réglages d'affichage : un fichier sur le téléphone, ou la mémoire dans les tests.
abstract class AppearanceStore {
  Future<AppearanceSettings> load();

  Future<void> save(AppearanceSettings pSettings);
}

class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([this.saved = const AppearanceSettings()]);

  AppearanceSettings saved;

  @override
  Future<AppearanceSettings> load() async => saved;

  @override
  Future<void> save(AppearanceSettings pSettings) async => saved = pSettings;
}

/// Fichier `apparence.json`, écrit sans risque de fichier à moitié écrit.
class FileAppearanceStore implements AppearanceStore {
  FileAppearanceStore(this.file);

  final File file;

  @override
  Future<AppearanceSettings> load() async =>
      await file.exists() ? parseAppearance(await file.readAsString()) : const AppearanceSettings();

  @override
  Future<void> save(AppearanceSettings pSettings) async {
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(appearanceJson(pSettings), flush: true);
    await vTemp.rename(file.path);
  }
}
