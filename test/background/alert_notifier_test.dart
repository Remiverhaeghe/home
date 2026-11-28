import 'package:flutter_test/flutter_test.dart';
import 'package:home/background/alert_notifier.dart';
import 'package:home/logic/alerts.dart';

void main() {
  test('titres courts selon le type d\'alerte', () {
    expect(alertTitle(const SensorAlert(sensorName: 'A', kind: AlertKind.frost)), 'Risque de gel');
    expect(
      alertTitle(const SensorAlert(sensorName: 'A', kind: AlertKind.humidity)),
      'Humidité haute',
    );
    expect(alertTitle(const SensorAlert(sensorName: 'A', kind: AlertKind.silent)), 'Capteur muet');
  });

  test('la même alerte garde le même numéro, deux alertes différentes non', () {
    const vFrost = SensorAlert(sensorName: 'Salon', kind: AlertKind.frost, value: 3);
    const vFrostLater = SensorAlert(sensorName: 'Salon', kind: AlertKind.frost, value: 2);
    const vHumidity = SensorAlert(sensorName: 'Salon', kind: AlertKind.humidity, value: 80);

    expect(notificationId(vFrost), notificationId(vFrostLater));
    expect(notificationId(vFrost), isNot(notificationId(vHumidity)));
    expect(notificationId(vFrost), greaterThanOrEqualTo(0));
  });

  test('chaque niveau a son canal, du plus bruyant au plus discret', () {
    final vCritical = alertChannel(AlertLevel.critical);
    final vImportant = alertChannel(AlertLevel.important);
    final vInfo = alertChannel(AlertLevel.info);

    expect({vCritical.channelId, vImportant.channelId, vInfo.channelId}, hasLength(3));
    expect(vCritical.importance.value, greaterThan(vImportant.importance.value));
    expect(vImportant.importance.value, greaterThan(vInfo.importance.value));
  });

  test('le gel est critique, le conseil d\'aération et l\'entretien informent', () {
    expect(alertLevel(AlertKind.frost), AlertLevel.critical);
    expect(alertLevel(AlertKind.silent), AlertLevel.important);
    expect(alertLevel(AlertKind.humidity), AlertLevel.important);
    expect(alertLevel(AlertKind.ventilate), AlertLevel.info);
    expect(alertLevel(AlertKind.maintenance), AlertLevel.info);
  });
}
