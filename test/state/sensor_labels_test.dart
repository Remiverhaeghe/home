import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/wall_tiles.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/label_store.dart';
import 'package:home/storage/sensor_store.dart';

void main() {
  late MemoryLabelStore vLabels;
  late SensorsController vController;

  setUp(() async {
    vLabels = MemoryLabelStore();
    vController = SensorsController(
      MemorySensorStore([const Sensor(name: 'TP357 (A1B2)')]),
      vLabels,
    );
    await vController.load();
  });

  test('sans nom donné, le capteur garde son identifiant', () {
    final vSensor = vController.sensors.single;

    expect(vSensor.title, 'TP357 (A1B2)');
    expect(vSensor.label, isNull);
  });

  test('le nom donné s\'affiche, l\'identifiant reste', () async {
    await vController.rename('TP357 (A1B2)', '  Chambre des enfants ');

    final vSensor = vController.sensors.single;
    expect(vSensor.title, 'Chambre des enfants');
    expect(vSensor.name, 'TP357 (A1B2)');
    expect(vLabels.saved, {'TP357 (A1B2)': 'Chambre des enfants'});
  });

  test('un nom vide ou identique à l\'identifiant retire le nom donné', () async {
    await vController.rename('TP357 (A1B2)', 'Salon');
    await vController.rename('TP357 (A1B2)', '  ');

    expect(vController.sensors.single.label, isNull);
    expect(vLabels.saved, isEmpty);

    await vController.rename('TP357 (A1B2)', 'TP357 (A1B2)');

    expect(vLabels.saved, isEmpty);
  });

  test('les noms sont relus au démarrage', () async {
    vLabels.saved = {'TP357 (A1B2)': 'Cave'};

    await vController.load();

    expect(vController.sensors.single.title, 'Cave');
  });

  test('l\'affichage mural montre le nom donné', () async {
    await vController.rename('TP357 (A1B2)', 'Bureau');

    final vTiles = buildWallTiles(
      pSensors: vController.sensors,
      pUnits: const [],
      pControls: const {},
      pNow: DateTime(2026, 11, 27, 12),
    );

    expect(vTiles.single.name, 'Bureau');
  });
}
