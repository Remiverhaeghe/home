import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/sensors_screen.dart';

import '../support/localized.dart';
import '../support/sensors.dart';

void main() {
  testWidgets('sans capteur, l\'écran invite à importer un fichier', (pTester) async {
    final vController = SensorsController(MemorySensorStore());

    await pTester.pumpWidget(localized(SensorsScreen(controller: vController)));

    expect(find.textContaining('Aucun capteur pour l'), findsOneWidget);
    expect(find.text('Importer un fichier'), findsOneWidget);
  });

  testWidgets('une carte montre le dernier relevé et le niveau de l\'air', (pTester) async {
    final vController = SensorsController(MemorySensorStore([bathroomSensor()]));
    await vController.load();

    await pTester.pumpWidget(localized(SensorsScreen(controller: vController)));

    expect(find.text('Salle de bain'), findsOneWidget);
    expect(find.text('19,0 °C'), findsOneWidget);
    expect(find.text('55,0 %'), findsOneWidget);
    expect(find.text('Air confortable'), findsOneWidget);
    expect(find.textContaining('Point de rosée'), findsOneWidget);
  });

  testWidgets('un air humide ou sec est signalé', (pTester) async {
    final vController = SensorsController(
      MemorySensorStore([
        Sensor(
          name: 'Cave',
          readings: [Reading(at: DateTime(2026, 12, 1, 8), temp: 12, humidity: 80)],
        ),
        Sensor(
          name: 'Bureau',
          readings: [Reading(at: DateTime(2026, 12, 1, 8), temp: 21, humidity: 30)],
        ),
      ]),
    );
    await vController.load();

    await pTester.pumpWidget(localized(SensorsScreen(controller: vController)));

    expect(find.text('Air humide'), findsOneWidget);
    expect(find.text('Air sec'), findsOneWidget);
  });

  testWidgets('un capteur sans relevé le dit', (pTester) async {
    final vController = SensorsController(MemorySensorStore([const Sensor(name: 'Cave')]));
    await vController.load();

    await pTester.pumpWidget(localized(SensorsScreen(controller: vController)));

    expect(find.text('Aucun relevé'), findsOneWidget);
  });

  testWidgets('importer un fichier ajoute la carte et le dit', (pTester) async {
    final vController = SensorsController(MemorySensorStore());
    await pTester.pumpWidget(
      localized(SensorsScreen(controller: vController, pickFile: () async => exchangeSample)),
    );

    await pTester.tap(find.text('Importer un fichier'));
    await pTester.pumpAndSettle();

    expect(find.text('Salle de bain'), findsOneWidget);
    expect(find.text('1 capteur importé'), findsOneWidget);
  });

  testWidgets('un fichier refusé affiche le motif', (pTester) async {
    final vController = SensorsController(MemorySensorStore());
    await pTester.pumpWidget(
      localized(SensorsScreen(controller: vController, pickFile: () async => 'pas du json')),
    );

    await pTester.tap(find.text('Importer un fichier'));
    await pTester.pumpAndSettle();

    expect(find.text('Ce fichier n\'est pas un fichier d\'échange JSON.'), findsOneWidget);
  });

  testWidgets('renoncer au choix du fichier ne change rien', (pTester) async {
    final vController = SensorsController(MemorySensorStore());
    await pTester.pumpWidget(
      localized(SensorsScreen(controller: vController, pickFile: () async => null)),
    );

    await pTester.tap(find.text('Importer un fichier'));
    await pTester.pumpAndSettle();

    expect(vController.sensors, isEmpty);
    expect(find.textContaining('importé'), findsNothing);
  });
}
