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
}
