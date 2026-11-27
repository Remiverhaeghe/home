import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/climate_exchange.dart';
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
}
