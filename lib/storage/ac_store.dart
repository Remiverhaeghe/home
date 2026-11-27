import 'dart:io';

import '../logic/ac_units.dart';

/// Où vivent les climatisations : un fichier sur le téléphone, ou la mémoire dans les tests.
abstract class AcStore {
  Future<List<AcUnit>> load();

  Future<void> save(List<AcUnit> pUnits);
}

class MemoryAcStore implements AcStore {
  MemoryAcStore([List<AcUnit>? pUnits]) : saved = pUnits ?? [];

  List<AcUnit> saved;

  @override
  Future<List<AcUnit>> load() async => saved;

  @override
  Future<void> save(List<AcUnit> pUnits) async => saved = pUnits;
}

/// Fichier `climatisations.json` sur le téléphone, écrit sans risque de fichier à moitié écrit.
class FileAcStore implements AcStore {
  FileAcStore(this.file);

  final File file;

  @override
  Future<List<AcUnit>> load() async =>
      await file.exists() ? parseAcUnits(await file.readAsString()) : [];

  @override
  Future<void> save(List<AcUnit> pUnits) async {
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(acUnitsJson(pUnits), flush: true);
    await vTemp.rename(file.path);
  }
}
