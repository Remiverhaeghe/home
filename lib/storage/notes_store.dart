import 'dart:io';

import '../logic/notes.dart';

/// Où vivent les notes : un fichier sur le téléphone, ou la mémoire dans les tests.
abstract class NotesStore {
  Future<List<HouseNote>> load();

  Future<void> save(List<HouseNote> pNotes);
}

class MemoryNotesStore implements NotesStore {
  MemoryNotesStore([List<HouseNote>? pNotes]) : saved = pNotes ?? [];

  List<HouseNote> saved;

  @override
  Future<List<HouseNote>> load() async => saved;

  @override
  Future<void> save(List<HouseNote> pNotes) async => saved = pNotes;
}

/// Fichier `notes.json`, écrit sans risque de fichier à moitié écrit.
class FileNotesStore implements NotesStore {
  FileNotesStore(this.file);

  final File file;

  @override
  Future<List<HouseNote>> load() async =>
      await file.exists() ? parseNotes(await file.readAsString()) : [];

  @override
  Future<void> save(List<HouseNote> pNotes) async {
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(notesJson(pNotes), flush: true);
    await vTemp.rename(file.path);
  }
}
