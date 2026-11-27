import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/sensor_merge.dart';

import '../support/sensors.dart';

void main() {
  test('un capteur nouveau est ajouté', () {
    final vMerged = mergeSensors([bathroomSensor()], [const Sensor(name: 'Cave')]);

    expect(vMerged.map((pS) => pS.name), ['Salle de bain', 'Cave']);
  });

  test('un capteur de même nom, sans tenir compte des majuscules, reçoit les relevés', () {
    final vNew = Sensor(
      name: ' salle de bain ',
      readings: [Reading(at: DateTime(2026, 12, 3, 8), temp: 18, humidity: 52)],
    );

    final vMerged = mergeSensors([bathroomSensor()], [vNew]);

    expect(vMerged, hasLength(1));
    expect(vMerged.single.name, 'Salle de bain');
    expect(vMerged.single.readings, hasLength(4));
    expect(vMerged.single.last!.temp, 18);
  });

  test('un relevé à la même date est remplacé, jamais doublé', () {
    final vNew = Sensor(
      name: 'Salle de bain',
      readings: [Reading(at: DateTime(2026, 12, 1, 8), temp: 25, humidity: 40)],
    );

    final vMerged = mergeSensors([bathroomSensor()], [vNew]);

    expect(vMerged.single.readings, hasLength(3));
    expect(vMerged.single.readings.first.temp, 25);
  });

  test('les relevés restent rangés par date après la fusion', () {
    final vNew = Sensor(
      name: 'Salle de bain',
      readings: [Reading(at: DateTime(2026, 11, 30, 8), temp: 15, humidity: 45)],
    );

    final vMerged = mergeSensors([bathroomSensor()], [vNew]);

    expect(vMerged.single.readings.first.temp, 15);
  });
}
