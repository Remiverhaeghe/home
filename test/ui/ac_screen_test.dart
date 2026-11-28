import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/ac_screen.dart';
import 'package:home/ui/sensors_screen.dart';

import '../support/fake_daikin.dart';
import '../support/localized.dart';
import '../support/menu.dart';

void main() {
  const vHost = '192.168.1.20';
  late FakeDaikinLink vLink;
  late MemoryAcStore vStore;
  late AcController vController;
  late SensorsController vSensors;

  setUp(() {
    vLink = FakeDaikinLink()
      ..names[vHost] = 'Salon'
      ..states[vHost] = FakeDaikinLink.coolingAt22();
    vStore = MemoryAcStore();
    vController = AcController(vStore, vLink);
    vSensors = SensorsController(
      MemorySensorStore([
        Sensor(
          name: 'TP357 (1A2B)',
          readings: [Reading(at: DateTime(2026, 12, 1, 8), temp: 21.5, humidity: 48)],
        ),
      ]),
    );
  });

  Future<void> open(WidgetTester pTester) async {
    await vSensors.load();
    await vController.load();
    await pTester.pumpWidget(localized(AcScreen(controller: vController, sensors: vSensors)));
    await pTester.pumpAndSettle();
  }

  testWidgets('sans climatisation, l\'écran invite à en ajouter', (pTester) async {
    await open(pTester);

    expect(find.textContaining('Aucune climatisation pour l'), findsOneWidget);
  });

  testWidgets('une carte montre l\'état : marche, mode, consigne et températures', (pTester) async {
    vStore.saved = [const AcUnit(name: 'Salon', host: vHost)];

    await open(pTester);

    expect(find.text('Salon'), findsOneWidget);
    expect(pTester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(pTester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Froid')).selected, isTrue);
    expect(find.text('Consigne 22,0 °C'), findsOneWidget);
    expect(find.text('Température mesurée 23,5 °C'), findsOneWidget);
    expect(find.text('Extérieur 8,0 °C'), findsOneWidget);
  });

  testWidgets('une climatisation injoignable le dit', (pTester) async {
    vStore.saved = [const AcUnit(name: 'Salon', host: vHost)];
    vLink.unreachable.add(vHost);

    await open(pTester);

    expect(find.text('Injoignable'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('couper, changer de mode et de consigne envoient les commandes', (pTester) async {
    vStore.saved = [const AcUnit(name: 'Salon', host: vHost)];
    await open(pTester);

    await pTester.tap(find.byType(Switch));
    await pTester.pumpAndSettle();
    expect(vLink.written.last.$2.power, isFalse);

    await pTester.tap(find.text('Chaud'));
    await pTester.pumpAndSettle();
    expect(vLink.written.last.$2.modeCode, '4');

    await pTester.tap(find.byTooltip('Monter la consigne'));
    await pTester.pumpAndSettle();
    expect(vLink.written.last.$2.setpoint, '22.5');

    await pTester.tap(find.byTooltip('Baisser la consigne'));
    await pTester.pumpAndSettle();
    expect(vLink.written.last.$2.setpoint, '22.0');
  });

  testWidgets('une commande refusée le dit', (pTester) async {
    vStore.saved = [const AcUnit(name: 'Salon', host: vHost)];
    await open(pTester);
    vLink.refuseWrites = true;

    await pTester.tap(find.byType(Switch));
    await pTester.pumpAndSettle();

    expect(find.text('La climatisation n\'a pas pris la commande.'), findsOneWidget);
  });

  testWidgets('en mode sec, la consigne est absente et le mode affiché', (pTester) async {
    vStore.saved = [const AcUnit(name: 'Salon', host: vHost)];
    vLink.states[vHost] = DaikinStateDry.build();

    await open(pTester);

    expect(find.text('Pas de consigne dans ce mode'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Sec'), findsOneWidget);
  });

  testWidgets('relier un capteur affiche sa dernière mesure', (pTester) async {
    vStore.saved = [const AcUnit(name: 'Salon', host: vHost)];
    await open(pTester);
    expect(find.textContaining('au capteur'), findsNothing);

    await pTester.tap(find.byType(DropdownButton<String?>));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('TP357 (1A2B)').last);
    await pTester.pumpAndSettle();

    expect(vStore.saved.single.sensorName, 'TP357 (1A2B)');
    expect(find.text('21,5 °C et 48,0 % au capteur'), findsOneWidget);
  });

  testWidgets('retirer demande confirmation', (pTester) async {
    vStore.saved = [const AcUnit(name: 'Salon', host: vHost)];
    await open(pTester);

    await pTester.tap(find.byTooltip('Retirer'));
    await pTester.pumpAndSettle();
    expect(find.text('Retirer « Salon » de la liste ?'), findsOneWidget);
    await pTester.tap(find.text('Annuler'));
    await pTester.pumpAndSettle();
    expect(vController.units, hasLength(1));

    await pTester.tap(find.byTooltip('Retirer'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.widgetWithText(FilledButton, 'Retirer'));
    await pTester.pumpAndSettle();
    expect(vController.units, isEmpty);
  });

  testWidgets('ajouter par adresse', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Ajouter par adresse'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.byType(TextField).first, vHost);
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();

    expect(vController.units.single.name, 'Salon');
    expect(find.text('Salon'), findsOneWidget);
  });

  testWidgets('une adresse refusée est expliquée', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Ajouter par adresse'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.byType(TextField).first, '8.8.8.8');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();

    expect(find.textContaining('pas sur un réseau de maison'), findsOneWidget);
    expect(vController.units, isEmpty);
  });

  testWidgets('annuler l\'ajout ne fait rien', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Ajouter par adresse'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Annuler'));
    await pTester.pumpAndSettle();

    expect(vController.units, isEmpty);
  });

  testWidgets('la recherche propose les modules trouvés', (pTester) async {
    vLink.found.add(vHost);
    await open(pTester);

    await pTester.tap(find.byTooltip('Chercher sur le réseau'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text(vHost));
    await pTester.pumpAndSettle();

    expect(vController.units.single.host, vHost);
  });

  testWidgets('une recherche sans résultat le dit', (pTester) async {
    await open(pTester);

    await pTester.tap(find.byTooltip('Chercher sur le réseau'));
    await pTester.pumpAndSettle();

    expect(find.textContaining('Aucune climatisation trouvée'), findsOneWidget);
  });

  testWidgets('la recherche ne propose pas une climatisation déjà connue', (pTester) async {
    vStore.saved = [const AcUnit(name: 'Salon', host: vHost)];
    vLink.found.add(vHost);
    await open(pTester);

    await pTester.tap(find.byTooltip('Chercher sur le réseau'));
    await pTester.pumpAndSettle();

    expect(find.textContaining('Aucune climatisation trouvée'), findsOneWidget);
  });

  testWidgets('le bouton des capteurs ouvre les climatisations quand elles sont fournies', (
    pTester,
  ) async {
    await pTester.pumpWidget(
      localized(SensorsScreen(controller: vSensors, acController: vController)),
    );

    await openMenuEntry(pTester, 'Climatisations');
    await pTester.pumpAndSettle();

    expect(find.textContaining('Aucune climatisation pour l'), findsOneWidget);
  });

  testWidgets('sans climatisations fournies, le bouton n\'apparaît pas', (pTester) async {
    await pTester.pumpWidget(localized(SensorsScreen(controller: vSensors)));

    expect(await menuHas(pTester, 'Climatisations'), isFalse);
  });
}
