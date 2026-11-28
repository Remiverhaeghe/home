import 'dart:io';

import '../logic/heating_costs.dart';

/// Où vivent les heures de marche des clims et les réglages de coût : un fichier sur le téléphone,
/// ou la mémoire dans les tests.
abstract class AcRunsStore {
  Future<AcRuns> load();

  Future<void> save(AcRuns pRuns);
}

class MemoryAcRunsStore implements AcRunsStore {
  MemoryAcRunsStore([this.saved = const AcRuns()]);

  AcRuns saved;

  @override
  Future<AcRuns> load() async => saved;

  @override
  Future<void> save(AcRuns pRuns) async => saved = pRuns;
}

/// Fichier `marche-clims.json`, écrit sans risque de fichier à moitié écrit.
class FileAcRunsStore implements AcRunsStore {
  FileAcRunsStore(this.file);

  final File file;

  @override
  Future<AcRuns> load() async =>
      await file.exists() ? parseAcRuns(await file.readAsString()) : const AcRuns();

  @override
  Future<void> save(AcRuns pRuns) async {
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(acRunsJson(pRuns), flush: true);
    await vTemp.rename(file.path);
  }
}
