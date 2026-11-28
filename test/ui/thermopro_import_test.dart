import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/sensors_screen.dart';

import '../support/localized.dart';
import '../support/menu.dart';

const _csv =
    'Horodatage pour chaque échantillon de fréquence chaque 1 min\n'
    'Date,Heure,Température_Celsius,Humidité_Relative(%)\n'
    '19/01/2025,10:31,17.7,35\n'
    '19/01/2025,10:45,-,-\n'
    '19/01/2025,11:00,16.3,36\n';

const _name = 'TempProSensor_Export_bureau_28112026.csv';

Future<SensorsController> _open(
  WidgetTester pTester,
  Future<({String name, String text})?> Function() pPick, {
  List<Sensor> pSensors = const [],
}) async {
  final vController = SensorsController(MemorySensorStore([...pSensors]));
  await vController.load();
  await pTester.pumpWidget(localized(SensorsScreen(controller: vController, pickCsv: pPick)));

  return vController;
}

void main() {
  testWidgets('un export ThermoPro devient un nouveau capteur nommé d\'après le fichier', (
    pTester,
  ) async {
    final vController = await _open(pTester, () async => (name: _name, text: _csv));

    await openMenuEntry(pTester, 'Importer un export ThermoPro');
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Nouveau capteur « Bureau »'));
    await pTester.pumpAndSettle();

    expect(vController.sensors.single.name, 'Bureau');
    expect(vController.sensors.single.readings, hasLength(2));
    expect(find.textContaining('2 relevés importés dans Bureau (1 lignes'), findsOneWidget);
  });

  testWidgets('l\'export peut aller dans un capteur existant', (pTester) async {
    final vController = await _open(
      pTester,
      () async => (name: _name, text: _csv),
      pSensors: [
        Sensor(
          name: 'TP357 (A1B2)',
          readings: [Reading(at: DateTime(2025, 2, 1), temp: 10, humidity: 50)],
        ),
      ],
    );

    await openMenuEntry(pTester, 'Importer un export ThermoPro');
    await pTester.pumpAndSettle();
    await pTester.tap(
      find.descendant(of: find.byType(SimpleDialog), matching: find.text('TP357 (A1B2)')),
    );
    await pTester.pumpAndSettle();

    expect(vController.sensors, hasLength(1));
    expect(vController.sensors.single.readings, hasLength(3));
  });

  testWidgets('un fichier qui n\'est pas un export est refusé', (pTester) async {
    final vController = await _open(pTester, () async => (name: 'x.csv', text: 'a,b'));

    await openMenuEntry(pTester, 'Importer un export ThermoPro');
    await pTester.pumpAndSettle();

    expect(find.text('Ce fichier n\'est pas un export de l\'appli ThermoPro.'), findsOneWidget);
    expect(vController.sensors, isEmpty);
  });

  testWidgets('un export sans mesure valide le dit, renoncer ne change rien', (pTester) async {
    const vEmpty = 'Date,Heure,Température_Celsius,Humidité_Relative(%)\n19/01/2025,10:45,-,-\n';
    final vController = await _open(pTester, () async => (name: _name, text: vEmpty));

    await openMenuEntry(pTester, 'Importer un export ThermoPro');
    await pTester.pumpAndSettle();
    expect(find.text('Aucun relevé valide dans ce fichier.'), findsOneWidget);
    expect(vController.sensors, isEmpty);
  });

  testWidgets('fermer le choix du capteur n\'importe rien', (pTester) async {
    final vController = await _open(pTester, () async => (name: _name, text: _csv));

    await openMenuEntry(pTester, 'Importer un export ThermoPro');
    await pTester.pumpAndSettle();
    await pTester.tapAt(const Offset(5, 5));
    await pTester.pumpAndSettle();

    expect(vController.sensors, isEmpty);
  });
}
