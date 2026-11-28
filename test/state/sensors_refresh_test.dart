import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/sensor_store.dart';

import '../support/fake_link.dart';

void main() {
  test('rafraîchir lit une mesure sur chaque capteur à portée', () async {
    final vStore = MemorySensorStore();
    final vController = SensorsController(vStore);
    final vLink = FakeTp357Link();

    final vDone = vController.refreshFromBluetooth(
      vLink,
      pScan: const Duration(milliseconds: 50),
      pWait: const Duration(seconds: 2),
    );
    vLink.devices.add((id: '1', name: 'TP357 (A1B2)'));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    vLink.liveValues.add((temp: 19.5, humidity: 48));

    expect(await vDone, 1);
    expect(vStore.saved.single.name, 'TP357 (A1B2)');
    expect(vStore.saved.single.last!.temp, 19.5);
  });

  test('un capteur qui ne répond pas est passé', () async {
    final vController = SensorsController(MemorySensorStore());
    final vLink = FakeTp357Link();

    final vDone = vController.refreshFromBluetooth(
      vLink,
      pScan: const Duration(milliseconds: 20),
      pWait: const Duration(milliseconds: 60),
    );
    vLink.devices.add((id: '1', name: 'TP357 (A1B2)'));

    expect(await vDone, 0);
    expect(vController.sensors, isEmpty);
  });

  test('importReadings crée le capteur puis complète le même sans doublon', () async {
    final vStore = MemorySensorStore();
    final vController = SensorsController(vStore);
    final vFirst = Reading(at: DateTime(2025, 1, 19, 10, 30), temp: 15, humidity: 40);
    final vSecond = Reading(at: DateTime(2025, 1, 19, 10, 40), temp: 16, humidity: 41);

    expect(await vController.importReadings('Bureau', [vFirst]), 1);
    expect(await vController.importReadings('bureau', [vFirst, vSecond]), 2);

    expect(vStore.saved, hasLength(1));
    expect(vStore.saved.single.readings, hasLength(2));
  });

  test('refreshIfStale lance la première actualisation, puis attend le délai', () async {
    final vController = SensorsController(MemorySensorStore());
    final vLink = FakeTp357Link();
    final vStart = DateTime(2026, 11, 28, 12);

    expect(vController.lastRefresh, isNull);
    final vFirst = vController.refreshIfStale(
      vLink,
      vStart,
      pScan: const Duration(milliseconds: 20),
    );
    expect(vController.lastRefresh, vStart);
    // Personne à portée : la recherche se termine sans capteur
    expect(await vFirst, 0);

    expect(
      await vController.refreshIfStale(
        vLink,
        vStart.add(const Duration(minutes: 9)),
        pScan: const Duration(milliseconds: 20),
      ),
      isNull,
    );
    expect(vController.lastRefresh, vStart);

    final vAgain = vController.refreshIfStale(
      vLink,
      vStart.add(const Duration(minutes: 10)),
      pScan: const Duration(milliseconds: 20),
    );
    expect(vController.lastRefresh, vStart.add(const Duration(minutes: 10)));
    expect(await vAgain, 0);
  });
}
