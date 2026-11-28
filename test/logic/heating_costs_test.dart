import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/heating_costs.dart';

final _t0 = DateTime(2026, 12, 7, 10);

void main() {
  group('journal de marche', () {
    test('la marche entre deux lectures compte si l\'appareil marchait à la première', () {
      final vLog = const RunLog()
          .record(_t0, pOn: true)
          .record(_t0.add(const Duration(minutes: 5)), pOn: true)
          .record(_t0.add(const Duration(minutes: 10)), pOn: false)
          .record(_t0.add(const Duration(minutes: 15)), pOn: false);

      expect(vLog.minutesByDay['2026-12-07'], 10);
      expect(vLog.lastOn, isFalse);
    });

    test('un trop long silence n\'est pas compté', () {
      final vLog = const RunLog()
          .record(_t0, pOn: true)
          .record(_t0.add(const Duration(hours: 3)), pOn: true);

      expect(vLog.minutesByDay, isEmpty);
    });

    test('les heures de la semaine et de la semaine d\'avant', () {
      const vLog = RunLog(
        minutesByDay: {
          '2026-12-07': 120,
          '2026-12-01': 60,
          '2026-11-30': 180,
          '2026-11-24': 240,
          '2026-11-23': 600,
        },
      );

      expect(vLog.hoursOver(7, _t0), 3);
      expect(vLog.hoursPreviousWeek(_t0), 7);
    });

    test('les jours trop anciens sont oubliés', () {
      final vLog = const RunLog(minutesByDay: {'2026-01-01': 60}).record(_t0, pOn: false);

      expect(vLog.minutesByDay, isEmpty);
    });
  });

  group('énergie et coût', () {
    const vRuns = AcRuns(
      logs: {
        'a': RunLog(minutesByDay: {'2026-12-07': 120}),
        'b': RunLog(minutesByDay: {'2026-12-06': 60}),
      },
      kwByHost: {'a': 1.5, 'b': 0.8},
      pricePerKwh: 0.25,
    );

    test('l\'énergie suit la puissance donnée, sans puissance rien n\'est estimé', () {
      expect(vRuns.kwhOver('a', 7, _t0), 3);
      expect(vRuns.kwhOver('c', 7, _t0), isNull);
    });

    test('le coût suit le prix du kWh', () {
      expect(vRuns.costOf(3), 0.75);
      expect(vRuns.costOf(null), isNull);
      expect(const AcRuns().costOf(3), isNull);
    });

    test('le coût total exige la puissance de chaque clim', () {
      expect(vRuns.totalCost(['a', 'b'], 7, _t0), closeTo(0.75 + 0.2, 1e-9));
      expect(vRuns.totalCost(['a', 'c'], 7, _t0), isNull);
    });

    test('le repère d\'un degré en moins vaut 7 % de la dépense', () {
      expect(degreeSaving(100), closeTo(7, 1e-9));
    });
  });

  test('le budget est dans les clous, proche ou dépassé', () {
    expect(budgetState(50, 100), BudgetState.ok);
    expect(budgetState(80, 100), BudgetState.near);
    expect(budgetState(100, 100), BudgetState.near);
    expect(budgetState(100.01, 100), BudgetState.over);
  });

  test('le fichier s\'écrit et se relit, abîmé il redevient vide', () {
    const vRuns = AcRuns(
      logs: {
        'a': RunLog(minutesByDay: {'2026-12-07': 90}),
      },
      kwByHost: {'a': 1.2},
      pricePerKwh: 0.2,
      monthlyBudget: 120,
    );

    final vRead = parseAcRuns(acRunsJson(vRuns));

    expect(vRead.logOf('a').minutesByDay, {'2026-12-07': 90});
    expect(vRead.kwByHost, {'a': 1.2});
    expect(vRead.pricePerKwh, 0.2);
    expect(vRead.monthlyBudget, 120);
    expect(parseAcRuns('pas du json').logs, isEmpty);
    expect(parseAcRuns('[1]').pricePerKwh, isNull);
    expect(parseAcRuns('{"kw": {"a": 0}, "prixKwh": 0}').kwByHost, isEmpty);
  });
}
