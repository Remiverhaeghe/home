import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/boost.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/house_calendar.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/pellet.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/pellet_controller.dart';
import 'package:home/state/plan_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/pellet_store.dart';
import 'package:home/storage/plan_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/plan_scenarios_section.dart';

import '../support/fake_daikin.dart';
import '../support/fake_pellet.dart';
import '../support/localized.dart';

const _stove = PelletStove(name: 'Poêle', host: '192.168.1.60', serial: 'S', password: 'P');

void main() {
  final vNow = DateTime(2026, 12, 7, 18, 30);
  late PlanController vPlan;
  late FakePelletLink vPelletLink;
  late PelletController vPellet;
  DateTime? vPicked;

  Future<void> open(WidgetTester pTester, {bool pWithStove = true}) async {
    pTester.view.physicalSize = const Size(900, 1200);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    final vAc = AcController(MemoryAcStore(), FakeDaikinLink());
    final vSensors = SensorsController(MemorySensorStore());
    vPlan = PlanController(MemoryPlanStore(), vAc, vSensors);
    vPelletLink = FakePelletLink();
    vPellet = PelletController(MemoryPelletStore(pWithStove ? _stove : null), vPelletLink);
    await vPellet.load();
    await pTester.pumpWidget(
      localized(
        Scaffold(
          body: ListenableBuilder(
            listenable: vPlan,
            builder: (_, _) => ScenariosSection(
              plan: vPlan,
              clock: () => vNow,
              pellet: vPellet,
              pickDay: (_) async => vPicked,
            ),
          ),
        ),
      ),
    );
  }

  setUp(() => vPicked = DateTime(2026, 12, 12));

  testWidgets('Départ programme l\'absence, arrête le poêle et propose le retour', (pTester) async {
    await open(pTester);

    await pTester.tap(find.byKey(const Key('scenario-leave')));
    await pTester.pumpAndSettle();

    expect(vPlan.vacation!.until, DateTime(2026, 12, 12));
    expect(vPelletLink.powers, [false]);
    expect(find.byKey(const Key('scenario-back')), findsOneWidget);
    expect(find.byKey(const Key('scenario-leave')), findsNothing);
  });

  testWidgets('sans poêle, Départ n\'envoie aucun ordre au poêle', (pTester) async {
    await open(pTester, pWithStove: false);

    await pTester.tap(find.byKey(const Key('scenario-leave')));
    await pTester.pumpAndSettle();

    expect(vPlan.vacation, isNotNull);
    expect(vPelletLink.powers, isEmpty);
  });

  testWidgets('annuler le choix du jour ne change rien', (pTester) async {
    vPicked = null;
    await open(pTester);

    await pTester.tap(find.byKey(const Key('scenario-leave')));
    await pTester.pumpAndSettle();

    expect(vPlan.vacation, isNull);
    expect(vPelletLink.powers, isEmpty);
  });

  testWidgets('Retour annule l\'absence', (pTester) async {
    await open(pTester);
    await pTester.tap(find.byKey(const Key('scenario-leave')));
    await pTester.pumpAndSettle();

    await pTester.tap(find.byKey(const Key('scenario-back')));
    await pTester.pumpAndSettle();

    expect(vPlan.vacation, isNull);
    expect(find.byKey(const Key('scenario-leave')), findsOneWidget);
  });

  testWidgets('le télétravail d\'aujourd\'hui se coche et se décoche', (pTester) async {
    await open(pTester);
    expect(pTester.widget<FilterChip>(find.byKey(const Key('scenario-remote'))).selected, isFalse);

    await pTester.tap(find.byKey(const Key('scenario-remote')));
    await pTester.pumpAndSettle();

    expect(vPlan.calendar.overrides[DateTime(2026, 12, 7)], DayOverride.remote);
    expect(pTester.widget<FilterChip>(find.byKey(const Key('scenario-remote'))).selected, isTrue);

    await pTester.tap(find.byKey(const Key('scenario-remote')));
    await pTester.pumpAndSettle();

    expect(pTester.widget<FilterChip>(find.byKey(const Key('scenario-remote'))).selected, isFalse);
  });

  testWidgets('Nuit règle chaque pièce sur sa température de nuit jusqu\'au matin', (pTester) async {
    await open(pTester);
    await vPlan.setRoom(const Room(acHost: '192.168.1.20', targets: RoomTargets(night: 16)));
    await vPlan.setRoom(const Room(acHost: '192.168.1.21'));
    await pTester.pump();

    await pTester.tap(find.byKey(const Key('scenario-night')));
    await pTester.pumpAndSettle();

    final vBoost = vPlan.boostOf('192.168.1.20', vNow)!;
    expect(vBoost.kind, BoostKind.night);
    expect(vBoost.temp, 16);
    expect(vBoost.until, DateTime(2026, 12, 8, 7));
    expect(vPlan.boostOf('192.168.1.21', vNow)!.temp, 17);
    expect(pTester.widget<FilterChip>(find.byKey(const Key('scenario-night'))).selected, isTrue);

    await pTester.tap(find.byKey(const Key('scenario-night')));
    await pTester.pumpAndSettle();

    expect(vPlan.boostOf('192.168.1.20', vNow), isNull);
    expect(pTester.widget<FilterChip>(find.byKey(const Key('scenario-night'))).selected, isFalse);
  });
}
