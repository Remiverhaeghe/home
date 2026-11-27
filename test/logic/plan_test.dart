import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/automations.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/daikin.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/vacation.dart';

// 2026-12-07 est un lundi
final _now = DateTime(2026, 12, 7, 14);
const _host = '192.168.1.20';
const _unit = AcUnit(name: 'Salon', host: _host, sensorName: 'TP357 (1A2B)');
const _room = Room(acHost: _host);

DaikinControl _control({bool pPower = false, String pMode = '3', String pSetpoint = '22.0'}) =>
    DaikinControl(
      power: pPower,
      modeCode: pMode,
      setpoint: pSetpoint,
      humidity: '0',
      fanRate: 'A',
      fanDirection: '0',
    );

Sensor _sensor(double pTemp, {double pHumidity = 50, Duration pAge = Duration.zero}) => Sensor(
  name: 'TP357 (1A2B)',
  readings: [Reading(at: _now.subtract(pAge), temp: pTemp, humidity: pHumidity)],
);

/// Capteur dont la température a baissé de [pFrom] à [pTo] sur les [pMinutes] dernières minutes.
Sensor _falling(double pFrom, double pTo, {int pMinutes = 8}) => Sensor(
  name: 'TP357 (1A2B)',
  readings: [
    Reading(at: _now.subtract(Duration(minutes: pMinutes)), temp: pFrom, humidity: 50),
    Reading(at: _now, temp: pTo, humidity: 50),
  ],
);

PlanResult _plan({
  Sensor? pSensor,
  DaikinControl? pControl,
  List<Room> pRooms = const [_room],
  List<AutoRule> pRules = const [],
  VacationMode? pVacation,
  List<AcUnit> pUnits = const [_unit],
  Map<String, double> pOutdoors = const {},
  Map<String, DateTime> pLastRuns = const {},
  Map<String, DateTime> pWindowSince = const {},
}) => evaluatePlan(
  pRooms: pRooms,
  pRules: pRules,
  pVacation: pVacation,
  pUnits: pUnits,
  pSensors: [pSensor ?? _sensor(21)],
  pControls: {_host: pControl ?? _control()},
  pNow: _now,
  pOutdoors: pOutdoors,
  pLastRuns: pLastRuns,
  pWindowSince: pWindowSince,
);

void main() {
  group('fenêtre ouverte', () {
    test('une chute de 1,5 °C en moins de 10 minutes est détectée', () {
      expect(windowOpened(_falling(22, 20.5), _now), isTrue);
      expect(windowOpened(_falling(22, 20.6), _now), isFalse);
    });

    test('une chute plus ancienne que 10 minutes ne compte pas', () {
      expect(windowOpened(_falling(22, 19, pMinutes: 11), _now), isFalse);
    });

    test('un capteur sans relevé, ou avec un seul relevé récent, ne détecte rien', () {
      expect(windowOpened(const Sensor(name: 'A'), _now), isFalse);
      expect(windowOpened(_sensor(15), _now), isFalse);
    });

    test('un dernier relevé daté du futur ne détecte rien', () {
      final vFuture = Sensor(
        name: 'A',
        readings: [
          Reading(at: _now.subtract(const Duration(minutes: 5)), temp: 22, humidity: 50),
          Reading(at: _now.add(const Duration(minutes: 5)), temp: 18, humidity: 50),
        ],
      );

      expect(windowOpened(vFuture, _now), isFalse);
    });

    test('la clim allumée est coupée et la fenêtre est signalée', () {
      final vResult = _plan(pSensor: _falling(22, 19), pControl: _control(pPower: true));

      expect(vResult.windowHosts, {_host});
      expect(vResult.commands.single.reason, PlanReason.windowOpen);
      expect(vResult.commands.single.control.power, isFalse);
    });

    test('une clim déjà éteinte n\'a rien à recevoir mais la fenêtre est signalée', () {
      final vResult = _plan(pSensor: _falling(22, 19));

      expect(vResult.windowHosts, {_host});
      expect(vResult.commands, isEmpty);
    });

    test('pendant le repos de la clim, la température souhaitée est suspendue', () {
      final vSince = {_host: _now.subtract(const Duration(minutes: 29))};

      final vResult = _plan(pSensor: _sensor(15), pWindowSince: vSince);

      expect(vResult.commands, isEmpty);
      expect(vResult.windowHosts, isEmpty);
    });

    test('le repos fini, la température souhaitée reprend', () {
      final vSince = {_host: _now.subtract(const Duration(minutes: 30))};

      final vResult = _plan(pSensor: _sensor(15), pWindowSince: vSince);

      expect(vResult.commands.single.reason, PlanReason.comfort);
    });
  });

  group('température souhaitée', () {
    test('une pièce trop froide fait chauffer sa clim', () {
      final vResult = _plan(pSensor: _sensor(15), pRooms: const [
        Room(acHost: _host, targets: RoomTargets(eco: 20)),
      ]);

      final vCommand = vResult.commands.single;
      expect(vCommand.reason, PlanReason.comfort);
      expect(vCommand.host, _host);
      expect(vCommand.control.mode, DaikinMode.heat);
      expect(vCommand.control.setpointDegrees, 20);
    });

    test('le planning choisit le profil et donc la température', () {
      const vRoom = Room(
        acHost: _host,
        targets: RoomTargets(comfort: 25, eco: 18),
        schedule: [
          ScheduleSlot(weekdays: {1, 2, 3, 4, 5, 6, 7}, minute: 0, profile: ProfileKind.comfort),
        ],
      );

      final vResult = _plan(pRooms: const [vRoom], pOutdoors: {_host: 10});

      expect(vResult.commands.single.control.setpointDegrees, 25);
      expect(_plan(pOutdoors: {_host: 10}).commands, isEmpty);
    });

    test('la température dehors écarte le chauffage l\'été', () {
      expect(_plan(pSensor: _sensor(15), pOutdoors: {_host: 25}).commands, isEmpty);
    });

    test('le délai entre deux commandes est respecté', () {
      final vRecent = {'$_host|comfort': _now.subtract(const Duration(minutes: 9))};
      final vOld = {'$_host|comfort': _now.subtract(const Duration(minutes: 10))};

      expect(_plan(pSensor: _sensor(15), pLastRuns: vRecent).commands, isEmpty);
      expect(_plan(pSensor: _sensor(15), pLastRuns: vOld).commands, hasLength(1));
    });

    test('une clim sans pièce n\'est pas pilotée par une température souhaitée', () {
      expect(_plan(pSensor: _sensor(15), pRooms: const []).commands, isEmpty);
    });
  });

  group('capteur et clim inutilisables', () {
    test('sans capteur relié, sans état connu ou sans relevé : rien', () {
      final vNoLink = [const AcUnit(name: 'Salon', host: _host)];
      final vNoState = evaluatePlan(
        pRooms: const [_room],
        pRules: const [],
        pVacation: null,
        pUnits: const [_unit],
        pSensors: [_sensor(15)],
        pControls: const {},
        pNow: _now,
      );
      final vNoReading = evaluatePlan(
        pRooms: const [_room],
        pRules: const [],
        pVacation: null,
        pUnits: const [_unit],
        pSensors: const [Sensor(name: 'TP357 (1A2B)')],
        pControls: {_host: _control()},
        pNow: _now,
      );

      expect(_plan(pSensor: _sensor(15), pUnits: vNoLink).commands, isEmpty);
      expect(vNoState.commands, isEmpty);
      expect(vNoReading.commands, isEmpty);
    });

    test('un relevé trop vieux ou daté du futur ne décide rien', () {
      final vOld = _sensor(15, pAge: const Duration(minutes: 21));
      final vFuture = _sensor(15, pAge: const Duration(minutes: -5));

      expect(_plan(pSensor: vOld).commands, isEmpty);
      expect(_plan(pSensor: vFuture).commands, isEmpty);
    });
  });

  group('absence', () {
    final vAway = VacationMode(from: DateTime(2026, 12, 1), until: DateTime(2026, 12, 20));

    test('en vacances, la maison est tenue hors gel', () {
      final vResult = _plan(pSensor: _sensor(6), pVacation: vAway);

      expect(vResult.commands.single.reason, PlanReason.vacation);
      expect(vResult.commands.single.control.setpointDegrees, defaultFrostSetpoint);
    });

    test('en vacances, la température souhaitée et les règles de confort sont suspendues', () {
      const vRule = AutoRule(
        name: 'Humidité',
        acHost: _host,
        metric: AutoMetric.humidity,
        side: AutoSide.above,
        threshold: 60,
        action: AutoActionKind.powerOff,
      );

      final vResult = _plan(
        pSensor: _sensor(15, pHumidity: 80),
        pVacation: vAway,
        pRules: const [vRule],
        pControl: _control(),
      );

      expect(vResult.commands, isEmpty);
    });

    test('le délai entre deux commandes hors gel est de 30 minutes', () {
      final vRecent = {'$_host|vacation': _now.subtract(const Duration(minutes: 29))};
      final vOld = {'$_host|vacation': _now.subtract(const Duration(minutes: 30))};

      expect(_plan(pSensor: _sensor(6), pVacation: vAway, pLastRuns: vRecent).commands, isEmpty);
      expect(_plan(pSensor: _sensor(6), pVacation: vAway, pLastRuns: vOld).commands, hasLength(1));
    });

    test('la veille du retour, la maison remonte à la température de confort', () {
      final vReturning = VacationMode(
        from: DateTime(2026, 12, 1),
        until: _now.add(const Duration(hours: 12)),
      );

      final vResult = _plan(
        pSensor: _sensor(15),
        pVacation: vReturning,
        pRooms: const [Room(acHost: _host, targets: RoomTargets(comfort: 22))],
      );

      expect(vResult.commands.single.reason, PlanReason.comfort);
      expect(vResult.commands.single.control.setpointDegrees, 22);
    });

    test('hors période, les règles et la température souhaitée reprennent', () {
      final vOver = VacationMode(from: DateTime(2026, 11, 1), until: DateTime(2026, 11, 20));

      expect(_plan(pSensor: _sensor(15), pVacation: vOver).commands.single.reason,
          PlanReason.comfort);
    });
  });

  group('règles de seuil', () {
    const vRule = AutoRule(
      name: 'Humidité',
      acHost: _host,
      metric: AutoMetric.humidity,
      side: AutoSide.above,
      threshold: 60,
      action: AutoActionKind.powerOff,
    );

    test('une clim sans pièce reçoit la règle dépassée', () {
      final vResult = _plan(
        pSensor: _sensor(21, pHumidity: 80),
        pRooms: const [],
        pRules: const [vRule],
        pControl: _control(pPower: true),
      );

      final vCommand = vResult.commands.single;
      expect(vCommand.reason, PlanReason.rule);
      expect(vCommand.control.power, isFalse);
      expect(vCommand.lastRunKey, '$_host|Humidité');
    });

    test('une clim déjà commandée par la température souhaitée ignore les règles', () {
      final vResult = _plan(
        pSensor: _sensor(15, pHumidity: 80),
        pRules: const [vRule],
        pControl: _control(pPower: true),
      );

      expect(vResult.commands.single.reason, PlanReason.comfort);
    });
  });

  group('commande', () {
    test('la clé du délai est celle de la clim et du motif, sauf règle', () {
      final vCommand = PlanCommand(host: _host, control: _control(), reason: PlanReason.comfort);

      expect(vCommand.lastRunKey, '$_host|comfort');
    });
  });
}
