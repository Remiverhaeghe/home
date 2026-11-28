import 'dart:math';

import 'package:home/logic/house.dart';
import 'package:home/logic/reading.dart';

/// Capteurs d'une maison fictive : trois jours de relevés toutes les deux heures, sans donnée réelle.
List<Sensor> demoSensors() {
  final vStart = DateTime(2026, 11, 26);
  Sensor vBuild(String pName, double pBase, double pHumidity, double pSwing) => Sensor(
    name: pName,
    readings: [
      for (var vStep = 0; vStep < 36; vStep++)
        Reading(
          at: vStart.add(Duration(hours: vStep * 2)),
          temp: double.parse((pBase + pSwing * sin(vStep * pi / 6 - pi / 2)).toStringAsFixed(1)),
          humidity: (pHumidity + 6 * cos(vStep * pi / 6)).roundToDouble(),
        ),
    ],
  );

  return [
    vBuild('Salon', 20.5, 46, 1.2),
    vBuild('Chambre', 17.5, 58, 0.8),
    vBuild('Salle de bain', 21, 66, 2),
    vBuild('Cellier', 14, 72, 0.5),
  ];
}

/// Rangement des capteurs fictifs par pièce et par étage.
House demoHouse() => const House(
  places: {
    'Salon': SensorPlace(room: 'Salon', floor: 0),
    'Cellier': SensorPlace(room: 'Cellier', floor: 0),
    'Chambre': SensorPlace(room: 'Chambre', floor: 1),
    'Salle de bain': SensorPlace(room: 'Salle de bain', floor: 1),
  },
);
