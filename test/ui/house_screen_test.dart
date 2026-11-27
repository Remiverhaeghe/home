import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/house.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/house_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/house_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/house_screen.dart';
import 'package:home/ui/sensors_screen.dart';

import '../support/localized.dart';

void main() {
  testWidgets('le lieu se saisit avec des virgules et s\'enregistre', (pTester) async {
    final vStore = MemoryHouseStore();
    await pTester.pumpWidget(localized(HouseScreen(controller: HouseController(vStore))));

    await pTester.enterText(find.widgetWithText(TextField, 'Lieu (ville ou adresse)'), 'Lyon');
    await pTester.enterText(find.widgetWithText(TextField, 'Latitude'), '45,76');
    await pTester.enterText(find.widgetWithText(TextField, 'Longitude'), '4,83');
    await pTester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await pTester.pumpAndSettle();

    expect(vStore.saved.location?.latitude, 45.76);
    expect(find.text('Lieu enregistré.'), findsOneWidget);
  });

  testWidgets('des coordonnées fausses sont signalées', (pTester) async {
    final vStore = MemoryHouseStore();
    await pTester.pumpWidget(localized(HouseScreen(controller: HouseController(vStore))));

    await pTester.enterText(find.widgetWithText(TextField, 'Lieu (ville ou adresse)'), 'Lyon');
    await pTester.enterText(find.widgetWithText(TextField, 'Latitude'), '95');
    await pTester.enterText(find.widgetWithText(TextField, 'Longitude'), '4');
    await pTester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await pTester.pumpAndSettle();

    expect(find.textContaining('Coordonnées invalides'), findsOneWidget);
    expect(vStore.saved.location, isNull);
  });

  testWidgets('la liste des capteurs est groupée par niveau', (pTester) async {
    final vSensors = SensorsController(
      MemorySensorStore([const Sensor(name: 'Haut'), const Sensor(name: 'Dehors')]),
    );
    await vSensors.load();
    final vHouse = HouseController(
      MemoryHouseStore(
        const House()
            .withPlace('Haut', const SensorPlace(room: 'Chambre', floor: 1))
            .withPlace('Dehors', const SensorPlace(outdoor: true)),
      ),
    );
    await vHouse.load();

    await pTester.pumpWidget(
      localized(SensorsScreen(controller: vSensors, houseController: vHouse)),
    );
    await pTester.pumpAndSettle();

    expect(find.text('Premier étage'), findsOneWidget);
    expect(find.text('Extérieur'), findsWidgets);
    expect(find.text('Chambre · Premier étage'), findsOneWidget);
  });

  testWidgets('l\'emplacement se choisit depuis le détail du capteur', (pTester) async {
    final vSensors = SensorsController(MemorySensorStore([const Sensor(name: 'Haut')]));
    await vSensors.load();
    final vStore = MemoryHouseStore();
    final vHouse = HouseController(vStore);

    await pTester.pumpWidget(
      localized(SensorsScreen(controller: vSensors, houseController: vHouse)),
    );
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Haut'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.byTooltip('Emplacement'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.widgetWithText(TextField, 'Pièce'), 'Salon');
    await pTester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await pTester.pumpAndSettle();

    expect(vStore.saved.placeOf('Haut').room, 'Salon');
  });
}
