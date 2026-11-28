import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/compare.dart';
import 'package:home/logic/reading.dart';

List<Reading> _days(List<int> pDays, double pTemp, double pHumidity) => [
  for (final vDay in pDays)
    Reading(at: DateTime(2026, 11, vDay, 12), temp: pTemp, humidity: pHumidity),
];

void main() {
  test('seuls les jours communs sont gardés', () {
    final vPairs = alignedDays(_days([1, 2, 3], 20, 50), _days([2, 3, 4], 18, 60));

    expect(vPairs.map((pPair) => pPair.day.day), [2, 3]);
    expect(vPairs.first.tempA, 20);
    expect(vPairs.first.tempB, 18);
    expect(vPairs.first.humidityB, 60);
  });

  test('l\'écart moyen est le premier moins le second', () {
    final vGap = meanGap(alignedDays(_days([1, 2], 20, 50), _days([1, 2], 18, 60)))!;

    expect(vGap.temp, 2);
    expect(vGap.humidity, -10);
  });

  test('sans jour commun, il n\'y a ni paire ni écart', () {
    final vPairs = alignedDays(_days([1], 20, 50), _days([5], 18, 60));

    expect(vPairs, isEmpty);
    expect(meanGap(vPairs), isNull);
  });
}
