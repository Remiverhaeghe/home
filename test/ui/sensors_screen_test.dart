import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/climate_exchange.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/error_log_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/sensors_screen.dart';

import '../support/fake_link.dart';
import '../support/localized.dart';
import '../support/sensors.dart';
import '../support/menu.dart';

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
    expect(find.textContaining('Condensation sous'), findsOneWidget);
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

  testWidgets('le bouton Bluetooth ouvre les capteurs à portée', (pTester) async {
    final vController = SensorsController(MemorySensorStore());
    await pTester.pumpWidget(
      localized(SensorsScreen(controller: vController, link: FakeTp357Link())),
    );

    await pTester.tap(find.byTooltip('Capteurs à portée'));
    await pTester.pumpAndSettle();

    expect(find.text('Recherche des capteurs TP357…'), findsOneWidget);
  });

  testWidgets('la barre ne garde que l\'actualisation et le Bluetooth, le reste est dans Plus', (
    pTester,
  ) async {
    final vController = SensorsController(MemorySensorStore());
    await pTester.pumpWidget(localized(SensorsScreen(controller: vController)));

    expect(find.byTooltip('Actualiser les capteurs'), findsOneWidget);
    expect(find.byTooltip('Capteurs à portée'), findsOneWidget);
    expect(find.byTooltip('Importer un export ThermoPro'), findsNothing);
    expect(await menuHas(pTester, 'Importer un export ThermoPro'), isTrue);
  });

  testWidgets('le bouton À propos n\'apparaît qu\'avec un journal et ouvre l\'écran', (
    pTester,
  ) async {
    final vController = SensorsController(MemorySensorStore());
    await pTester.pumpWidget(localized(SensorsScreen(controller: vController)));
    expect(await menuHas(pTester, 'À propos'), isFalse);

    await pTester.pumpWidget(
      localized(SensorsScreen(controller: vController, errorLog: MemoryErrorLogStore())),
    );
    await openMenuEntry(pTester, 'À propos');
    await pTester.pumpAndSettle();

    expect(find.text('À propos de Home'), findsOneWidget);
  });

  group('export pour Atelier', () {
    testWidgets('le bouton est inactif sans capteur', (pTester) async {
      final vController = SensorsController(MemorySensorStore());

      await pTester.pumpWidget(localized(SensorsScreen(controller: vController)));
      await pTester.tap(find.byTooltip('Plus d\'options'));
      await pTester.pumpAndSettle();

      final vItem = pTester.widget<PopupMenuItem<int>>(
        find.widgetWithText(PopupMenuItem<int>, 'Exporter pour Atelier'),
      );
      expect(vItem.enabled, isFalse);
    });

    testWidgets('le fichier d\'échange de tous les capteurs est proposé à l\'enregistrement', (
      pTester,
    ) async {
      final vController = SensorsController(MemorySensorStore([bathroomSensor()]));
      await vController.load();
      String? vName;
      Uint8List? vBytes;

      await pTester.pumpWidget(
        localized(
          SensorsScreen(
            controller: vController,
            saveFile: (pName, pBytes) async {
              vName = pName;
              vBytes = pBytes;

              return true;
            },
          ),
        ),
      );
      await openMenuEntry(pTester, 'Exporter pour Atelier');
      await pTester.pump();

      expect(vName, 'home-climat.json');
      expect(parseExchange(utf8.decode(vBytes!)).single.name, 'Salle de bain');
      expect(find.textContaining('Ouvre-le dans Atelier'), findsOneWidget);
    });

    testWidgets('renoncer à l\'enregistrement n\'affiche rien', (pTester) async {
      final vController = SensorsController(MemorySensorStore([bathroomSensor()]));
      await vController.load();

      await pTester.pumpWidget(
        localized(SensorsScreen(controller: vController, saveFile: (_, _) async => false)),
      );
      await openMenuEntry(pTester, 'Exporter pour Atelier');
      await pTester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
