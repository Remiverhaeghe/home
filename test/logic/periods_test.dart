import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/periods.dart';
import 'package:home/logic/reading.dart';

Reading _at(DateTime pAt, double pTemp) => Reading(at: pAt, temp: pTemp, humidity: 50);

void main() {
  final vReadings = [
    _at(DateTime(2025, 1, 19), 10),
    _at(DateTime(2025, 1, 20), 12),
    _at(DateTime(2025, 2, 17), 20),
    _at(DateTime(2025, 2, 18), 22),
    _at(DateTime(2025, 6, 11), 30),
  ];

  test('un trou de deux jours ou plus ouvre une nouvelle période', () {
    final vPeriods = findPeriods(vReadings);

    expect(vPeriods, hasLength(3));
    expect(vPeriods.first.count, 2);
    expect(vPeriods.first.avgTemp, 11);
    expect(vPeriods.first.from, DateTime(2025, 1, 19));
    expect(vPeriods.first.to, DateTime(2025, 1, 20));
    expect(vPeriods.last.count, 1);
    expect(vPeriods.last.avgHumidity, 50);
  });

  test('sans trou ou sans relevé : une période ou aucune', () {
    expect(findPeriods([_at(DateTime(2025, 1, 1), 1), _at(DateTime(2025, 1, 2), 1)]), hasLength(1));
    expect(findPeriods(const []), isEmpty);
  });

  test('séparer une période garde les autres relevés', () {
    final vSplit = separatePeriod(vReadings, DateTime(2025, 2, 17), DateTime(2025, 2, 18));

    expect(vSplit.moved.map((pReading) => pReading.temp), [20, 22]);
    expect(vSplit.kept.map((pReading) => pReading.temp), [10, 12, 30]);
  });
}
