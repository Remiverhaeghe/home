import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/boost.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/daikin.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/reading.dart';

final _now = DateTime(2026, 12, 7, 14);
const _host = '192.168.1.30';
const _unit = AcUnit(name: 'Salle de bain', host: _host, sensorName: 'TP357 (1A2B)');

const _off = DaikinControl(
  power: false,
  modeCode: '4',
  setpoint: '20.0',
  humidity: '0',
  fanRate: 'A',
  fanDirection: '0',
);

PlanResult _plan(double pTemp, {Map<String, Boost> pBoosts = const {}, List<Room>? pRooms}) =>
    evaluatePlan(
      pRooms: pRooms ?? const [Room(acHost: _host, targets: RoomTargets(comfort: 20, eco: 20))],
      pRules: const [],
      pVacation: null,
      pUnits: const [_unit],
      pSensors: [
        Sensor(
          name: 'TP357 (1A2B)',
          readings: [Reading(at: _now, temp: pTemp, humidity: 50)],
        ),
      ],
      pControls: {_host: _off},
      pNow: _now,
      pBoosts: pBoosts,
    );

Boost _boost({Duration pLeft = const Duration(minutes: 30), double pTemp = 24}) => Boost(
  host: _host,
  kind: BoostKind.shower,
  temp: pTemp,
  until: _now.add(pLeft),
);

void main() {
  test('chaque usage a son réglage de départ', () {
    expect(defaultBoost(BoostKind.shower), (temp: 24.0, minutes: 45));
    expect(defaultBoost(BoostKind.bath), (temp: 25.0, minutes: 90));
    expect(defaultBoost(BoostKind.laundry), (temp: 22.0, minutes: 180));
  });

  test('seuls les coups de chaud en cours comptent, le plus récent par clim', () {
    final vOld = Boost(
      host: _host,
      kind: BoostKind.bath,
      temp: 25,
      until: _now.subtract(const Duration(minutes: 1)),
    );
    final vNew = _boost();

    expect(activeBoosts([vOld], _now), isEmpty);
    expect(activeBoosts([vOld, vNew], _now)[_host], vNew);
    expect(vNew.isActiveAt(_now.add(const Duration(minutes: 30))), isFalse);
  });

  test('les coups de chaud s\'écrivent et se relisent, les entrées abîmées sont ignorées', () {
    final vJson = boostsToJson([_boost()]);

    final vRead = parseBoosts(jsonDecode(vJson));

    expect(vRead.single.host, _host);
    expect(vRead.single.kind, BoostKind.shower);
    expect(vRead.single.temp, 24);
    expect(vRead.single.until, _now.add(const Duration(minutes: 30)));
    expect(parseBoosts('pas une liste'), isEmpty);
    expect(
      parseBoosts([
        'x',
        {'host': _host, 'kind': 'inconnu', 'temp': 24, 'until': _now.toIso8601String()},
        {'host': _host, 'kind': 'bath', 'temp': 'chaud', 'until': _now.toIso8601String()},
        {'host': '', 'kind': 'bath', 'temp': 24, 'until': _now.toIso8601String()},
        {'host': _host, 'kind': 'bath', 'temp': 24, 'until': 'jamais'},
      ]),
      isEmpty,
    );
  });

  group('dans le plan', () {
    test('sans coup de chaud, la température du planning est tenue', () {
      expect(_plan(20).commands, isEmpty);
    });

    test('un coup de chaud en cours fait chauffer jusqu\'à sa température', () {
      final vResult = _plan(20, pBoosts: {_host: _boost()});

      final vCommand = vResult.commands.single;
      expect(vCommand.control.mode, DaikinMode.heat);
      expect(vCommand.control.power, isTrue);
      expect(vCommand.control.setpoint, '24.0');
    });

    test('un coup de chaud fini ne change rien', () {
      final vOld = _boost(pLeft: const Duration(minutes: -1));

      expect(_plan(20, pBoosts: {_host: vOld}).commands, isEmpty);
    });

    test('une pièce sans réglage de planning chauffe aussi pour un coup de chaud', () {
      final vResult = _plan(20, pBoosts: {_host: _boost()}, pRooms: const []);

      expect(vResult.commands.single.control.setpoint, '24.0');
    });
  });
}
