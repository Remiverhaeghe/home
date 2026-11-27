import 'package:home/logic/house.dart';
import 'package:home/logic/reading.dart';
import 'package:home/net/weather_link.dart';

/// Service météo de test : des relevés à volonté, le nombre d'appels et une panne à volonté.
class FakeWeatherLink implements WeatherLink {
  FakeWeatherLink([List<Reading>? readings]) : readings = readings ?? [];

  List<Reading> readings;
  var fail = false;
  var calls = 0;
  int? lastPastDays;

  @override
  Future<List<Reading>> fetch(HouseLocation pLocation, {int pPastDays = 7}) async {
    calls++;
    lastPastDays = pPastDays;
    if (fail) {
      throw const WeatherException('injoignable');
    }

    return readings;
  }
}
