import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/house.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/house_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/house_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/rooms_screen.dart';

import '../support/localized.dart';

Sensor _sensor(String pName, double pTemp, double pHumidity) => Sensor(
  name: pName,
  readings: [Reading(at: DateTime(2026, 11, 28, 8), temp: pTemp, humidity: pHumidity)],
);

void main() {
  testWidgets('sans pièce nommée, l\'écran dit quoi faire', (pTester) async {
    final vSensors = SensorsController(MemorySensorStore([_sensor('a', 20, 50)]));
    await vSensors.load();
    final vHouse = HouseController(MemoryHouseStore(const House()));
    await vHouse.load();

    await pTester.pumpWidget(localized(RoomsScreen(sensors: vSensors, house: vHouse)));

    expect(find.textContaining('Range les capteurs dans des pièces'), findsOneWidget);
  });

  testWidgets('les pièces sont listées avec la plus fraîche et la plus humide', (pTester) async {
    final vSensors = SensorsController(
      MemorySensorStore([_sensor('a', 21, 45), _sensor('b', 16, 72)]),
    );
    await vSensors.load();
    final vHouse = HouseController(
      MemoryHouseStore(
        const House(
          places: {
            'a': SensorPlace(room: 'Salon', floor: 0),
            'b': SensorPlace(room: 'Chambre', floor: 1),
          },
        ),
      ),
    );
    await vHouse.load();

    await pTester.pumpWidget(localized(RoomsScreen(sensors: vSensors, house: vHouse)));

    expect(find.text('Chambre'), findsOneWidget);
    expect(find.textContaining('La plus fraîche'), findsOneWidget);
    expect(find.textContaining('La plus humide'), findsOneWidget);
    expect(find.text('16,0 °C · 72,0 %'), findsOneWidget);
    // Sans météo, la pièce humide n'a pas de conseil d'aération
    expect(find.text('Conseils'), findsNothing);
  });
}
