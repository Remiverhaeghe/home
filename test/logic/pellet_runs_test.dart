import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/pellet_runs.dart';

final _t0 = DateTime(2026, 12, 7, 10);

void main() {
  test('la marche entre deux lectures compte si le poêle marchait à la première', () {
    final vRuns = const PelletRuns()
        .record(_t0, pOn: true)
        .record(_t0.add(const Duration(minutes: 5)), pOn: true)
        .record(_t0.add(const Duration(minutes: 10)), pOn: false)
        .record(_t0.add(const Duration(minutes: 15)), pOn: false);

    expect(vRuns.minutesByDay['2026-12-07'], 10);
    expect(vRuns.lastOn, isFalse);
  });

  test('un trop long silence entre deux lectures n\'est pas compté', () {
    final vRuns = const PelletRuns()
        .record(_t0, pOn: true)
        .record(_t0.add(const Duration(hours: 3)), pOn: true);

    expect(vRuns.minutesByDay, isEmpty);
  });

  test('une lecture dans le passé ou la toute première ne comptent rien', () {
    final vRuns = const PelletRuns().record(_t0, pOn: true).record(_t0, pOn: true);

    expect(vRuns.minutesByDay, isEmpty);
    expect(vRuns.lastAt, _t0);
  });

  test('les heures se totalisent sur 7 et 30 jours, les vieux jours sont oubliés', () {
    final vRuns = PelletRuns(
      minutesByDay: const {
        '2026-12-07': 120,
        '2026-12-01': 60,
        '2026-11-20': 180,
        '2026-11-01': 600,
      },
      lastAt: _t0,
    );

    expect(vRuns.hoursOver(7, _t0), 3);
    expect(vRuns.hoursOver(30, _t0), 6);
    final vLater = vRuns.record(DateTime(2027, 3, 10), pOn: false);
    expect(vLater.minutesByDay, isEmpty);
  });

  test('sans débit donné, aucune consommation n\'est annoncée', () {
    expect(const PelletRuns().kgFor(10), isNull);
    expect(const PelletRuns().withFlow(pKgPerHour: 1.2, pBagKg: 15).kgFor(10), 12);
  });

  test('le journal s\'écrit et se relit, abîmé il redevient vide', () {
    final vRuns = const PelletRuns(
      minutesByDay: {'2026-12-07': 90},
      kgPerHour: 1.4,
      bagKg: 10,
    ).record(_t0, pOn: true);

    final vRead = parsePelletRuns(pelletRunsJson(vRuns));

    expect(vRead.minutesByDay, {'2026-12-07': 90});
    expect(vRead.lastAt, _t0);
    expect(vRead.lastOn, isTrue);
    expect(vRead.kgPerHour, 1.4);
    expect(vRead.bagKg, 10);
    expect(parsePelletRuns('pas du json').minutesByDay, isEmpty);
    expect(parsePelletRuns('[1]').lastAt, isNull);
    final vOdd = parsePelletRuns('{"jours":{"a":"x","2026-12-01":30},"debitKgH":-1,"sacKg":0}');
    expect(vOdd.minutesByDay, {'2026-12-01': 30});
    expect(vOdd.kgPerHour, isNull);
    expect(vOdd.bagKg, defaultBagKg);
  });

  test('la semaine d\'avant se compte sur les 7 jours qui précèdent les 7 derniers', () {
    final vRuns = const PelletRuns(
      minutesByDay: {
        '2026-12-07': 120,
        '2026-12-01': 60,
        '2026-11-30': 180,
        '2026-11-24': 240,
        '2026-11-23': 600,
      },
    );

    expect(vRuns.hoursOver(7, _t0), 3);
    expect(vRuns.hoursPreviousWeek(_t0), 7);
  });

  test('le coût suit le prix du sac et n\'est annoncé qu\'avec lui', () {
    const vFlow = PelletRuns(kgPerHour: 1.5, bagKg: 15);

    expect(vFlow.costFor(30), isNull);
    expect(vFlow.costFor(null), isNull);
    final vPriced = vFlow.withFlow(pKgPerHour: 1.5, pBagKg: 15, pBagPrice: 6.5);
    expect(vPriced.costFor(30), 13);
  });

  test('le prix du sac s\'écrit et se relit, absent ou nul il est ignoré', () {
    const vRuns = PelletRuns(bagPrice: 6.9);

    expect(parsePelletRuns(pelletRunsJson(vRuns)).bagPrice, 6.9);
    expect(parsePelletRuns('{"prixSac": 0}').bagPrice, isNull);
    expect(parsePelletRuns('{}').bagPrice, isNull);
  });

  group('stock de pellets', () {
    final vStart = DateTime(2026, 12, 1, 9);
    const vBase = PelletRuns(
      minutesByDay: {'2026-11-30': 600, '2026-12-01': 120, '2026-12-05': 240, '2026-12-07': 120},
      kgPerHour: 1.5,
      bagKg: 15,
    );

    test('sans stock ou sans débit, rien n\'est annoncé', () {
      expect(vBase.remainingKg(_t0), isNull);
      expect(vBase.withStock(10, vStart).withFlow(pKgPerHour: null, pBagKg: 15).remainingKg(_t0), isNull);
    });

    test('le stock diminue de ce que le poêle consomme depuis le comptage', () {
      final vRuns = vBase.withStock(10, vStart);

      // Depuis le 1er décembre : 120 + 240 + 120 minutes = 8 h, soit 12 kg sur 150 kg
      expect(vRuns.remainingKg(_t0), 138);
      expect(vRuns.hoursSince(vStart, _t0), 8);
    });

    test('le stock ne descend pas sous zéro', () {
      expect(vBase.withStock(0.2, vStart).remainingKg(_t0), 0);
    });

    test('l\'autonomie suit le rythme des 7 derniers jours', () {
      // 7 derniers jours : 1er au 7 décembre, 8 h de marche, soit 1,714 h par jour, 2,57 kg par jour
      final vRuns = vBase.withStock(1, vStart);

      expect(vRuns.remainingKg(_t0), 3);
      expect(vRuns.autonomyDays(_t0), closeTo(3 / (1.5 * 8 / 7), 1e-9));
      expect(vRuns.isStockLow(_t0), isTrue);
      expect(vBase.withStock(10, vStart).isStockLow(_t0), isFalse);
    });

    test('sans marche récente, pas d\'autonomie', () {
      final vRuns = const PelletRuns(kgPerHour: 1.5).withStock(2, vStart);

      expect(vRuns.autonomyDays(_t0), isNull);
      expect(vRuns.isStockLow(_t0), isFalse);
    });

    test('effacer le stock efface aussi sa date', () {
      final vRuns = vBase.withStock(3, vStart).withStock(null, vStart);

      expect(vRuns.stockBags, isNull);
      expect(vRuns.stockAt, isNull);
    });
  });

  group('arrêt programmé', () {
    test('sans heure, jamais', () {
      expect(const PelletRuns().shouldStopNow(DateTime(2026, 12, 7, 23)), isFalse);
    });

    test('l\'arrêt vaut dans la demi-heure qui suit l\'heure choisie', () {
      final vRuns = const PelletRuns().withStopAt(23 * 60);

      expect(vRuns.shouldStopNow(DateTime(2026, 12, 7, 22, 59)), isFalse);
      expect(vRuns.shouldStopNow(DateTime(2026, 12, 7, 23)), isTrue);
      expect(vRuns.shouldStopNow(DateTime(2026, 12, 7, 23, 29)), isTrue);
      expect(vRuns.shouldStopNow(DateTime(2026, 12, 7, 23, 30)), isFalse);
    });

    test('la fenêtre passe minuit', () {
      final vRuns = const PelletRuns().withStopAt(23 * 60 + 50);

      expect(vRuns.shouldStopNow(DateTime(2026, 12, 8, 0, 10)), isTrue);
      expect(vRuns.shouldStopNow(DateTime(2026, 12, 8, 0, 20)), isFalse);
    });
  });

  test('stock et arrêt programmé s\'écrivent et se relisent, valeurs absurdes ignorées', () {
    final vRuns = const PelletRuns(
      kgPerHour: 1.2,
    ).withStock(4.5, DateTime(2026, 12, 1, 9)).withStopAt(22 * 60 + 30);

    final vRead = parsePelletRuns(pelletRunsJson(vRuns));

    expect(vRead.stockBags, 4.5);
    expect(vRead.stockAt, DateTime(2026, 12, 1, 9));
    expect(vRead.stopAtMinute, 22 * 60 + 30);
    expect(parsePelletRuns('{"stockSacs": -1, "stockLe": "2026-12-01T09:00:00"}').stockBags, isNull);
    expect(parsePelletRuns('{"stockSacs": 3}').stockBags, isNull);
    expect(parsePelletRuns('{"arretMinute": 1440}').stopAtMinute, isNull);
  });
}
