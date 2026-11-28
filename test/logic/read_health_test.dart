import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/read_health.dart';

void main() {
  final vNow = DateTime(2026, 12, 7, 14);

  test('un tour réussi remet la série à zéro, un tour manqué l\'allonge', () {
    final vHealth = const ReadHealth()
        .record('Salon', vNow, pOk: false)
        .record('Salon', vNow.add(const Duration(minutes: 5)), pOk: false)
        .record('Salon', vNow.add(const Duration(minutes: 10)), pOk: false);

    expect(vHealth.of('Salon').streak, 3);
    expect(vHealth.of('Salon').lastOk, isNull);

    final vBack = vHealth.record('Salon', vNow.add(const Duration(minutes: 15)), pOk: true);

    expect(vBack.of('Salon').streak, 0);
    expect(vBack.of('Salon').lastOk, vNow.add(const Duration(minutes: 15)));
    expect(vBack.of('Salon').today(vNow).ok, 1);
    expect(vBack.of('Salon').today(vNow).missed, 3);
  });

  test('chaque capteur a sa propre santé', () {
    final vHealth = const ReadHealth().record('A', vNow, pOk: true).record('B', vNow, pOk: false);

    expect(vHealth.of('A').streak, 0);
    expect(vHealth.of('B').streak, 1);
    expect(vHealth.of('inconnu').lastTry, isNull);
  });

  test('la part de tours réussis se calcule sur les jours demandés', () {
    var vHealth = const ReadHealth();
    for (var vTurn = 0; vTurn < 3; vTurn++) {
      vHealth = vHealth.record('A', vNow.subtract(const Duration(days: 10)), pOk: false);
    }
    vHealth = vHealth.record('A', vNow, pOk: true).record('A', vNow, pOk: true);
    vHealth = vHealth.record('A', vNow, pOk: true).record('A', vNow, pOk: false);

    expect(vHealth.of('A').rateOver(7, vNow), 0.75);
    expect(vHealth.of('A').rateOver(14, vNow), closeTo(3 / 7, 1e-9));
    expect(const SensorHealth().rateOver(7, vNow), isNull);
  });

  test('les jours trop anciens sont oubliés', () {
    final vHealth = const ReadHealth()
        .record('A', vNow.subtract(const Duration(days: 30)), pOk: true)
        .record('A', vNow, pOk: true);

    expect(vHealth.of('A').days.keys, ['2026-12-07']);
  });

  test('le fichier s\'écrit et se relit, abîmé il redevient vide', () {
    final vHealth = const ReadHealth()
        .record('Salon', vNow, pOk: true)
        .record('Salon', vNow.add(const Duration(minutes: 5)), pOk: false);

    final vRead = parseReadHealth(readHealthJson(vHealth));

    expect(vRead.of('Salon').streak, 1);
    expect(vRead.of('Salon').lastOk, vNow);
    expect(vRead.of('Salon').today(vNow).ok, 1);
    expect(vRead.of('Salon').today(vNow).missed, 1);
    expect(parseReadHealth('pas du json').sensors, isEmpty);
    expect(parseReadHealth('{"version": 2}').sensors, isEmpty);
    expect(parseReadHealth('{"version": 1, "capteurs": []}').sensors, isEmpty);
    expect(
      parseReadHealth(
        '{"version":1,"capteurs":{"A":{"serie":-3,"jours":{"2026-12-07":[1]}}}}',
      ).of('A').days,
      isEmpty,
    );
  });
}
