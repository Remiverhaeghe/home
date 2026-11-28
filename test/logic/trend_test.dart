import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/trend.dart';

void main() {
  final vNoon = DateTime(2026, 11, 28, 12);
  Reading at(Duration pAgo, double pTemp) =>
      Reading(at: vNoon.subtract(pAgo), temp: pTemp, humidity: 50);

  test('sans relevé, aucune tendance', () {
    expect(recentTemps(const []), isEmpty);
  });

  test('seules les 24 dernières heures comptent', () {
    final vTemps = recentTemps([
      at(const Duration(hours: 30), 10),
      at(const Duration(hours: 23), 18),
      at(const Duration(hours: 1), 20),
      at(Duration.zero, 21),
    ]);

    expect(vTemps, [18, 20, 21]);
  });

  test('beaucoup de relevés sont ramenés à une quarantaine de points par moyennes', () {
    final vReadings = [
      for (var vIndex = 0; vIndex < 288; vIndex++) at(Duration(minutes: 5 * (287 - vIndex)), 20),
    ];
    final vTemps = recentTemps(vReadings);

    expect(vTemps, hasLength(48));
    expect(vTemps.every((pTemp) => pTemp == 20), isTrue);
  });

  test('les moyennes de paquets suivent la montée', () {
    final vReadings = [
      for (var vIndex = 0; vIndex < 100; vIndex++)
        at(Duration(minutes: 10 * (99 - vIndex)), vIndex.toDouble()),
    ];
    final vTemps = recentTemps(vReadings, pMaxPoints: 4);

    expect(vTemps, hasLength(4));
    expect(vTemps, orderedEquals([...vTemps]..sort()));
  });
}
