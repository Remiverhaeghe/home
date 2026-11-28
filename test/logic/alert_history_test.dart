import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/alert_history.dart';
import 'package:home/logic/alerts.dart';
import 'package:home/logic/heating_costs.dart';

void main() {
  const vQuiet = OffPeak(startHour: 22, endHour: 7);
  const vFrost = SensorAlert(sensorName: 'Cave', kind: AlertKind.frost, value: 2);
  const vHumid = SensorAlert(sensorName: 'Salle de bain', kind: AlertKind.humidity, value: 80);

  group('audibleAlerts', () {
    test('de nuit, seul le gel sonne', () {
      final vAlerts = audibleAlerts([vHumid, vFrost], DateTime(2026, 11, 28, 23), vQuiet);

      expect(vAlerts, [vFrost]);
    });

    test('après minuit, la plage qui passe minuit reste silencieuse', () {
      expect(audibleAlerts([vHumid], DateTime(2026, 11, 29, 6, 59), vQuiet), isEmpty);
    });

    test('à l\'heure de fin, tout sonne de nouveau', () {
      expect(audibleAlerts([vHumid], DateTime(2026, 11, 29, 7), vQuiet), [vHumid]);
    });

    test('sans plage, ou avec une plage vide, tout sonne', () {
      final vNow = DateTime(2026, 11, 28, 23);

      expect(audibleAlerts([vHumid], vNow, null), [vHumid]);
      expect(
        audibleAlerts([vHumid], vNow, const OffPeak(startHour: 8, endHour: 8)),
        [vHumid],
      );
    });
  });

  group('historique', () {
    test('une alerte qui dure n\'est notée qu\'une fois par tranche de 6 heures', () {
      final vFirst = DateTime(2026, 11, 28, 8);
      var vHistory = appendAlerts([], [vHumid], vFirst);
      vHistory = appendAlerts(vHistory, [vHumid], vFirst.add(const Duration(hours: 5)));
      expect(vHistory, hasLength(1));

      vHistory = appendAlerts(vHistory, [vHumid], vFirst.add(const Duration(hours: 6)));
      expect(vHistory, hasLength(2));
    });

    test('deux capteurs ou deux sortes d\'alerte se notent séparément', () {
      final vNow = DateTime(2026, 11, 28, 8);

      expect(appendAlerts([], [vHumid, vFrost], vNow), hasLength(2));
    });

    test('garde les cent plus récentes', () {
      var vHistory = <AlertEntry>[];
      for (var vIndex = 0; vIndex < alertHistoryMax + 5; vIndex++) {
        final vAlert = SensorAlert(sensorName: 'C$vIndex', kind: AlertKind.silent);
        vHistory = appendAlerts(vHistory, [vAlert], DateTime(2026, 11, 28, 8));
      }

      expect(vHistory, hasLength(alertHistoryMax));
      expect(vHistory.first.sensorName, 'C5');
    });

    test('s\'écrit et se relit, une ligne abîmée est ignorée', () {
      final vHistory = appendAlerts([], [vFrost], DateTime(2026, 11, 28, 8));
      final vText = '${alertHistoryText(vHistory)}\nnon json\n{"at":"x","sensor":"A","kind":"frost"}';

      final vBack = parseAlertHistory(vText);

      expect(vBack, hasLength(1));
      expect(vBack.single.sensorName, 'Cave');
      expect(vBack.single.kind, AlertKind.frost);
      expect(vBack.single.at, DateTime(2026, 11, 28, 8));
    });
  });
}
