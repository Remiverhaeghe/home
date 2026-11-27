import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/daikin.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/wall_tiles.dart';

void main() {
  final vNow = DateTime(2026, 12, 1, 12);
  const vControl = DaikinControl(
    power: true,
    modeCode: '3',
    setpoint: '22.0',
    humidity: '0',
    fanRate: 'A',
    fanDirection: '0',
  );
  Sensor sensor(String pName, Duration pAge) => Sensor(
    name: pName,
    readings: [Reading(at: vNow.subtract(pAge), temp: 21, humidity: 50)],
  );

  test('une tuile par clim avec son capteur, puis les capteurs restés seuls', () {
    final vTiles = buildWallTiles(
      pSensors: [
        sensor('Salon', const Duration(minutes: 5)),
        sensor('Garage', const Duration(minutes: 5)),
      ],
      pUnits: const [AcUnit(name: 'Clim salon', host: '10.0.0.2', sensorName: 'Salon')],
      pControls: const {'10.0.0.2': vControl},
      pNow: vNow,
    );

    expect(vTiles.map((pTile) => pTile.name), ['Clim salon', 'Garage']);
    expect(vTiles.first.ac, WallAc.ready);
    expect(vTiles.first.reading?.temp, 21);
    expect(vTiles.first.host, '10.0.0.2');
    expect(vTiles.last.ac, WallAc.none);
    expect(vTiles.last.host, isNull);
  });

  test('une clim pas encore lue charge, une clim muette est injoignable', () {
    final vTiles = buildWallTiles(
      pSensors: const [],
      pUnits: const [
        AcUnit(name: 'A', host: '10.0.0.2'),
        AcUnit(name: 'B', host: '10.0.0.3'),
      ],
      pControls: const {'10.0.0.3': null},
      pNow: vNow,
    );

    expect(vTiles[0].ac, WallAc.loading);
    expect(vTiles[1].ac, WallAc.unreachable);
    expect(vTiles[1].control, isNull);
  });

  test('un relevé de plus de 30 minutes est signalé ancien', () {
    final vTiles = buildWallTiles(
      pSensors: [
        sensor('Récent', const Duration(minutes: 30)),
        sensor('Ancien', const Duration(minutes: 31)),
        const Sensor(name: 'Vide'),
      ],
      pUnits: const [],
      pControls: const {},
      pNow: vNow,
    );

    expect(vTiles.map((pTile) => pTile.stale), [false, true, false]);
    expect(vTiles.last.reading, isNull);
  });

  test('sans clim ni capteur, rien à afficher', () {
    expect(
      buildWallTiles(pSensors: const [], pUnits: const [], pControls: const {}, pNow: vNow),
      isEmpty,
    );
  });
}
