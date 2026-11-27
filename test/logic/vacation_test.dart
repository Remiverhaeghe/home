import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/automations.dart';
import 'package:home/logic/daikin.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/vacation.dart';

final _now = DateTime(2026, 12, 20, 10);
final _vacation = VacationMode(from: DateTime(2026, 12, 18), until: DateTime(2026, 12, 28));

const _unit = AcUnit(name: 'Salon', host: '192.168.1.20', sensorName: 'TP357 (1A2B)');

DaikinControl _control({bool pPower = false, String pMode = '4', String pSetpoint = '20.0'}) =>
    DaikinControl(
      power: pPower,
      modeCode: pMode,
      setpoint: pSetpoint,
      humidity: '0',
      fanRate: 'A',
      fanDirection: '0',
    );

Sensor _sensor(double pTemp, {Duration pAge = Duration.zero, double pHumidity = 50}) => Sensor(
  name: 'TP357 (1A2B)',
  readings: [Reading(at: _now.subtract(pAge), temp: pTemp, humidity: pHumidity)],
);

List<AutoDecision> _vacationDecisions(
  Sensor pSensor,
  DaikinControl pControl, {
  List<AcUnit> pUnits = const [_unit],
  Map<String, DateTime> pLastRuns = const {},
}) => evaluateVacation(
  pVacation: _vacation,
  pUnits: pUnits,
  pSensors: [pSensor],
  pControls: {'192.168.1.20': pControl},
  pNow: _now,
  pLastRuns: pLastRuns,
);

void main() {
  group('période', () {
    test('le début est compris, la fin est exclue', () {
      expect(_vacation.isActiveAt(DateTime(2026, 12, 17, 23, 59)), isFalse);
      expect(_vacation.isActiveAt(DateTime(2026, 12, 18)), isTrue);
      expect(_vacation.isActiveAt(DateTime(2026, 12, 27, 23, 59)), isTrue);
      expect(_vacation.isActiveAt(DateTime(2026, 12, 28)), isFalse);
    });
  });

  group('hors gel', () {
    test('sous le seuil, la clim chauffe à la consigne hors gel', () {
      final vDecisions = _vacationDecisions(_sensor(7), _control());

      expect(vDecisions, hasLength(1));
      expect(vDecisions.single.control.power, isTrue);
      expect(vDecisions.single.control.mode, DaikinMode.heat);
      expect(vDecisions.single.control.setpointDegrees, defaultFrostSetpoint);
      expect(vDecisions.single.rule.name, 'Vacances');
    });

    test('entre le seuil et la consigne, rien ne change (hystérésis)', () {
      expect(_vacationDecisions(_sensor(8), _control(pPower: true)), isEmpty);
      expect(_vacationDecisions(_sensor(11.9), _control(pPower: true)), isEmpty);
      expect(_vacationDecisions(_sensor(10), _control()), isEmpty);
    });

    test('la consigne atteinte, la clim allumée est coupée', () {
      final vDecisions = _vacationDecisions(_sensor(12), _control(pPower: true));

      expect(vDecisions.single.control.power, isFalse);
    });

    test('une clim déjà éteinte, ou déjà en chauffe hors gel, ne reçoit rien', () {
      final vHeating = _control(pPower: true, pSetpoint: '12.0');

      expect(_vacationDecisions(_sensor(15), _control()), isEmpty);
      expect(_vacationDecisions(_sensor(7), vHeating), isEmpty);
    });

    test('capteur absent, relevé trop vieux, daté du futur ou état inconnu : rien', () {
      final vNoSensor = [const AcUnit(name: 'Salon', host: '192.168.1.20')];

      expect(_vacationDecisions(_sensor(5), _control(), pUnits: vNoSensor), isEmpty);
      expect(
        _vacationDecisions(_sensor(5, pAge: const Duration(minutes: 21)), _control()),
        isEmpty,
      );
      expect(
        _vacationDecisions(_sensor(5, pAge: const Duration(minutes: -5)), _control()),
        isEmpty,
      );
      expect(
        evaluateVacation(
          pVacation: _vacation,
          pUnits: const [_unit],
          pSensors: [_sensor(5)],
          pControls: const {},
          pNow: _now,
        ),
        isEmpty,
      );
      expect(
        evaluateVacation(
          pVacation: _vacation,
          pUnits: const [_unit],
          pSensors: const [Sensor(name: 'Autre')],
          pControls: {'192.168.1.20': _control()},
          pNow: _now,
        ),
        isEmpty,
      );
      expect(
        evaluateVacation(
          pVacation: _vacation,
          pUnits: const [_unit],
          pSensors: const [Sensor(name: 'TP357 (1A2B)')],
          pControls: {'192.168.1.20': _control()},
          pNow: _now,
        ),
        isEmpty,
      );
    });

    test('le délai entre deux commandes est respecté', () {
      const vKey = '192.168.1.20|Vacances';
      final vRecent = {vKey: _now.subtract(const Duration(minutes: 29))};
      final vOld = {vKey: _now.subtract(const Duration(minutes: 30))};

      expect(_vacationDecisions(_sensor(5), _control(), pLastRuns: vRecent), isEmpty);
      expect(_vacationDecisions(_sensor(5), _control(), pLastRuns: vOld), hasLength(1));
    });

    test('des seuils personnalisés sont suivis', () {
      final vVacation = VacationMode(
        from: DateTime(2026, 12, 18),
        until: DateTime(2026, 12, 28),
        frostTemp: 5,
        frostSetpoint: 10,
      );
      List<AutoDecision> run(double pTemp) => evaluateVacation(
        pVacation: vVacation,
        pUnits: const [_unit],
        pSensors: [_sensor(pTemp)],
        pControls: {'192.168.1.20': _control()},
        pNow: _now,
      );

      expect(run(6), isEmpty);
      expect(run(4).single.control.setpointDegrees, 10);
    });
  });

  group('choix entre règles et vacances', () {
    const vHumidityRule = AutoRule(
      name: 'Humidité',
      acHost: '192.168.1.20',
      metric: AutoMetric.humidity,
      side: AutoSide.above,
      threshold: 60,
      action: AutoActionKind.powerOff,
    );

    List<AutoDecision> run(VacationMode? pVacation, DateTime pAt, Sensor pSensor) =>
        evaluateAutomations(
          pRules: const [vHumidityRule],
          pVacation: pVacation,
          pUnits: const [_unit],
          pSensors: [pSensor],
          pControls: {'192.168.1.20': _control(pPower: true)},
          pNow: pAt,
        );

    test('en vacances, les règles de confort sont suspendues', () {
      final vSensor = _sensor(15, pHumidity: 80);

      expect(run(_vacation, _now, vSensor), isEmpty);
    });

    test('en vacances, le hors gel s\'applique', () {
      expect(run(_vacation, _now, _sensor(6)).single.rule.name, 'Vacances');
    });

    test('hors période ou sans mode vacances, les règles reprennent', () {
      final vSensor = _sensor(15, pHumidity: 80);
      final vAfter = DateTime(2026, 12, 29);
      final vAfterSensor = Sensor(
        name: 'TP357 (1A2B)',
        readings: [Reading(at: vAfter, temp: 15, humidity: 80)],
      );

      expect(run(null, _now, vSensor).single.rule.name, 'Humidité');
      expect(run(_vacation, vAfter, vAfterSensor).single.rule.name, 'Humidité');
    });
  });

  group('fichier', () {
    test('écriture puis lecture redonnent le mode vacances', () {
      final vBack = parseVacation(
        vacationJson(
          VacationMode(
            from: DateTime(2026, 12, 18),
            until: DateTime(2026, 12, 28, 18),
            frostTemp: 6,
            frostSetpoint: 11,
          ),
        ),
      )!;

      expect(vBack.from, DateTime(2026, 12, 18));
      expect(vBack.until, DateTime(2026, 12, 28, 18));
      expect(vBack.frostTemp, 6);
      expect(vBack.frostSetpoint, 11);
    });

    test('les températures absentes prennent les valeurs par défaut', () {
      final vBack = parseVacation(
        '{"version": 1, "from": "2026-12-18T00:00:00", "until": "2026-12-28T00:00:00"}',
      )!;

      expect(vBack.frostTemp, defaultFrostTemp);
      expect(vBack.frostSetpoint, defaultFrostSetpoint);
    });

    test('un fichier illisible, d\'une autre version ou incohérent donne null', () {
      const vDates = '"from": "2026-12-18T00:00:00", "until": "2026-12-28T00:00:00"';

      expect(parseVacation('pas du json'), isNull);
      expect(parseVacation('[]'), isNull);
      expect(parseVacation('{"version": 2, $vDates}'), isNull);
      expect(parseVacation('{"version": 1}'), isNull);
      expect(
        parseVacation(
          '{"version": 1, "from": "2026-12-28T00:00:00", "until": "2026-12-18T00:00:00"}',
        ),
        isNull,
      );
      expect(
        parseVacation('{"version": 1, $vDates, "frostTemp": 12, "frostSetpoint": 12}'),
        isNull,
      );
    });
  });
}
