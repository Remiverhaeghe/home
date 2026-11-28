import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/day_summary.dart';
import 'package:home/logic/rooms.dart';

RoomStatus _room(String pName, double pTemp, double pHumidity) => RoomStatus(
  room: pName,
  floor: 0,
  sensors: [pName],
  temp: pTemp,
  humidity: pHumidity,
  range: const HumidityRange(40, 60),
);

void main() {
  test('sans pièce, il n\'y a pas de résumé', () {
    expect(buildDaySummary(const []), isNull);
  });

  test('le résumé nomme la pièce la plus fraîche et la plus humide', () {
    final vSummary = buildDaySummary([
      _room('Salon', 21, 45),
      _room('Chambre', 16.5, 52),
      _room('Cellier', 14, 72),
    ])!;

    expect(vSummary.title, 'Résumé de la maison');
    expect(vSummary.body, contains('Pièce la plus fraîche : Cellier (14,0 °C).'));
    expect(vSummary.body, contains('Pièce la plus humide : Cellier (72 %).'));
    expect(vSummary.body, contains('1 pièce hors de la plage d\'humidité.'));
  });

  test('toutes les pièces dans leur plage : humidité correcte partout', () {
    final vSummary = buildDaySummary([_room('Salon', 21, 45), _room('Chambre', 18, 50)])!;

    expect(vSummary.body, contains('Humidité correcte partout.'));
  });

  test('plusieurs pièces hors plage sont comptées au pluriel', () {
    final vSummary = buildDaySummary([_room('A', 20, 30), _room('B', 20, 80)])!;

    expect(vSummary.body, contains('2 pièces hors de la plage d\'humidité.'));
  });

  group('envoi du jour', () {
    final vMorning = DateTime(2026, 12, 7, 8, 10);

    test('pas avant l\'heure', () {
      expect(summaryDue(DateTime(2026, 12, 7, 7, 59), pLastSent: null), isFalse);
    });

    test('jamais envoyé, l\'heure passée : il part', () {
      expect(summaryDue(vMorning, pLastSent: null), isTrue);
    });

    test('déjà envoyé aujourd\'hui : il ne repart pas, le lendemain oui', () {
      final vSent = DateTime(2026, 12, 7, 8, 5);

      expect(summaryDue(DateTime(2026, 12, 7, 15), pLastSent: vSent), isFalse);
      expect(summaryDue(DateTime(2026, 12, 8, 8, 1), pLastSent: vSent), isTrue);
    });
  });
}
