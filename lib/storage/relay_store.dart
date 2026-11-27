import 'dart:io';

import '../logic/relay.dart';

/// Où vivent les boutons à relais : un fichier sur le téléphone, ou la mémoire dans les tests.
abstract class RelayStore {
  Future<List<RelayButton>> load();

  Future<void> save(List<RelayButton> pButtons);
}

class MemoryRelayStore implements RelayStore {
  MemoryRelayStore([List<RelayButton>? pButtons]) : saved = pButtons ?? [];

  List<RelayButton> saved;

  @override
  Future<List<RelayButton>> load() async => saved;

  @override
  Future<void> save(List<RelayButton> pButtons) async => saved = pButtons;
}

/// Fichier `relais.json` sur le téléphone, écrit sans risque de fichier à moitié écrit.
class FileRelayStore implements RelayStore {
  FileRelayStore(this.file);

  final File file;

  @override
  Future<List<RelayButton>> load() async =>
      await file.exists() ? parseRelays(await file.readAsString()) : [];

  @override
  Future<void> save(List<RelayButton> pButtons) async {
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(relaysJson(pButtons), flush: true);
    await vTemp.rename(file.path);
  }
}
