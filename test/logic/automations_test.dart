import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/automations.dart';
import 'package:home/logic/daikin.dart';
import 'package:home/logic/reading.dart';

final _now = DateTime(2026, 12, 1, 14);

const _unit = AcUnit(name: 'Salon', host: '192.168.1.20', sensorName: 'TP357 (1A2B)');

DaikinControl _control({bool pPower = true, String pMode = '3', String pSetpoint = '22.0'}) =>
    DaikinControl(
      power: pPower,
      modeCode: pMode,
      setpoint: pSetpoint,
      humidity: '0',
      fanRate: 'A',
      fanDirection: '0',
    );

Sensor _sensor({double pTemp = 21, double pHumidity = 50, Duration pAge = Duration.zero}) => Sensor(
  name: 'TP357 (1A2B)',
  readings: [Reading(at: _now.subtract(pAge), temp: pTemp, humidity: pHumidity)],
);

AutoRule _rule({
  AutoMetric pMetric = AutoMetric.humidity,
  AutoSide pSide = AutoSide.above,
  double pThreshold = 60,
  AutoActionKind pAction = AutoActionKind.powerOff,
  double? pSetpoint,
  String pHost = '192.168.1.20',
}) => AutoRule(
  name: 'Règle',
  acHost: pHost,
  metric: pMetric,
  side: pSide,
  threshold: pThreshold,
  action: pAction,
  setpoint: pSetpoint,
);

List<AutoDecision> _evaluate(
  AutoRule pRule, {
  Sensor? pSensor,
  DaikinControl? pControl,
  Map<String, DateTime> pLastRuns = const {},
  List<AcUnit> pUnits = const [_unit],
}) => evaluateRules(
  pRules: [pRule],
  pUnits: pUnits,
  pSensors: [pSensor ?? _sensor()],
  pControls: {'192.168.1.20': pControl ?? _control()},
  pNow: _now,
  pLastRuns: pLastRuns,
);

void main() {
  group('seuil', () {
    test('au-dessus et au-dessous, le seuil lui-même ne déclenche pas', () {
      final vAbove = _rule();
      final vBelow = _rule(pSide: AutoSide.below);
      Reading at(double pHumidity) => Reading(at: _now, temp: 20, humidity: pHumidity);

      expect(vAbove.isMet(at(60.1)), isTrue);
      expect(vAbove.isMet(at(60)), isFalse);
      expect(vBelow.isMet(at(59.9)), isTrue);
      expect(vBelow.isMet(at(60)), isFalse);
    });

    test('la température est comparée quand la règle porte sur elle', () {
      final vRule = _rule(pMetric: AutoMetric.temperature, pThreshold: 25);

      expect(vRule.isMet(Reading(at: _now, temp: 26, humidity: 10)), isTrue);
      expect(vRule.isMet(Reading(at: _now, temp: 24, humidity: 90)), isFalse);
    });
  });

  group('action', () {
    test('couper éteint une clim allumée et ne fait rien sur une clim éteinte', () {
      final vRule = _rule();

      expect(vRule.targetFor(_control())!.power, isFalse);
      expect(vRule.targetFor(_control(pPower: false)), isNull);
    });

    test('froid, chaud et automatique allument avec le bon mode', () {
      final vCool = _rule(pAction: AutoActionKind.cool).targetFor(_control(pMode: '4'))!;
      final vHeat = _rule(pAction: AutoActionKind.heat).targetFor(_control())!;
      final vAuto = _rule(pAction: AutoActionKind.auto).targetFor(_control())!;

      expect(vCool.mode, DaikinMode.cool);
      expect(vHeat.mode, DaikinMode.heat);
      expect(vAuto.mode, DaikinMode.auto);
      expect([vCool, vHeat, vAuto].every((pControl) => pControl.power), isTrue);
    });

    test('allumer une clim éteinte envoie le réglage demandé', () {
      final vTarget = _rule(
        pAction: AutoActionKind.cool,
        pSetpoint: 24,
      ).targetFor(_control(pPower: false));

      expect(vTarget!.power, isTrue);
      expect(vTarget.setpointDegrees, 24);
    });

    test('la consigne est ramenée à la plage acceptée', () {
      final vTarget = _rule(pAction: AutoActionKind.heat, pSetpoint: 60).targetFor(_control());

      expect(vTarget!.setpointDegrees, daikinMaxSetpoint);
    });

    test('un appareil déjà réglé ainsi ne reçoit rien', () {
      final vRule = _rule(pAction: AutoActionKind.cool, pSetpoint: 22);

      expect(vRule.targetFor(_control()), isNull);
    });

    test('depuis le mode sec, la consigne par défaut est envoyée', () {
      final vTarget = _rule(
        pAction: AutoActionKind.cool,
      ).targetFor(_control(pMode: '2', pSetpoint: 'M'));

      expect(vTarget!.mode, DaikinMode.cool);
      expect(vTarget.setpointDegrees, daikinDefaultSetpoint);
    });
  });

  group('décision', () {
    test('une règle dépassée donne une commande pour sa clim', () {
      final vDecisions = _evaluate(_rule(), pSensor: _sensor(pHumidity: 70));

      expect(vDecisions, hasLength(1));
      expect(vDecisions.single.control.power, isFalse);
      expect(vDecisions.single.rule.acHost, '192.168.1.20');
    });

    test('sous le seuil, rien', () {
      expect(_evaluate(_rule(), pSensor: _sensor(pHumidity: 55)), isEmpty);
    });

    test('une clim sans capteur relié est ignorée', () {
      final vUnits = [const AcUnit(name: 'Salon', host: '192.168.1.20')];

      expect(_evaluate(_rule(), pSensor: _sensor(pHumidity: 70), pUnits: vUnits), isEmpty);
    });

    test('une règle pour une clim inconnue est ignorée', () {
      expect(_evaluate(_rule(pHost: '192.168.1.99'), pSensor: _sensor(pHumidity: 70)), isEmpty);
    });

    test('un capteur introuvable ou sans relevé est ignoré', () {
      final vOther = evaluateRules(
        pRules: [_rule()],
        pUnits: const [_unit],
        pSensors: const [Sensor(name: 'Autre')],
        pControls: {'192.168.1.20': _control()},
        pNow: _now,
      );
      final vEmpty = evaluateRules(
        pRules: [_rule()],
        pUnits: const [_unit],
        pSensors: const [Sensor(name: 'TP357 (1A2B)')],
        pControls: {'192.168.1.20': _control()},
        pNow: _now,
      );

      expect(vOther, isEmpty);
      expect(vEmpty, isEmpty);
    });

    test('un relevé trop vieux ou daté du futur ne décide rien', () {
      final vOld = _sensor(pHumidity: 70, pAge: const Duration(minutes: 21));
      final vFuture = _sensor(pHumidity: 70, pAge: const Duration(minutes: -5));
      final vEdge = _sensor(pHumidity: 70, pAge: maxReadingAge);

      expect(_evaluate(_rule(), pSensor: vOld), isEmpty);
      expect(_evaluate(_rule(), pSensor: vFuture), isEmpty);
      expect(_evaluate(_rule(), pSensor: vEdge), hasLength(1));
    });

    test('sans état connu de la clim, rien n\'est envoyé', () {
      final vDecisions = evaluateRules(
        pRules: [_rule()],
        pUnits: const [_unit],
        pSensors: [_sensor(pHumidity: 70)],
        pControls: const {},
        pNow: _now,
      );

      expect(vDecisions, isEmpty);
    });

    test('le délai entre deux déclenchements est respecté', () {
      final vRule = _rule();
      final vSensor = _sensor(pHumidity: 70);
      final vJustBefore = {vRule.key: _now.subtract(const Duration(minutes: 29))};
      final vLongAgo = {vRule.key: _now.subtract(const Duration(minutes: 30))};

      expect(_evaluate(vRule, pSensor: vSensor, pLastRuns: vJustBefore), isEmpty);
      expect(_evaluate(vRule, pSensor: vSensor, pLastRuns: vLongAgo), hasLength(1));
    });

    test('une clim déjà dans l\'état voulu ne donne pas de commande', () {
      final vDecisions = _evaluate(
        _rule(),
        pSensor: _sensor(pHumidity: 70),
        pControl: _control(pPower: false),
      );

      expect(vDecisions, isEmpty);
    });
  });

  group('fichier des règles', () {
    test('écriture puis lecture redonnent les mêmes règles', () {
      final vRules = [
        _rule(),
        const AutoRule(
          name: 'Chaud',
          acHost: '192.168.1.21',
          metric: AutoMetric.temperature,
          side: AutoSide.below,
          threshold: 17.5,
          action: AutoActionKind.heat,
          setpoint: 20,
          minGap: Duration(minutes: 10),
        ),
      ];

      final vBack = parseAutoRules(autoRulesJson(vRules));

      expect(vBack, hasLength(2));
      expect(vBack[0].setpoint, isNull);
      expect(vBack[0].minGap, defaultMinGap);
      expect(vBack[1].name, 'Chaud');
      expect(vBack[1].metric, AutoMetric.temperature);
      expect(vBack[1].side, AutoSide.below);
      expect(vBack[1].threshold, 17.5);
      expect(vBack[1].action, AutoActionKind.heat);
      expect(vBack[1].setpoint, 20);
      expect(vBack[1].minGap, const Duration(minutes: 10));
    });

    test('un fichier illisible ou d\'une autre version donne une liste vide', () {
      expect(parseAutoRules('pas du json'), isEmpty);
      expect(parseAutoRules('[]'), isEmpty);
      expect(parseAutoRules('{"version": 2, "rules": []}'), isEmpty);
      expect(parseAutoRules('{"version": 1}'), isEmpty);
    });

    test('une règle incomplète est ignorée, les autres sont gardées', () {
      const vBase =
          '"name": "A", "ac": "h", "metric": "humidity", "side": "above", '
          '"threshold": 60, "action": "powerOff"';
      final vJson =
          '{"version": 1, "rules": ['
          '{$vBase}, 42, {"name": "B"}, '
          '{"name": " ", "ac": "h", "metric": "humidity", "side": "above", '
          '"threshold": 60, "action": "powerOff"}, '
          '{"name": "C", "ac": "", "metric": "humidity", "side": "above", '
          '"threshold": 60, "action": "powerOff"}, '
          '{"name": "D", "ac": "h", "metric": "vent", "side": "above", '
          '"threshold": 60, "action": "powerOff"}, '
          '{"name": "E", "ac": "h", "metric": "humidity", "side": "above", '
          '"threshold": "beaucoup", "action": "powerOff"}'
          ']}';

      final vRules = parseAutoRules(vJson);

      expect(vRules.map((pRule) => pRule.name), ['A']);
    });

    test('un délai négatif ou mal typé revient au délai par défaut', () {
      for (final vGap in ['-5', '"vite"']) {
        final vRules = parseAutoRules(
          '{"version": 1, "rules": [{"name": "A", "ac": "h", "metric": "humidity", '
          '"side": "above", "threshold": 60, "action": "powerOff", "minGapMinutes": $vGap}]}',
        );

        expect(vRules.single.minGap, defaultMinGap);
      }
    });
  });
}
