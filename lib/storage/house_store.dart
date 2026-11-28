import 'dart:io';

import '../logic/house.dart';

/// Où vit la maison : un fichier sur le téléphone, ou la mémoire dans les tests.
abstract class HouseStore {
  Future<House> load();

  Future<void> save(House pHouse);
}

class MemoryHouseStore implements HouseStore {
  MemoryHouseStore([this.saved = const House()]);

  House saved;

  @override
  Future<House> load() async => saved;

  @override
  Future<void> save(House pHouse) async => saved = pHouse;
}

/// Fichier `maison.json`, écrit sans risque de fichier à moitié écrit.
class FileHouseStore implements HouseStore {
  FileHouseStore(this.file);

  final File file;

  @override
  Future<House> load() async =>
      await file.exists() ? parseHouse(await file.readAsString()) : const House();

  @override
  Future<void> save(House pHouse) async {
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(houseJson(pHouse), flush: true);
    await vTemp.rename(file.path);
  }
}
