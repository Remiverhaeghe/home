import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/automations.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/plan_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/plan_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/rules_screen.dart';

import '../support/fake_daikin.dart';
import '../support/localized.dart';

void main() {
  late MemoryPlanStore vStore;
  late PlanController vPlan;

  Future<void> open(
    WidgetTester pTester, {
    List<AcUnit> pUnits = const [AcUnit(name: 'Salle de bain', host: '10.0.0.2')],
    List<AutoRule> pRules = const [],
  }) async {
    pTester.view.physicalSize = const Size(800, 1800);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    final vAc = AcController(MemoryAcStore(pUnits), FakeDaikinLink());
    await vAc.load();
    vStore = MemoryPlanStore(PlanSettings(rules: pRules));
    vPlan = PlanController(vStore, vAc, SensorsController(MemorySensorStore()));
    await vPlan.load();
    await pTester.pumpWidget(localized(RulesScreen(plan: vPlan, ac: vAc)));
  }

  testWidgets('sans climatisation, l\'écran invite à en ajouter une', (pTester) async {
    await open(pTester, pUnits: []);

    expect(find.textContaining('Ajoute d\'abord une climatisation'), findsOneWidget);
    expect(find.text('Ajouter une règle'), findsNothing);
  });

  testWidgets('sans règle, l\'écran donne un exemple', (pTester) async {
    await open(pTester);

    expect(find.textContaining('Aucune règle'), findsOneWidget);
  });

  testWidgets('ajouter une règle d\'humidité qui coupe la clim', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Ajouter une règle'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.widgetWithText(TextField, 'Seuil'), '70');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();

    final vRule = vStore.saved.rules.single;
    expect(vRule.name, 'Humidité > 70');
    expect(vRule.metric, AutoMetric.humidity);
    expect(vRule.action, AutoActionKind.powerOff);
    expect(find.text('Humidité > 70'), findsOneWidget);
    expect(find.textContaining('Salle de bain : Humidité au-dessus de 70'), findsOneWidget);
  });

  testWidgets('une règle de chauffage avec consigne et température sous un seuil', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Ajouter une règle'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Température'));
    await pTester.tap(find.text('sous'));
    await pTester.tap(find.text('Chaud'));
    await pTester.pump();
    await pTester.enterText(find.widgetWithText(TextField, 'Seuil'), '16');
    await pTester.enterText(find.widgetWithText(TextField, 'Consigne en °C (facultatif)'), '19');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();

    final vRule = vStore.saved.rules.single;
    expect(vRule.metric, AutoMetric.temperature);
    expect(vRule.side, AutoSide.below);
    expect(vRule.action, AutoActionKind.heat);
    expect(vRule.setpoint, 19);
  });

  testWidgets('un seuil absent ou hors plage est refusé avec un message', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Ajouter une règle'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pump();

    expect(find.text('Le seuil doit être un nombre.'), findsOneWidget);

    await pTester.enterText(find.widgetWithText(TextField, 'Seuil'), '150');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pump();

    expect(find.textContaining('hors de ce que le capteur mesure'), findsOneWidget);

    await pTester.tap(find.text('Chaud'));
    await pTester.pump();
    await pTester.enterText(find.widgetWithText(TextField, 'Seuil'), '60');
    await pTester.enterText(find.widgetWithText(TextField, 'Consigne en °C (facultatif)'), '50');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pump();

    expect(find.text('La consigne doit être entre 10 et 32 °C.'), findsOneWidget);
    expect(vStore.saved.rules, isEmpty);
  });

  testWidgets('avec plusieurs clims, on choisit celle de la règle', (pTester) async {
    await open(
      pTester,
      pUnits: const [
        AcUnit(name: 'Salon', host: '10.0.0.1'),
        AcUnit(name: 'Chambre', host: '10.0.0.2'),
      ],
    );

    await pTester.tap(find.text('Ajouter une règle'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Salon').last);
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Chambre').last);
    await pTester.pumpAndSettle();
    await pTester.enterText(find.widgetWithText(TextField, 'Seuil'), '65');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();

    expect(vStore.saved.rules.single.acHost, '10.0.0.2');
  });

  testWidgets('annuler le dialogue n\'ajoute rien, supprimer retire la règle', (pTester) async {
    await open(
      pTester,
      pRules: const [
        AutoRule(
          name: 'Bain',
          acHost: '10.0.0.2',
          metric: AutoMetric.humidity,
          side: AutoSide.above,
          threshold: 70,
          action: AutoActionKind.powerOff,
        ),
      ],
    );

    await pTester.tap(find.text('Ajouter une règle'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Annuler'));
    await pTester.pumpAndSettle();

    expect(vPlan.rules, hasLength(1));

    await pTester.tap(find.byTooltip('Supprimer la règle'));
    await pTester.pump();

    expect(vStore.saved.rules, isEmpty);
    expect(find.textContaining('Aucune règle'), findsOneWidget);
  });
}
