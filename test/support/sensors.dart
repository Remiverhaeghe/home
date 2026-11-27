import 'package:home/logic/reading.dart';

/// Capteur fictif de la salle de bain, avec deux relevés le même jour et un le lendemain.
Sensor bathroomSensor() => Sensor(
  name: 'Salle de bain',
  readings: [
    Reading(at: DateTime(2026, 12, 1, 8), temp: 20, humidity: 70),
    Reading(at: DateTime(2026, 12, 1, 20), temp: 22, humidity: 50),
    Reading(at: DateTime(2026, 12, 2, 8), temp: 19, humidity: 55),
  ],
);

/// Fichier d'échange JSON valide, au format de docs/echange-climat.md.
const exchangeSample = '''
{
  "version": 1,
  "sensors": [
    {
      "name": "Salle de bain",
      "readings": [{ "at": "2026-12-01T08:00:00", "temp": 20.5, "humidity": 61 }]
    }
  ]
}
''';
