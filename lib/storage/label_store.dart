import 'dart:convert';
import 'dart:io';

/// Noms donnés aux capteurs, par identifiant : un fichier sur le téléphone, ou la mémoire dans les
/// tests.
abstract class LabelStore {
  Future<Map<String, String>> load();

  Future<void> save(Map<String, String> pLabels);
}

class MemoryLabelStore implements LabelStore {
  MemoryLabelStore([Map<String, String>? pLabels]) : saved = pLabels ?? {};

  Map<String, String> saved;

  @override
  Future<Map<String, String>> load() async => Map.of(saved);

  @override
  Future<void> save(Map<String, String> pLabels) async => saved = Map.of(pLabels);
}

/// Fichier `noms-capteurs.json`, écrit sans risque de fichier à moitié écrit.
class FileLabelStore implements LabelStore {
  FileLabelStore(this.file);

  final File file;

  @override
  Future<Map<String, String>> load() async {
    if (!await file.exists()) {
      return {};
    }
    try {
      final vRoot = jsonDecode(await file.readAsString());
      if (vRoot is! Map<String, dynamic>) {
        return {};
      }

      return {
        for (final vEntry in vRoot.entries)
          if (vEntry.value is String && (vEntry.value as String).trim().isNotEmpty)
            vEntry.key: (vEntry.value as String).trim(),
      };
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, String> pLabels) async {
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(jsonEncode(pLabels), flush: true);
    await vTemp.rename(file.path);
  }
}
