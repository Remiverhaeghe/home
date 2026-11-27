import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/climate_exchange.dart';
import 'package:home/logic/pending_readings.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/sensor_store.dart';

import '../support/sensors.dart';

void main() {
  test('charge les capteurs enregistrés', () async {
    final vController = SensorsController(MemorySensorStore([bathroomSensor()]));

    await vController.load();

    expect(vController.sensors.single.name, 'Salle de bain');
  });

  test('un fichier valide est ajouté et enregistré', () async {
    final vStore = MemorySensorStore();
    final vController = SensorsController(vStore);
    var vNotified = 0;
    vController.addListener(() => vNotified++);

    final vCount = await vController.importText(exchangeSample);

    expect(vCount, 1);
    expect(vController.problem, isNull);
    expect(vStore.saved.single.name, 'Salle de bain');
    expect(vNotified, 1);
  });

  test('ré-importer le même fichier ne double rien', () async {
    final vController = SensorsController(MemorySensorStore());

    await vController.importText(exchangeSample);
    await vController.importText(exchangeSample);

    expect(vController.sensors, hasLength(1));
    expect(vController.sensors.single.readings, hasLength(1));
  });

  test('un fichier refusé garde le motif et ne change rien', () async {
    final vStore = MemorySensorStore([bathroomSensor()]);
    final vController = SensorsController(vStore);
    await vController.load();

    final vCount = await vController.importText('{"version": 9}');

    expect(vCount, isNull);
    expect(vController.problem, ExchangeProblem.wrongVersion);
    expect(vController.sensors, hasLength(1));
    expect(vStore.saved, hasLength(1));
  });

  test('un import réussi efface le motif du refus précédent', () async {
    final vController = SensorsController(MemorySensorStore());

    await vController.importText('pas du json');
    expect(vController.problem, ExchangeProblem.notJson);
    await vController.importText(exchangeSample);

    expect(vController.problem, isNull);
  });

  test('une mesure en direct est gardée, enregistrée et signalée', () async {
    final vStore = MemorySensorStore();
    final vController = SensorsController(vStore);
    var vNotified = 0;
    vController.addListener(() => vNotified++);

    await vController.addLiveReading(
      'TP357 (1A2B)',
      Reading(at: DateTime(2026, 12, 1, 8), temp: 21.5, humidity: 48),
    );

    expect(vController.sensors.single.last!.temp, 21.5);
    expect(vStore.saved.single.name, 'TP357 (1A2B)');
    expect(vNotified, 1);
  });

  test('une mesure trop proche de la précédente n\'écrit rien', () async {
    final vStore = MemorySensorStore();
    final vController = SensorsController(vStore);
    await vController.addLiveReading(
      'Cave',
      Reading(at: DateTime(2026, 12, 1, 8), temp: 12, humidity: 70),
    );
    var vNotified = 0;
    vController.addListener(() => vNotified++);

    await vController.addLiveReading(
      'Cave',
      Reading(at: DateTime(2026, 12, 1, 8, 0, 30), temp: 13, humidity: 71),
    );

    expect(vController.sensors.single.readings, hasLength(1));
    expect(vNotified, 0);
  });

  group('relevés pris en arrière-plan', () {
    PendingReading pending(String pSensor, DateTime pAt) => PendingReading(
      sensor: pSensor,
      reading: Reading(at: pAt, temp: 20, humidity: 55),
    );

    test('ils sont rangés, enregistrés et signalés', () async {
      final vStore = MemorySensorStore();
      final vController = SensorsController(vStore);
      var vNotified = 0;
      vController.addListener(() => vNotified++);

      await vController.syncPending(
        () async => [
          pending('TP357 (1A2B)', DateTime(2026, 12, 1, 8)),
          pending('TP357 (1A2B)', DateTime(2026, 12, 1, 8, 5)),
        ],
      );

      expect(vController.sensors.single.readings, hasLength(2));
      expect(vStore.saved.single.name, 'TP357 (1A2B)');
      expect(vNotified, 1);
    });

    test('sans relevé en attente, rien n\'est écrit ni signalé', () async {
      final vStore = MemorySensorStore();
      final vController = SensorsController(vStore);
      var vNotified = 0;
      vController.addListener(() => vNotified++);

      await vController.syncPending(() async => []);

      expect(vNotified, 0);
      expect(vStore.saved, isEmpty);
    });

    test('des relevés tous trop proches des précédents ne changent rien', () async {
      final vStore = MemorySensorStore();
      final vController = SensorsController(vStore);
      await vController.addLiveReading(
        'Cave',
        Reading(at: DateTime(2026, 12, 1, 8), temp: 12, humidity: 70),
      );
      var vNotified = 0;
      vController.addListener(() => vNotified++);

      await vController.syncPending(() async => [pending('Cave', DateTime(2026, 12, 1, 8, 0, 20))]);

      expect(vController.sensors.single.readings, hasLength(1));
      expect(vNotified, 0);
    });
  });
}
