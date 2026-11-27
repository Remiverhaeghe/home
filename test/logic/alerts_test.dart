import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/alerts.dart';
import 'package:home/logic/reading.dart';

final _now = DateTime(2026, 12, 7, 14);

Sensor _sensor(String pName, double pTemp, double pHumidity, {Duration pAge = Duration.zero}) =>
    Sensor(
      name: pName,
      readings: [Reading(at: _now.subtract(pAge), temp: pTemp, humidity: pHumidity)],
    );

void main() {
  group('alertes', () {
    test('un capteur normal n\'alerte pas', () {
      expect(evaluateAlerts([_sensor('A', 20, 50)], _now), isEmpty);
    });

    test('le gel alerte sous le seuil', () {
      final vAlerts = evaluateAlerts([_sensor('A', 4.9, 50), _sensor('B', 5, 50)], _now);

      expect(vAlerts, hasLength(1));
      expect(vAlerts.single.kind, AlertKind.frost);
      expect(vAlerts.single.value, 4.9);
      expect(vAlerts.single.sensorName, 'A');
    });

    test('l\'humidité alerte au-dessus du seuil', () {
      final vAlerts = evaluateAlerts([_sensor('A', 20, 70.1), _sensor('B', 20, 70)], _now);

      expect(vAlerts, hasLength(1));
      expect(vAlerts.single.kind, AlertKind.humidity);
      expect(vAlerts.single.value, 70.1);
    });

    test('gel et humidité peuvent s\'ajouter sur le même capteur', () {
      final vAlerts = evaluateAlerts([_sensor('A', 3, 90)], _now);

      expect(vAlerts.map((pAlert) => pAlert.kind), [AlertKind.frost, AlertKind.humidity]);
    });

    test('un capteur muet alerte, sans mesure, et masque les autres alertes', () {
      final vAlerts = evaluateAlerts(
        [_sensor('A', 3, 90, pAge: const Duration(minutes: 31)), _sensor('B', 20, 50, pAge: silentAfter)],
        _now,
      );

      expect(vAlerts, hasLength(1));
      expect(vAlerts.single.kind, AlertKind.silent);
      expect(vAlerts.single.value, isNull);
    });

    test('un capteur qui n\'a jamais parlé n\'alerte pas', () {
      expect(evaluateAlerts(const [Sensor(name: 'A')], _now), isEmpty);
    });
  });

  group('alertes nouvelles', () {
    test('seules les alertes pas encore signalées sont gardées', () {
      final vCurrent = evaluateAlerts([_sensor('A', 3, 90)], _now);

      final vFresh = freshAlerts(vCurrent, {'A|frost'});

      expect(vFresh.single.kind, AlertKind.humidity);
      expect(vCurrent.first.key, 'A|frost');
      expect(freshAlerts(vCurrent, {}), hasLength(2));
    });
  });
}
