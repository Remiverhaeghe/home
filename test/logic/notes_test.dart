import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/notes.dart';
import 'package:home/logic/reading.dart';

/// Un relevé par heure, [pDays] jours à partir du jour [pStart] de novembre.
List<Reading> _hourly(int pStart, int pDays, double pTemp, double pHumidity) => [
  for (var vHour = 0; vHour < pDays * 24; vHour++)
    Reading(
      at: DateTime(2026, 11, pStart).add(Duration(hours: vHour)),
      temp: pTemp,
      humidity: pHumidity,
    ),
];

void main() {
  test('le fichier garde les notes, de la plus récente à la plus ancienne', () {
    final vBack = parseNotes(
      notesJson([
        HouseNote(at: DateTime(2026, 5, 1), text: 'Fenêtre changée', sensor: 'A'),
        HouseNote(at: DateTime(2026, 9, 10), text: 'Isolation posée'),
      ]),
    );

    expect(vBack.map((pNote) => pNote.text), ['Isolation posée', 'Fenêtre changée']);
    expect(vBack.last.sensor, 'A');
    expect(vBack.first.sensor, isNull);
  });

  test('un fichier abîmé ou une note illisible sont ignorés', () {
    expect(parseNotes('pas du json'), isEmpty);
    expect(parseNotes('{"version":2,"notes":[]}'), isEmpty);
    expect(parseNotes('{"version":1,"notes":[1,{"at":"x","text":"a"},{"at":"2026-01-01","text":" "}]}'), isEmpty);
  });

  test('avant et après se comparent sur deux semaines de chaque côté', () {
    final vReadings = [..._hourly(1, 14, 17, 70), ..._hourly(15, 14, 20, 55)];

    final vEffect = beforeAfter(vReadings, DateTime(2026, 11, 15), pNow: DateTime(2026, 12, 20))!;

    expect(vEffect.tempBefore, 17);
    expect(vEffect.tempAfter, 20);
    expect(vEffect.tempChange, 3);
    expect(vEffect.humidityChange, -15);
    expect(vEffect.days, 14);
  });

  test('pas de comparaison si la période d\'après n\'est pas finie', () {
    final vReadings = [..._hourly(1, 14, 17, 70), ..._hourly(15, 14, 20, 55)];

    expect(beforeAfter(vReadings, DateTime(2026, 11, 15), pNow: DateTime(2026, 11, 20)), isNull);
  });

  test('pas de comparaison s\'il manque des relevés d\'un côté', () {
    final vReadings = _hourly(15, 14, 20, 55);

    expect(beforeAfter(vReadings, DateTime(2026, 11, 15), pNow: DateTime(2026, 12, 20)), isNull);
  });
}
