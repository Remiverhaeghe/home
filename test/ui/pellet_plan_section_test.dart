import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/pellet.dart';
import 'package:home/logic/pellet_runs.dart';
import 'package:home/state/pellet_controller.dart';
import 'package:home/storage/pellet_runs_store.dart';
import 'package:home/storage/pellet_store.dart';
import 'package:home/ui/pellet_plan_section.dart';

import '../support/fake_pellet.dart';
import '../support/localized.dart';

const _stove = PelletStove(name: 'Poêle', host: '192.168.1.60', serial: 'S', password: 'P');
final _now = DateTime(2026, 12, 7, 12);

void main() {
  late MemoryPelletRunsStore vRunsStore;

  Future<PelletController> open(
    WidgetTester pTester, {
    PelletRuns pRuns = const PelletRuns(),
    TimePicker pPick = pickStopTime,
  }) async {
    pTester.view.physicalSize = const Size(1200, 3000);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    vRunsStore = MemoryPelletRunsStore(pRuns);
    final vController = PelletController(
      MemoryPelletStore(_stove),
      FakePelletLink(),
      runsStore: vRunsStore,
      clock: () => _now,
    );
    await vController.load();
    await pTester.pumpWidget(
      localized(Scaffold(body: PelletPlanSection(controller: vController, clock: () => _now, pickTime: pPick))),
    );

    return vController;
  }

  testWidgets('sans stock ni arrêt, la section invite à les donner', (pTester) async {
    await open(pTester);

    expect(find.textContaining('Donne le nombre de sacs'), findsOneWidget);
    expect(find.text('Aucun arrêt programmé.'), findsOneWidget);
  });

  testWidgets('un stock sans débit demande le débit', (pTester) async {
    await open(
      pTester,
      pRuns: PelletRuns(stockBags: 5, stockAt: DateTime(2026, 12, 1)),
    );

    expect(find.textContaining('Donne aussi le débit'), findsOneWidget);
  });

  testWidgets('le stock restant et l\'autonomie sont montrés, le stock bas est signalé', (
    pTester,
  ) async {
    await open(
      pTester,
      pRuns: PelletRuns(
        minutesByDay: const {'2026-12-05': 240, '2026-12-07': 120, '2026-12-01': 120},
        kgPerHour: 1.5,
        bagKg: 15,
        stockBags: 1,
        stockAt: DateTime(2026, 12, 1, 9),
      ),
    );

    expect(find.text('Il reste environ 0,2 sacs.'), findsOneWidget);
    expect(find.textContaining('Autonomie : environ 2 jours'), findsOneWidget);
    expect(find.textContaining('Stock bas'), findsOneWidget);
  });

  testWidgets('compter le stock l\'enregistre, effacer le retire', (pTester) async {
    final vController = await open(pTester);

    await pTester.tap(find.text('Compter le stock'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.byType(TextField), '4,5');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();
    expect(vRunsStore.saved.stockBags, 4.5);

    await pTester.tap(find.text('Compter le stock'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Effacer'));
    await pTester.pumpAndSettle();
    expect(vController.runs.stockBags, isNull);
  });

  testWidgets('une saisie illisible ou annulée ne change rien', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Compter le stock'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.byType(TextField), 'abc');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();
    expect(vRunsStore.saved.stockBags, isNull);

    await pTester.tap(find.text('Compter le stock'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Annuler'));
    await pTester.pumpAndSettle();
    expect(vRunsStore.saved.stockBags, isNull);
  });

  testWidgets('l\'arrêt programmé se choisit, s\'affiche et se retire', (pTester) async {
    await open(pTester, pPick: (_, _) async => const TimeOfDay(hour: 22, minute: 30));

    await pTester.tap(find.text('Choisir l\'heure'));
    await pTester.pumpAndSettle();
    expect(vRunsStore.saved.stopAtMinute, 22 * 60 + 30);
    expect(find.text('Le poêle est éteint chaque soir à 22:30.'), findsOneWidget);

    await pTester.tap(find.text('Retirer'));
    await pTester.pumpAndSettle();
    expect(vRunsStore.saved.stopAtMinute, isNull);
  });

  testWidgets('renoncer au choix de l\'heure ne programme rien', (pTester) async {
    await open(pTester, pPick: (_, _) async => null);

    await pTester.tap(find.text('Choisir l\'heure'));
    await pTester.pumpAndSettle();

    expect(vRunsStore.saved.stopAtMinute, isNull);
  });
}
