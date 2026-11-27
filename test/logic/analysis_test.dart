import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/analysis.dart';
import 'package:home/logic/reading.dart';

final _start = DateTime(2026, 11, 1);

/// Relevés toutes les [pMinutes] minutes, avec les valeurs données par [pValue].
List<Reading> _series(int pCount, int pMinutes, (double, double) Function(int) pValue) => [
  for (var vIndex = 0; vIndex < pCount; vIndex++)
    Reading(
      at: _start.add(Duration(minutes: pMinutes * vIndex)),
      temp: pValue(vIndex).$1,
      humidity: pValue(vIndex).$2,
    ),
];

void main() {
  test('l\'humidité absolue de 20 °C et 50 % est d\'environ 8,6 g/m³', () {
    expect(absoluteHumidity(20, 50), closeTo(8.6, 0.1));
    expect(absoluteHumidity(20, 0), 0);
  });

  test('le confort compte le temps passé dans la plage', () {
    final vSeries = _series(5, 60, (pIndex) => pIndex < 2 ? (21, 50) : (15, 50));

    final vShare = comfortHours(vSeries);

    expect(vShare.totalHours, 4);
    expect(vShare.comfortHours, 2);
    expect(vShare.share, 0.5);
  });

  test('sans relevé, il n\'y a pas de confort', () {
    expect(comfortHours(const []).share, 0);
  });

  test('un trou de plusieurs jours ne compte que deux heures', () {
    final vReadings = [
      Reading(at: _start, temp: 21, humidity: 50),
      Reading(at: _start.add(const Duration(days: 3)), temp: 21, humidity: 50),
    ];

    expect(comfortHours(vReadings).totalHours, 2);
  });

  test('le risque de moisissure suit la plus longue période humide', () {
    expect(moldRisk(_series(20, 60, (_) => (20, 50))).level, MoldLevel.low);
    expect(moldRisk(_series(14, 60, (_) => (20, 75))).level, MoldLevel.watch);
    final vHigh = moldRisk(_series(52, 60, (_) => (20, 80)));
    expect(vHigh.level, MoldLevel.high);
    expect(vHigh.longestHours, 51);
  });

  test('une période sèche coupe la série humide', () {
    final vSeries = _series(30, 60, (pIndex) => (20, pIndex == 10 ? 50 : 80));

    expect(moldRisk(vSeries).longestHours, lessThan(24));
  });

  test('un capteur figé est repéré', () {
    final vStuck = _series(20, 30, (_) => (19.5, 55));

    final vFound = findAnomalies(vStuck);

    expect(vFound.single.kind, AnomalyKind.stuck);
    expect(findAnomalies(_series(20, 30, (pIndex) => (19.0 + pIndex * 0.1, 55))), isEmpty);
  });

  test('un saut de valeur est repéré, pas une variation lente', () {
    final vJump = _series(6, 10, (pIndex) => pIndex < 3 ? (20, 50) : (35, 50));
    final vSlow = _series(6, 10, (pIndex) => (20.0 + pIndex, 50));

    expect(findAnomalies(vJump).single.kind, AnomalyKind.jump);
    expect(findAnomalies(vSlow), isEmpty);
  });

  test('un saut d\'humidité aussi, mais pas après une longue pause', () {
    final vJump = _series(4, 10, (pIndex) => (20, pIndex < 2 ? 40 : 75));
    final vPause = [
      Reading(at: _start, temp: 20, humidity: 40),
      Reading(at: _start.add(const Duration(hours: 5)), temp: 20, humidity: 80),
    ];

    expect(findAnomalies(vJump), hasLength(1));
    expect(findAnomalies(vPause), isEmpty);
  });
}
