import 'package:flutter_test/flutter_test.dart';
import 'package:home/state/notes_controller.dart';
import 'package:home/storage/notes_store.dart';

void main() {
  late MemoryNotesStore vStore;
  late NotesController vController;

  setUp(() async {
    vStore = MemoryNotesStore();
    vController = NotesController(vStore);
    await vController.load();
  });

  test('une note est rangée, la plus récente en premier', () async {
    await vController.add(DateTime(2026, 5, 1, 15), 'Fenêtre changée');
    await vController.add(DateTime(2026, 9, 10), ' Isolation posée ');

    expect(vController.notes.map((pNote) => pNote.text), ['Isolation posée', 'Fenêtre changée']);
    expect(vController.notes.last.at, DateTime(2026, 5, 1));
    expect(vStore.saved, hasLength(2));
  });

  test('un texte vide est refusé', () async {
    expect(await vController.add(DateTime(2026, 5, 1), '  '), isFalse);
    expect(vController.notes, isEmpty);
  });

  test('un capteur voit ses notes et celles de toute la maison', () async {
    await vController.add(DateTime(2026, 5, 1), 'Maison');
    await vController.add(DateTime(2026, 5, 2), 'Salon', pSensor: 'A');
    await vController.add(DateTime(2026, 5, 3), 'Cave', pSensor: 'B');

    expect(vController.forSensor('A').map((pNote) => pNote.text), ['Salon', 'Maison']);
  });

  test('une note se retire', () async {
    await vController.add(DateTime(2026, 5, 1), 'Maison');

    await vController.remove(vController.notes.single);

    expect(vController.notes, isEmpty);
    expect(vStore.saved, isEmpty);
  });
}
