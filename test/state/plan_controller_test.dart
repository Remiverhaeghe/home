import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/alerts.dart';
import 'package:home/logic/automations.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/daikin.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/vacation.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/plan_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/plan_store.dart';
import 'package:home/storage/sensor_store.dart';

import '../support/fake_daikin.dart';

void main() {
  const vHost = '192.168.1.20';
  final vNow = DateTime(2026, 12, 1, 12);
  late FakeDaikinLink vLink;
  late MemoryPlanStore vStore;
  late SensorsController vSensors;
  late AcController vAc;
  late PlanController vPlan;

  Sensor salon(double pTemp, {Duration pAge = const Duration(minutes: 5), double pHum = 50}) =>
      Sensor(
        name: 'Salon',
        readings: [Reading(at: vNow.subtract(pAge), temp: pTemp, humidity: pHum)],
      );

  Future<void> start(Sensor pSensor) async {
    vLink = FakeDaikinLink()
      ..names[vHost] = 'Salon'
      ..states[vHost] = FakeDaikinLink.coolingAt22();
    vAc = AcController(
      MemoryAcStore([const AcUnit(name: 'Salon', host: vHost, sensorName: 'Salon')]),
      vLink,
    );
    vSensors = SensorsController(MemorySensorStore([pSensor]));
    vStore = MemoryPlanStore();
    vPlan = PlanController(vStore, vAc, vSensors);
    await vAc.load();
    await vSensors.load();
    await vPlan.load();
    await vAc.refresh();
  }

  group('réglages', () {
    setUp(() => start(salon(15)));

    test('une pièce remplace celle de la même clim et reste enregistrée', () async {
      await vPlan.setRoom(const Room(acHost: vHost));
      await vPlan.setRoom(const Room(acHost: vHost, targets: RoomTargets(comfort: 23)));

      expect(vPlan.rooms, hasLength(1));
      expect(vPlan.roomOf(vHost)?.targets.comfort, 23);
      expect(vPlan.roomOf('autre'), isNull);
      expect(vStore.saved.rooms.single.targets.comfort, 23);
    });

    test('le planning change sans toucher aux températures souhaitées', () async {
      await vPlan.setRoom(const Room(acHost: vHost, targets: RoomTargets(comfort: 23)));

      await vPlan.setSchedule(vHost, const [
        ScheduleSlot(weekdays: {6, 7}, minute: 600, profile: ProfileKind.eco),
      ]);

      expect(vPlan.roomOf(vHost)?.targets.comfort, 23);
      expect(vStore.saved.rooms.single.schedule.single.minute, 600);
    });

    test('un planning sur une pièce encore non réglée la crée', () async {
      await vPlan.setSchedule(vHost, const [
        ScheduleSlot(weekdays: {1}, minute: 420, profile: ProfileKind.comfort),
      ]);

      expect(vPlan.roomOf(vHost)?.targets.comfort, const RoomTargets().comfort);
      expect(vPlan.roomOf(vHost)?.schedule, hasLength(1));
    });

    test('les règles et les vacances s\'enregistrent et se retirent', () async {
      final vVacation = VacationMode(from: DateTime(2026, 12, 18), until: DateTime(2026, 12, 28));
      await vPlan.setRules(const [
        AutoRule(
          name: 'Humidité',
          acHost: vHost,
          metric: AutoMetric.humidity,
          side: AutoSide.above,
          threshold: 70,
          action: AutoActionKind.powerOff,
        ),
      ]);
      await vPlan.setVacation(vVacation);

      expect(vPlan.rules.single.name, 'Humidité');
      expect(vPlan.vacation?.until, vVacation.until);
      expect(vStore.saved.vacation, isNotNull);

      await vPlan.setVacation(null);

      expect(vPlan.vacation, isNull);
      expect(vStore.saved.rules, hasLength(1));
    });
  });

  group('passage du plan', () {
    test('une pièce trop froide met la clim en chauffage sur la température souhaitée', () async {
      await start(salon(15));
      await vPlan.setRoom(const Room(acHost: vHost, targets: RoomTargets(eco: 19)));

      await vPlan.tick(vNow);

      final vSent = vLink.written.single.$2;
      expect(vSent.mode, DaikinMode.heat);
      expect(vSent.setpoint, '19.0');
      expect(vPlan.applied.single.reason, PlanReason.comfort);
    });

    test('le délai entre deux commandes est respecté', () async {
      await start(salon(15));
      await vPlan.setRoom(const Room(acHost: vHost, targets: RoomTargets(eco: 19)));
      await vPlan.tick(vNow);
      vLink.states[vHost] = FakeDaikinLink.coolingAt22();
      await vAc.refresh();

      await vPlan.tick(vNow.add(const Duration(minutes: 2)));

      expect(vLink.written, hasLength(1));
      expect(vPlan.applied, isEmpty);
    });

    test('une commande refusée par la clim n\'est pas comptée', () async {
      await start(salon(15));
      await vPlan.setRoom(const Room(acHost: vHost, targets: RoomTargets(eco: 19)));
      vLink.refuseWrites = true;

      await vPlan.tick(vNow);

      expect(vPlan.applied, isEmpty);
    });

    test('une chute de température coupe la clim et la tient au repos', () async {
      await start(
        Sensor(
          name: 'Salon',
          readings: [
            Reading(at: vNow.subtract(const Duration(minutes: 8)), temp: 21, humidity: 50),
            Reading(at: vNow.subtract(const Duration(minutes: 1)), temp: 18, humidity: 50),
          ],
        ),
      );
      await vPlan.setRoom(const Room(acHost: vHost, targets: RoomTargets(eco: 25)));

      await vPlan.tick(vNow);

      expect(vPlan.applied.single.reason, PlanReason.windowOpen);
      expect(vLink.written.single.$2.power, isFalse);

      await vPlan.tick(vNow.add(const Duration(minutes: 1)));

      expect(vLink.written, hasLength(1));
    });

    test('sans pièce réglée, rien n\'est envoyé', () async {
      await start(salon(15));

      await vPlan.tick(vNow);

      expect(vLink.written, isEmpty);
    });
  });

  group('alertes', () {
    test(
      'une alerte n\'est signalée qu\'une fois tant qu\'elle dure, puis de nouveau après',
      () async {
        await start(salon(3));

        final vFirst = await vPlan.tick(vNow);
        final vSecond = await vPlan.tick(vNow);

        expect(vFirst.single.kind, AlertKind.frost);
        expect(vSecond, isEmpty);

        final vWarm = vNow.add(const Duration(hours: 1));
        await vSensors.addLiveReading('Salon', Reading(at: vWarm, temp: 19, humidity: 50));
        await vPlan.tick(vWarm);
        final vCold = vNow.add(const Duration(hours: 2));
        await vSensors.addLiveReading('Salon', Reading(at: vCold, temp: 2, humidity: 50));
        final vAgain = await vPlan.tick(vCold);

        expect(vAgain.single.kind, AlertKind.frost);
      },
    );
  });
}
