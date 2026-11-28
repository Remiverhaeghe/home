import 'dart:convert';
import 'dart:typed_data';

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

  group('bilan en PDF', () {
    Future<(SensorsController, HouseController)> controllers() async {
      final vSensors = SensorsController(MemorySensorStore([_sensor('a', 21, 45)]));
      await vSensors.load();
      final vHouse = HouseController(
        MemoryHouseStore(const House(places: {'a': SensorPlace(room: 'Salon', floor: 0)})),
      );
      await vHouse.load();

      return (vSensors, vHouse);
    }

    testWidgets('sans moyen d\'enregistrer, il n\'y a pas de bouton', (pTester) async {
      final (vSensors, vHouse) = await controllers();

      await pTester.pumpWidget(localized(RoomsScreen(sensors: vSensors, house: vHouse)));

      expect(find.byTooltip('Exporter le bilan en PDF'), findsNothing);
    });

    testWidgets('le bouton enregistre un PDF nommé home-bilan.pdf', (pTester) async {
      final (vSensors, vHouse) = await controllers();
      String? vName;
      Uint8List? vBytes;

      await pTester.pumpWidget(
        localized(
          RoomsScreen(
            sensors: vSensors,
            house: vHouse,
            clock: () => DateTime(2026, 11, 28, 12),
            saveFile: (pName, pBytes) async {
              vName = pName;
              vBytes = pBytes;

              return true;
            },
          ),
        ),
      );
      await pTester.tap(find.byTooltip('Exporter le bilan en PDF'));
      await pTester.pump();

      expect(vName, 'home-bilan.pdf');
      expect(latin1.decode(vBytes!), startsWith('%PDF-1.4'));
      expect(find.text('Bilan enregistré.'), findsOneWidget);
    });

    testWidgets('renoncer à l\'enregistrement n\'affiche rien', (pTester) async {
      final (vSensors, vHouse) = await controllers();

      await pTester.pumpWidget(
        localized(
          RoomsScreen(sensors: vSensors, house: vHouse, saveFile: (_, _) async => false),
        ),
      );
      await pTester.tap(find.byTooltip('Exporter le bilan en PDF'));
      await pTester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('sans pièce rangée, le bouton est inactif', (pTester) async {
      final vSensors = SensorsController(MemorySensorStore([_sensor('a', 21, 45)]));
      await vSensors.load();
      final vHouse = HouseController(MemoryHouseStore(const House()));
      await vHouse.load();

      await pTester.pumpWidget(
        localized(RoomsScreen(sensors: vSensors, house: vHouse, saveFile: (_, _) async => true)),
      );

      expect(
        pTester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.picture_as_pdf_outlined)).onPressed,
        isNull,
      );
    });
  });
}
