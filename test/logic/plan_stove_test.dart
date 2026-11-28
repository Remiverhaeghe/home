import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/daikin.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/reading.dart';

final _now = DateTime(2026, 12, 7, 14);
const _host = '192.168.1.20';
const _unit = AcUnit(name: 'Salon', host: _host, sensorName: 'TP357 (1A2B)');

DaikinControl _control({required bool pPower, String pMode = '4'}) => DaikinControl(
  power: pPower,
  modeCode: pMode,
  setpoint: '20.0',
  humidity: '0',
  fanRate: 'A',
  fanDirection: '0',
);

PlanResult _plan(double pTemp, DaikinControl pControl, {required bool pStove}) => evaluatePlan(
  pRooms: const [Room(acHost: _host, targets: RoomTargets(eco: 20, comfort: 20, night: 20))],
  pRules: const [],
  pVacation: null,
  pUnits: const [_unit],
  pSensors: [
    Sensor(
      name: 'TP357 (1A2B)',
      readings: [Reading(at: _now, temp: pTemp, humidity: 50)],
    ),
  ],
  pControls: {_host: pControl},
  pNow: _now,
  pStoveRunning: pStove,
);

void main() {
  test('poêle éteint : la clim chauffe comme avant', () {
    final vResult = _plan(18, _control(pPower: false), pStove: false);

    expect(vResult.commands.single.reason, PlanReason.comfort);
    expect(vResult.commands.single.control.power, isTrue);
  });

  test('poêle allumé et pièce à 18 °C : la clim ne démarre pas', () {
    final vResult = _plan(18, _control(pPower: false), pStove: true);

    expect(vResult.commands, isEmpty);
  });

  test('poêle allumé et clim qui chauffait : elle s\'arrête', () {
    final vResult = _plan(18, _control(pPower: true), pStove: true);

    expect(vResult.commands.single.reason, PlanReason.stove);
    expect(vResult.commands.single.control.power, isFalse);
  });

  test('poêle allumé mais il fait très froid : les deux chauffent', () {
    final vResult = _plan(14, _control(pPower: false), pStove: true);

    expect(vResult.commands.single.reason, PlanReason.comfort);
    expect(vResult.commands.single.control.power, isTrue);
  });

  test('poêle allumé et clim qui chauffe dans la pièce très froide : rien ne change', () {
    final vResult = _plan(14, _control(pPower: true), pStove: true);

    expect(vResult.commands, isEmpty);
  });

  test('poêle allumé : la clim qui refroidit n\'est pas touchée', () {
    final vResult = _plan(26, _control(pPower: false, pMode: '3'), pStove: true);

    expect(vResult.commands.single.control.mode, DaikinMode.cool);
  });

  test('le seuil de froid se règle', () {
    final vResult = evaluatePlan(
      pRooms: const [Room(acHost: _host, targets: RoomTargets(eco: 20, comfort: 20, night: 20))],
      pRules: const [],
      pVacation: null,
      pUnits: const [_unit],
      pSensors: [
        Sensor(
          name: 'TP357 (1A2B)',
          readings: [Reading(at: _now, temp: 18, humidity: 50)],
        ),
      ],
      pControls: {_host: _control(pPower: false)},
      pNow: _now,
      pStoveRunning: true,
      pStoveColdBelow: 19,
    );

    expect(vResult.commands.single.reason, PlanReason.comfort);
  });
}
