import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/automations.dart';
import 'package:home/logic/rule_form.dart';

RuleBuild _build({
  String pName = '',
  String pHost = 'h',
  AutoMetric pMetric = AutoMetric.humidity,
  AutoSide pSide = AutoSide.above,
  String pThreshold = '70',
  AutoActionKind pAction = AutoActionKind.powerOff,
  String pSetpoint = '',
  List<AutoRule> pExisting = const [],
}) => buildRule(
  pName: pName,
  pAcHost: pHost,
  pMetric: pMetric,
  pSide: pSide,
  pThreshold: pThreshold,
  pAction: pAction,
  pSetpoint: pSetpoint,
  pExisting: pExisting,
);

void main() {
  group('nombres', () {
    test('virgule ou point, espaces ignorés', () {
      expect(parseNumber(' 21,5 '), 21.5);
      expect(parseNumber('21.5'), 21.5);
      expect(parseNumber(''), isNull);
      expect(parseNumber('abc'), isNull);
    });
  });

  group('seuil', () {
    test('vide ou illisible : refusé', () {
      expect(_build(pThreshold: '').problem, RuleProblem.noThreshold);
      expect(_build(pThreshold: 'beaucoup').problem, RuleProblem.noThreshold);
    });

    test('l\'humidité reste entre 0 et 100 %', () {
      expect(_build(pThreshold: '101').problem, RuleProblem.thresholdOutOfRange);
      expect(_build(pThreshold: '-1').problem, RuleProblem.thresholdOutOfRange);
      expect(_build(pThreshold: '100').rule, isNotNull);
      expect(_build(pThreshold: '0').rule, isNotNull);
    });

    test('la température reste entre -30 et 60 °C', () {
      expect(_build(pMetric: AutoMetric.temperature, pThreshold: '61').problem, isNotNull);
      expect(_build(pMetric: AutoMetric.temperature, pThreshold: '-31').problem, isNotNull);
      expect(_build(pMetric: AutoMetric.temperature, pThreshold: '-5').rule, isNotNull);
    });
  });

  group('consigne', () {
    test('ignorée quand la règle coupe la clim', () {
      final vRule = _build(pSetpoint: '99').rule!;

      expect(vRule.setpoint, isNull);
    });

    test('vide : la clim garde la sienne', () {
      expect(_build(pAction: AutoActionKind.cool).rule!.setpoint, isNull);
    });

    test('lue pour le froid, le chaud et l\'auto', () {
      expect(_build(pAction: AutoActionKind.heat, pSetpoint: '19,5').rule!.setpoint, 19.5);
    });

    test('hors de la plage de la clim ou illisible : refusée', () {
      expect(_build(pAction: AutoActionKind.cool, pSetpoint: '5').problem, RuleProblem.badSetpoint);
      expect(
        _build(pAction: AutoActionKind.cool, pSetpoint: '40').problem,
        RuleProblem.badSetpoint,
      );
      expect(_build(pAction: AutoActionKind.cool, pSetpoint: 'x').problem, RuleProblem.badSetpoint);
    });
  });

  group('nom', () {
    test('vide, il décrit la règle', () {
      expect(_build().rule!.name, 'Humidité > 70');
      expect(
        _build(
          pMetric: AutoMetric.temperature,
          pSide: AutoSide.below,
          pThreshold: '18,5',
        ).rule!.name,
        'Température < 18.5',
      );
    });

    test('le nom saisi est gardé, sans espaces autour', () {
      expect(_build(pName: '  Salle de bain ').rule!.name, 'Salle de bain');
    });

    test('un nom déjà pris sur la même clim reçoit un numéro, pas sur une autre', () {
      final vFirst = _build(pName: 'Bain').rule!;
      final vSecond = _build(pName: 'Bain', pExisting: [vFirst]).rule!;
      final vThird = _build(pName: 'Bain', pExisting: [vFirst, vSecond]).rule!;
      final vOther = _build(pName: 'Bain', pHost: 'autre', pExisting: [vFirst]).rule!;

      expect(vSecond.name, 'Bain (2)');
      expect(vThird.name, 'Bain (3)');
      expect(vOther.name, 'Bain');
    });
  });
}
