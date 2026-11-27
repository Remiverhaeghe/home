import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/pending_readings.dart';
import 'package:home/logic/reading.dart';

import '../support/sensors.dart';

Reading _at(DateTime pAt, [double pTemp = 21]) => Reading(at: pAt, temp: pTemp, humidity: 50);

void main() {
  group('relevés en attente', () {
    test('une ligne écrite se relit à l\'identique', () {
      final vLine = pendingLine('TP357 (1A2B)', _at(DateTime(2026, 12, 1, 8, 5), 21.5));

      final vBack = parsePending(vLine).single;

      expect(vBack.sensor, 'TP357 (1A2B)');
      expect(vBack.reading.at, DateTime(2026, 12, 1, 8, 5));
      expect(vBack.reading.temp, 21.5);
      expect(vBack.reading.humidity, 50);
    });

    test('plusieurs lignes sont lues dans l\'ordre du fichier', () {
      final vText =
          '${pendingLine('A', _at(DateTime(2026, 12, 1, 8)))}\n'
          '${pendingLine('B', _at(DateTime(2026, 12, 1, 9)))}\n';

      expect(parsePending(vText).map((pItem) => pItem.sensor), ['A', 'B']);
    });

    test('une ligne coupée, illisible ou incomplète est ignorée', () {
      final vGood = pendingLine('A', _at(DateTime(2026, 12, 1, 8)));
      final vText = [
        vGood,
        '{"sensor": "A", "at": "2026-12-01T09:00:00", "te',
        'pas du json',
        '[1, 2]',
        '{"sensor": " ", "at": "2026-12-01T09:00:00", "temp": 1, "humidity": 2}',
        '{"sensor": "A", "at": "pas une date", "temp": 1, "humidity": 2}',
        '{"sensor": "A", "at": "2026-12-01T09:00:00", "temp": "x", "humidity": 2}',
        '{"sensor": "A", "at": "2026-12-01T09:00:00", "temp": 1, "humidity": "x"}',
        '{"at": "2026-12-01T09:00:00", "temp": 1, "humidity": 2}',
        '',
      ].join('\n');

      expect(parsePending(vText), hasLength(1));
    });

    test('un texte vide ne donne rien', () {
      expect(parsePending(''), isEmpty);
    });

    test('les relevés sont rangés dans l\'ordre du temps, au plus un par minute', () {
      final vSensors = applyPending(
        [],
        [
          PendingReading(sensor: 'A', reading: _at(DateTime(2026, 12, 1, 8, 10), 22)),
          PendingReading(sensor: 'A', reading: _at(DateTime(2026, 12, 1, 8, 0), 20)),
          PendingReading(sensor: 'A', reading: _at(DateTime(2026, 12, 1, 8, 0, 30), 99)),
        ],
      );

      expect(vSensors.single.readings.map((pR) => pR.temp), [20, 22]);
    });

    test('ils s\'ajoutent aux relevés déjà là', () {
      final vSensors = applyPending(
        [bathroomSensor()],
        [PendingReading(sensor: 'Salle de bain', reading: _at(DateTime(2026, 12, 3, 8)))],
      );

      expect(vSensors.single.readings, hasLength(4));
    });
  });

  group('capteurs suivis', () {
    test('la liste écrite se relit', () {
      final vBack = parseFollowed(
        followedJson([
          const FollowedDevice(id: 'AA:BB', name: 'TP357 (1A2B)'),
          const FollowedDevice(id: 'CC:DD', name: 'TP357 (3C4D)'),
        ]),
      );

      expect(vBack.map((pD) => pD.id), ['AA:BB', 'CC:DD']);
      expect(vBack.first.name, 'TP357 (1A2B)');
    });

    test('un texte abîmé ou une entrée incomplète sont ignorés', () {
      expect(parseFollowed('pas du json'), isEmpty);
      expect(parseFollowed('{"id": "A"}'), isEmpty);
      expect(parseFollowed('[{"id": "A"}, {"name": "B"}, {"id": 1, "name": "C"}, 3]'), isEmpty);
      expect(parseFollowed('[{"id": "A", "name": "B"}]'), hasLength(1));
    });
  });
}
