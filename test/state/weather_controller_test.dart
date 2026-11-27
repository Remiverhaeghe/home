import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/house.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/weather_controller.dart';
import 'package:home/storage/weather_store.dart';

import '../support/fake_weather.dart';

const _lyon = HouseLocation(label: 'Lyon', latitude: 45.76, longitude: 4.83);

Reading _at(DateTime pAt) => Reading(at: pAt, temp: 5, humidity: 80);

void main() {
  late FakeWeatherLink vLink;
  late MemoryWeatherStore vStore;
  late DateTime vNow;
  late WeatherController vController;

  setUp(() {
    vNow = DateTime(2026, 11, 27, 12);
    vLink = FakeWeatherLink([_at(DateTime(2026, 11, 27, 11))]);
    vStore = MemoryWeatherStore();
    vController = WeatherController(vStore, vLink, clock: () => vNow);
  });

  test('par défaut, rien ne part sur Internet', () async {
    await vController.load();

    expect(vController.enabled, isFalse);
    expect(await vController.refresh(_lyon), WeatherResult.disabled);
    expect(vLink.calls, 0);
  });

  test('sans lieu, rien ne part non plus', () async {
    await vController.setEnabled(pEnabled: true);

    expect(await vController.refresh(null), WeatherResult.noLocation);
    expect(vLink.calls, 0);
  });

  test('l\'autorisation est rangée puis relue', () async {
    await vController.setEnabled(pEnabled: true);
    final vAgain = WeatherController(vStore, vLink);
    await vAgain.load();

    expect(vAgain.enabled, isTrue);
  });

  test('la récupération garde les relevés et demande un mois la première fois', () async {
    await vController.setEnabled(pEnabled: true);

    expect(await vController.refresh(_lyon), WeatherResult.done);

    expect(vLink.lastPastDays, 30);
    expect(vController.readings, hasLength(1));
    expect(vStore.readings, hasLength(1));
    expect(vController.csv, contains('temperature_c'));
  });

  test('au plus une récupération par heure, sauf si on force', () async {
    await vController.setEnabled(pEnabled: true);
    await vController.refresh(_lyon);

    vNow = vNow.add(const Duration(minutes: 30));
    await vController.refresh(_lyon);
    expect(vLink.calls, 1);

    await vController.refresh(_lyon, pForce: true);
    expect(vLink.calls, 2);

    vNow = vNow.add(const Duration(hours: 2));
    await vController.refresh(_lyon);
    expect(vLink.calls, 3);
  });

  test('ensuite, seul le temps manquant est demandé', () async {
    vStore.readings = [_at(DateTime(2026, 11, 20, 12))];
    await vController.load();
    await vController.setEnabled(pEnabled: true);

    await vController.refresh(_lyon);

    expect(vLink.lastPastDays, 9);
  });

  test('un service muet est signalé sans perdre l\'archive', () async {
    vStore.readings = [_at(DateTime(2026, 11, 27, 9))];
    await vController.load();
    await vController.setEnabled(pEnabled: true);
    vLink.fail = true;

    expect(await vController.refresh(_lyon), WeatherResult.failed);
    expect(vController.readings, hasLength(1));
  });
}
