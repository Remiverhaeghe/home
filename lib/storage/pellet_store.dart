import 'dart:io';

import '../logic/pellet.dart';

/// Où vit le poêle enregistré : un fichier sur le téléphone, ou la mémoire dans les tests.
abstract class PelletStore {
  Future<PelletStove?> load();

  Future<void> save(PelletStove? pStove);
}

class MemoryPelletStore implements PelletStore {
  MemoryPelletStore([this.saved]);

  PelletStove? saved;

  @override
  Future<PelletStove?> load() async => saved;

  @override
  Future<void> save(PelletStove? pStove) async => saved = pStove;
}

/// Fichier `poele.json` dans le dossier privé de l'appli, écrit sans risque de fichier à moitié
/// écrit.
class FilePelletStore implements PelletStore {
  FilePelletStore(this.file);

  final File file;

  @override
  Future<PelletStove?> load() async =>
      await file.exists() ? parsePellet(await file.readAsString()) : null;

  @override
  Future<void> save(PelletStove? pStove) async {
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(pelletJson(pStove), flush: true);
    await vTemp.rename(file.path);
  }
}
