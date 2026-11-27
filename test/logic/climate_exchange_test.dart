import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/climate_exchange.dart';

import '../support/sensors.dart';

void main() {
  test('lit un fichier d\'échange valide', () {
    final vSensors = parseExchange(exchangeSample);

    expect(vSensors.single.name, 'Salle de bain');
    expect(vSensors.single.readings.single.temp, 20.5);
    expect(vSensors.single.readings.single.humidity, 61);
    expect(vSensors.single.readings.single.at, DateTime(2026, 12, 1, 8));
  });

  test('un texte qui n\'est pas du JSON est refusé', () {
    expect(
      () => parseExchange('pas du json'),
      throwsA(
        isA<ExchangeException>().having(
          (pE) => pE.problem,
          'motif',
          ExchangeProblem.notJson,
        ),
      ),
    );
    expect(() => parseExchange('[1, 2]'), throwsA(isA<ExchangeException>()));
  });

  test('une autre version est refusée', () {
    expect(
      () => parseExchange('{"version": 2, "sensors": []}'),
      throwsA(
        isA<ExchangeException>().having(
          (pE) => pE.problem,
          'motif',
          ExchangeProblem.wrongVersion,
        ),
      ),
    );
  });

  test('sans liste de capteurs, le fichier est refusé', () {
    expect(
      () => parseExchange('{"version": 1}'),
      throwsA(
        isA<ExchangeException>().having(
          (pE) => pE.problem,
          'motif',
          ExchangeProblem.noSensors,
        ),
      ),
    );
  });

  test('un relevé invalide ou un capteur sans nom est ignoré', () {
    final vSensors = parseExchange('''
{
  "version": 1,
  "sensors": [
    {"name": "  ", "readings": []},
    "intrus",
    {"name": "Cave", "readings": [
      {"at": "pas une date", "temp": 10, "humidity": 80},
      {"at": "2026-12-01T08:00:00", "temp": "chaud", "humidity": 80},
      {"at": "2026-12-01T09:00:00", "temp": 10, "humidity": 140},
      "intrus",
      {"at": "2026-12-01T10:00:00", "temp": 11, "humidity": 82}
    ]}
  ]
}
''');

    expect(vSensors, hasLength(1));
    expect(vSensors.single.readings, hasLength(1));
    expect(vSensors.single.readings.single.temp, 11);
  });

  test('les relevés sont rangés du plus ancien au plus récent', () {
    final vSensors = parseExchange('''
{"version": 1, "sensors": [{"name": "Cave", "readings": [
  {"at": "2026-12-02T08:00:00", "temp": 12, "humidity": 60},
  {"at": "2026-12-01T08:00:00", "temp": 10, "humidity": 60}
]}]}
''');

    expect(vSensors.single.readings.first.temp, 10);
    expect(vSensors.single.last!.temp, 12);
  });

  test('écrire puis relire rend les mêmes capteurs', () {
    final vBack = parseExchange(exchangeJson([bathroomSensor()]));

    expect(vBack.single.name, 'Salle de bain');
    expect(vBack.single.readings, hasLength(3));
    expect(vBack.single.readings[1].temp, 22);
    expect(vBack.single.readings[1].at, DateTime(2026, 12, 1, 20));
  });

  test('un capteur sans relevé n\'a pas de dernier relevé', () {
    expect(parseExchange('{"version":1,"sensors":[{"name":"Vide"}]}').single.last, isNull);
  });
}
