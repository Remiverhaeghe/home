import 'dart:io';

import '../logic/pellet_runs.dart';

/// Où vit le journal de marche du poêle : un fichier sur le téléphone, ou la mémoire dans les tests.
abstract class PelletRunsStore {
  Future<PelletRuns> load();

  Future<void> save(PelletRuns pRuns);
}

class MemoryPelletRunsStore implements PelletRunsStore {
  MemoryPelletRunsStore([this.saved = const PelletRuns()]);

  PelletRuns saved;

  @override
  Future<PelletRuns> load() async => saved;

  @override
  Future<void> save(PelletRuns pRuns) async => saved = pRuns;
}

/// Fichier `marche-poele.json`, écrit sans risque de fichier à moitié écrit.
class FilePelletRunsStore implements PelletRunsStore {
  FilePelletRunsStore(this.file);

  final File file;

  @override
  Future<PelletRuns> load() async =>
      await file.exists() ? parsePelletRuns(await file.readAsString()) : const PelletRuns();

  @override
  Future<void> save(PelletRuns pRuns) async {
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(pelletRunsJson(pRuns), flush: true);
    await vTemp.rename(file.path);
  }
}
