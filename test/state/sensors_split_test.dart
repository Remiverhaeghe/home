import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/sensor_store.dart';

Reading _at(DateTime pAt, double pTemp) => Reading(at: pAt, temp: pTemp, humidity: 50);

void main() {
  late MemorySensorStore vStore;
  late SensorsController vController;

  setUp(() async {
    vStore = MemorySensorStore([
      Sensor(
        name: 'Chambre',
        readings: [
          _at(DateTime(2025, 1, 19), 10),
          _at(DateTime(2025, 1, 20), 12),
          _at(DateTime(2025, 6, 11), 24),
        ],
      ),
    ]);
    vController = SensorsController(vStore);
    await vController.load();
  });

  test('une période devient un capteur à part', () async {
    final vDone = await vController.splitPeriod(
      'Chambre',
      DateTime(2025, 1, 19),
      DateTime(2025, 1, 20),
      ' Bureau en hiver ',
    );

    expect(vDone, isTrue);
    expect(vStore.saved.map((pSensor) => pSensor.name), ['Chambre', 'Bureau en hiver']);
    expect(vStore.saved.first.readings, hasLength(1));
    expect(vStore.saved.last.readings, hasLength(2));
  });

  test('un nom vide ou identique, un capteur inconnu sont refusés', () async {
    final vFrom = DateTime(2025, 1, 19);
    final vTo = DateTime(2025, 1, 20);

    expect(await vController.splitPeriod('Chambre', vFrom, vTo, '  '), isFalse);
    expect(await vController.splitPeriod('Chambre', vFrom, vTo, 'chambre'), isFalse);
    expect(await vController.splitPeriod('Cave', vFrom, vTo, 'Autre'), isFalse);
    expect(vStore.saved, hasLength(1));
  });

  test('une période vide ou qui est tout le capteur est refusée', () async {
    expect(
      await vController.splitPeriod('Chambre', DateTime(2024), DateTime(2024, 2), 'Autre'),
      isFalse,
    );
    expect(
      await vController.splitPeriod('Chambre', DateTime(2025), DateTime(2025, 12), 'Autre'),
      isFalse,
    );
    expect(vStore.saved.single.readings, hasLength(3));
  });

  test('la période peut rejoindre un capteur déjà existant', () async {
    await vController.importReadings('Bureau', [_at(DateTime(2025, 3, 1), 8)]);

    await vController.splitPeriod('Chambre', DateTime(2025, 1, 19), DateTime(2025, 1, 20), 'bureau');

    expect(vController.sensors.firstWhere((pSensor) => pSensor.name == 'Bureau').readings, hasLength(3));
  });
}
