import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/sensor_log.dart';

import '../support/sensors.dart';

Reading _at(DateTime pAt) => Reading(at: pAt, temp: 21, humidity: 50);

void main() {
  test('un capteur inconnu est créé avec son premier relevé', () {
    final vSensors = withLiveReading([], '  TP357 (1A2B) ', _at(DateTime(2026, 12, 1, 8)));

    expect(vSensors.single.name, 'TP357 (1A2B)');
    expect(vSensors.single.readings, hasLength(1));
  });

  test('un relevé trop proche du précédent est ignoré', () {
    final vKnown = [bathroomSensor()];
    final vLast = bathroomSensor().last!.at;

    final vSensors = withLiveReading(
      vKnown,
      'Salle de bain',
      _at(vLast.add(const Duration(seconds: 59))),
    );

    expect(identical(vSensors, vKnown), isTrue);
  });

  test('à une minute pile, le relevé est gardé', () {
    final vLast = bathroomSensor().last!.at;

    final vSensors = withLiveReading(
      [bathroomSensor()],
      'salle de bain',
      _at(vLast.add(minReadingGap)),
    );

    expect(vSensors.single.readings, hasLength(4));
    expect(vSensors.single.name, 'Salle de bain');
  });

  test('les autres capteurs ne changent pas', () {
    final vOther = Sensor(name: 'Cave', readings: [_at(DateTime(2026, 12, 1))]);
    final vLast = bathroomSensor().last!.at;

    final vSensors = withLiveReading(
      [vOther, bathroomSensor()],
      'Salle de bain',
      _at(vLast.add(const Duration(hours: 1))),
    );

    expect(identical(vSensors.first, vOther), isTrue);
    expect(vSensors.last.readings, hasLength(4));
  });

  test('un capteur sans relevé reçoit le premier', () {
    final vSensors = withLiveReading(
      [const Sensor(name: 'Cave')],
      'Cave',
      _at(DateTime(2026, 12, 1)),
    );

    expect(vSensors.single.readings, hasLength(1));
  });
}
