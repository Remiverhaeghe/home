import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/climate_stats.dart';

import '../support/sensors.dart';

void main() {
  test('le niveau d\'humidité change à 40 % et à 60 %', () {
    expect(humidityLevel(39.9), HumidityLevel.dry);
    expect(humidityLevel(40), HumidityLevel.good);
    expect(humidityLevel(60), HumidityLevel.good);
    expect(humidityLevel(60.1), HumidityLevel.humid);
  });

  test('point de rosée connu : 20 °C et 50 % donnent environ 9,3 °C', () {
    expect(dewPoint(20, 50), closeTo(9.3, 0.1));
  });

  test('à 100 % d\'humidité, le point de rosée est la température', () {
    expect(dewPoint(18, 100), closeTo(18, 0.01));
  });

  test('moyennes par jour, dans l\'ordre', () {
    final vDays = dailyAverages(bathroomSensor().readings);

    expect(vDays, hasLength(2));
    expect(vDays[0].day, DateTime(2026, 12, 1));
    expect(vDays[0].temp, 21);
    expect(vDays[0].humidity, 60);
    expect(vDays[1].day, DateTime(2026, 12, 2));
    expect(vDays[1].temp, 19);
  });

  test('sans relevé, aucune moyenne', () {
    expect(dailyAverages([]), isEmpty);
  });
}
