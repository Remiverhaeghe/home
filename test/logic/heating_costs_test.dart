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

  group('heures creuses', () {
    test('une plage de nuit passe minuit, une plage de jour reste dans la journée', () {
      const vNight = OffPeak(startHour: 22, endHour: 6);
      expect(vNight.contains(DateTime(2026, 12, 7, 23)), isTrue);
      expect(vNight.contains(DateTime(2026, 12, 8, 5, 59)), isTrue);
      expect(vNight.contains(DateTime(2026, 12, 8, 6)), isFalse);
      expect(vNight.contains(DateTime(2026, 12, 8, 21, 59)), isFalse);

      const vNoon = OffPeak(startHour: 12, endHour: 14);
      expect(vNoon.contains(DateTime(2026, 12, 7, 13)), isTrue);
      expect(vNoon.contains(DateTime(2026, 12, 7, 14)), isFalse);
    });

    test('une plage vide ou hors de la journée n\'est pas valide', () {
      expect(const OffPeak(startHour: 5, endHour: 5).isValid, isFalse);
      expect(const OffPeak(startHour: -1, endHour: 5).isValid, isFalse);
      expect(const OffPeak(startHour: 5, endHour: 24).isValid, isFalse);
      expect(const OffPeak(startHour: 22, endHour: 6).isValid, isTrue);
    });

    test('la marche à cheval sur le début des heures creuses se partage', () {
      const vWindow = OffPeak(startHour: 22, endHour: 6);
      final vStart = DateTime(2026, 12, 7, 21, 55);
      final vLog = const RunLog()
          .record(vStart, pOn: true, pOffPeak: vWindow)
          .record(vStart.add(const Duration(minutes: 10)), pOn: true, pOffPeak: vWindow);

      expect(vLog.minutesByDay['2026-12-07'], 10);
      expect(vLog.offPeakByDay['2026-12-07'], 5);
    });

    test('sans plage donnée, aucune minute n\'est comptée en heures creuses', () {
      final vLog = const RunLog()
          .record(_t0, pOn: true)
          .record(_t0.add(const Duration(minutes: 10)), pOn: true);

      expect(vLog.offPeakByDay, isEmpty);
    });

    const vBase = AcRuns(
      logs: {
        'a': RunLog(minutesByDay: {'2026-12-07': 120}, offPeakByDay: {'2026-12-07': 60}),
      },
      kwByHost: {'a': 1.5},
      pricePerKwh: 0.25,
    );

    test('les heures creuses se paient au prix donné pour elles', () {
      final vRuns = vBase.withSettings(
        pKwByHost: vBase.kwByHost,
        pPricePerKwh: 0.25,
        pMonthlyBudget: null,
        pOffPeak: const OffPeak(startHour: 22, endHour: 6),
        pOffPeakPrice: 0.15,
      );

      expect(vRuns.costOver('a', 7, _t0), closeTo(1.5 * (0.25 + 0.15), 1e-9));
      expect(vRuns.totalCost(['a'], 7, _t0), closeTo(0.6, 1e-9));
    });

    test('sans prix creux ou sans plage, tout compte au prix normal', () {
      final vNoPrice = vBase.withSettings(
        pKwByHost: vBase.kwByHost,
        pPricePerKwh: 0.25,
        pMonthlyBudget: null,
        pOffPeak: const OffPeak(startHour: 22, endHour: 6),
      );

      expect(vNoPrice.costOver('a', 7, _t0), closeTo(0.75, 1e-9));
      expect(vBase.costOver('a', 7, _t0), closeTo(0.75, 1e-9));
      expect(vBase.costOver('inconnue', 7, _t0), isNull);
    });

    test('la plage et son prix s\'écrivent et se relisent', () {
      final vRuns = vBase.withSettings(
        pKwByHost: vBase.kwByHost,
        pPricePerKwh: 0.25,
        pMonthlyBudget: null,
        pOffPeak: const OffPeak(startHour: 22, endHour: 6),
        pOffPeakPrice: 0.15,
      );

      final vRead = parseAcRuns(acRunsJson(vRuns));

      expect(vRead.offPeak?.startHour, 22);
      expect(vRead.offPeak?.endHour, 6);
      expect(vRead.offPeakPrice, 0.15);
      expect(vRead.logOf('a').offPeakByDay, {'2026-12-07': 60});
      expect(
        parseAcRuns('{"creuses": {"debut": 5, "fin": 5}, "prixCreuxKwh": -1}').offPeak,
        isNull,
      );
    });
  });
}
