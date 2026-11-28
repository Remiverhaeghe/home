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
}
