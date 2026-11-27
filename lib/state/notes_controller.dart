import 'package:flutter/foundation.dart';

import '../logic/notes.dart';
import '../storage/notes_store.dart';

/// Notes datées de la maison.
class NotesController extends ChangeNotifier {
  NotesController(this._store);

  final NotesStore _store;
  var _notes = <HouseNote>[];

  List<HouseNote> get notes => List.unmodifiable(_notes);

  /// Les notes de toute la maison et celles du capteur donné.
  List<HouseNote> forSensor(String pSensorName) => [
    for (final vNote in _notes)
      if (vNote.sensor == null || vNote.sensor == pSensorName) vNote,
  ];

  Future<void> load() async {
    _notes = await _store.load();
    notifyListeners();
  }

  /// Ajoute une note ; un texte vide est refusé (renvoie false).
  Future<bool> add(DateTime pDay, String pText, {String? pSensor}) async {
    if (pText.trim().isEmpty) {
      return false;
    }
    _notes = [
      HouseNote(
        at: DateTime(pDay.year, pDay.month, pDay.day),
        text: pText.trim(),
        sensor: pSensor,
      ),
      ..._notes,
    ]..sort((pA, pB) => pB.at.compareTo(pA.at));
    await _store.save(_notes);
    notifyListeners();

    return true;
  }

  Future<void> remove(HouseNote pNote) async {
    _notes = [
      for (final vNote in _notes)
        if (!identical(vNote, pNote)) vNote,
    ];
    await _store.save(_notes);
    notifyListeners();
  }
}
