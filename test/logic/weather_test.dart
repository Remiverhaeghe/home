import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/house.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/weather.dart';

const _reply = '''
{"hourly":{"time":["2026-11-27T00:00","2026-11-27T01:00","2026-11-27T02:00","2026-11-27T03:00"],
"temperature_2m":[4.5,4.1,null,3.0],"relative_humidity_2m":[90,91,92,93]}}
''';

void main() {
  test('la demande ne contient que le lieu et les relevés voulus', () {
    final vUri = weatherUri(const HouseLocation(label: 'Lyon', latitude: 45.76, longitude: 4.83));

    expect(vUri.scheme, 'https');
    expect(vUri.host, weatherHost);
    expect(vUri.queryParameters['latitude'], '45.7600');
    expect(vUri.queryParameters['longitude'], '4.8300');
    expect(vUri.queryParameters['past_days'], '7');
    expect(vUri.queryParameters.keys, contains('hourly'));
    expect(vUri.queryParameters.containsKey('label'), isFalse);
  });

  test('la réponse est lue, sans les heures à venir ni les valeurs manquantes', () {
    final vReadings = parseWeather(_reply, pNow: DateTime(2026, 11, 27, 2, 30));

    expect(vReadings, hasLength(2));
    expect(vReadings.first.temp, 4.5);
    expect(vReadings.last.humidity, 91);
  });

  test('une réponse inattendue donne une liste vide', () {
    final now = DateTime(2026, 12);

    expect(parseWeather('pas du json', pNow: now), isEmpty);
    expect(parseWeather('[]', pNow: now), isEmpty);
    expect(parseWeather('{"hourly":{"time":[]}}', pNow: now), isEmpty);
    expect(parseWeather('{"hourly":{"time":[1],"temperature_2m":[1],"relative_humidity_2m":[1]}}', pNow: now), isEmpty);
  });

  test('la fusion remplace une même heure et ne double rien', () {
    final vOld = [Reading(at: DateTime(2026, 11, 1, 10), temp: 5, humidity: 80)];
    final vNew = [
      Reading(at: DateTime(2026, 11, 1, 10), temp: 6, humidity: 70),
      Reading(at: DateTime(2026, 11, 1, 11), temp: 7, humidity: 60),
    ];

    final vMerged = mergeWeather(vOld, vNew);

    expect(vMerged, hasLength(2));
    expect(vMerged.first.temp, 6);
  });

  test('l\'archive oublie ce qui a plus de 400 jours', () {
    final vLast = DateTime(2026, 11, 27);
    final vMerged = mergeWeather([
      Reading(at: vLast.subtract(const Duration(days: 401)), temp: 1, humidity: 1),
    ], [
      Reading(at: vLast, temp: 2, humidity: 2),
    ]);

    expect(vMerged, hasLength(1));
    expect(mergeWeather(const [], const []), isEmpty);
  });

  test('le fichier garde l\'autorisation et l\'archive', () {
    final vJson = weatherJson(
      pEnabled: true,
      pReadings: [Reading(at: DateTime(2026, 11, 1, 10), temp: 5.5, humidity: 80)],
    );

    final vBack = parseWeatherFile(vJson);

    expect(vBack.enabled, isTrue);
    expect(vBack.readings.single.temp, 5.5);
    expect(parseWeatherFile('pas du json').enabled, isFalse);
    expect(parseWeatherFile('{"version":2,"enabled":true}').enabled, isFalse);
    expect(parseWeatherFile('{"version":1,"readings":[1,{"at":"x"}]}').readings, isEmpty);
  });

  test('le CSV a des virgules décimales et un point-virgule', () {
    final vCsv = weatherCsv([Reading(at: DateTime(2026, 11, 1, 10), temp: 5.55, humidity: 80)]);

    expect(vCsv, 'date;temperature_c;humidite_pct\n2026-11-01T10:00:00.000;5,6;80,0\n');
  });

  test('l\'écart et l\'amortissement se calculent sur les heures communes', () {
    List<Reading> day(double Function(int) pTemp) => [
      for (var vHour = 0; vHour < 24; vHour++)
        Reading(at: DateTime(2026, 11, 1, vHour), temp: pTemp(vHour), humidity: 50),
    ];
    final vOutdoor = day((pHour) => pHour < 12 ? 0 : 10);
    final vIndoor = day((pHour) => pHour < 12 ? 18 : 20);

    final vCompare = compareWithOutdoor(vIndoor, vOutdoor)!;

    expect(vCompare.hours, 24);
    expect(vCompare.meanDelta, closeTo(14, 0.01));
    expect(vCompare.indoorAmplitude, 2);
    expect(vCompare.outdoorAmplitude, 10);
    expect(vCompare.damping, closeTo(0.2, 0.001));
  });

  test('trop peu d\'heures communes ne donnent pas de comparaison', () {
    final vIndoor = [Reading(at: DateTime(2026, 11, 1, 10), temp: 20, humidity: 50)];

    expect(compareWithOutdoor(vIndoor, vIndoor), isNull);
    expect(compareWithOutdoor(vIndoor, const []), isNull);
  });

  test('un dehors qui ne varie pas ne donne pas d\'amortissement', () {
    final vFlat = [
      for (var vHour = 0; vHour < 8; vHour++)
        Reading(at: DateTime(2026, 11, 1, vHour), temp: 5, humidity: 50),
    ];

    expect(compareWithOutdoor(vFlat, vFlat)!.damping, isNull);
  });
}
