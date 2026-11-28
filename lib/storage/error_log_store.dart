import 'dart:io';

import '../logic/error_log.dart';

/// Où vit le journal d'erreurs : un fichier sur le téléphone, ou la mémoire dans les tests.
abstract class ErrorLogStore {
  /// Ajoute une entrée à la fin du journal.
  Future<void> append(String pEntry);

  Future<String> read();

  Future<void> clear();
}

class MemoryErrorLogStore implements ErrorLogStore {
  var text = '';

  @override
  Future<void> append(String pEntry) async =>
      text = trimLog(text.isEmpty ? pEntry : '$text\n$pEntry');

  @override
  Future<String> read() async => text;

  @override
  Future<void> clear() async => text = '';
}

/// Fichier `journal-erreurs.txt` dans le dossier privé de l'appli.
class FileErrorLogStore implements ErrorLogStore {
  FileErrorLogStore(this.file);

  final File file;

  @override
  Future<void> append(String pEntry) async {
    final vOld = await read();
    await file.writeAsString(trimLog(vOld.isEmpty ? pEntry : '$vOld\n$pEntry'), flush: true);
  }

  @override
  Future<String> read() async => await file.exists() ? file.readAsString() : '';

  @override
  Future<void> clear() async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
