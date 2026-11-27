import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/plan.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/plan_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/plan_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/schedule_screen.dart';

import '../support/fake_daikin.dart';
import '../support/localized.dart';

void main() {
  const vUnit = AcUnit(name: 'Salon', host: '192.168.1.20');
  late MemoryPlanStore vStore;
  late PlanController vPlan;
  TimeOfDay? vTime;

  Future<void> open(WidgetTester pTester, {List<ScheduleSlot> pSlots = const []}) async {
    pTester.view.physicalSize = const Size(800, 1600);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    vStore = MemoryPlanStore(
      PlanSettings(rooms: [Room(acHost: vUnit.host, schedule: pSlots)]),
    );
    vPlan = PlanController(
      vStore,
      AcController(MemoryAcStore([vUnit]), FakeDaikinLink()),
      SensorsController(MemorySensorStore()),
    );
    await vPlan.load();
    await pTester.pumpWidget(
      localized(ScheduleScreen(plan: vPlan, unit: vUnit, chooseStart: (_, _) async => vTime)),
    );
  }

  setUp(() => vTime = const TimeOfDay(hour: 22, minute: 30));

  testWidgets('sans plage, l\'écran explique quoi faire', (pTester) async {
    await open(pTester);

    expect(find.textContaining('Aucune plage'), findsOneWidget);
  });

  testWidgets('les plages sont rangées par heure avec leurs jours', (pTester) async {
    await open(
      pTester,
      pSlots: const [
        ScheduleSlot(weekdays: {1, 2, 3, 4, 5, 6, 7}, minute: 1350, profile: ProfileKind.night),
        ScheduleSlot(weekdays: {6, 7}, minute: 540, profile: ProfileKind.comfort),
      ],
    );

    final vTitles = pTester.widgetList<ListTile>(find.byType(ListTile)).toList();

    expect((vTitles.first.title! as Text).data, 'À 09:00 : Confort');
    expect((vTitles.last.title! as Text).data, 'À 22:30 : Nuit');
    expect(find.text('Tous les jours'), findsOneWidget);
    expect(find.text('sam. dim.'), findsOneWidget);
  });

  testWidgets('supprimer une plage l\'enlève du planning enregistré', (pTester) async {
    await open(
      pTester,
      pSlots: const [ScheduleSlot(weekdays: {1}, minute: 420, profile: ProfileKind.comfort)],
    );

    await pTester.tap(find.byTooltip('Supprimer la plage'));
    await pTester.pump();

    expect(vStore.saved.rooms.single.schedule, isEmpty);
    expect(find.textContaining('Aucune plage'), findsOneWidget);
  });

  testWidgets('ajouter une plage : heure, profil et jours choisis', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Ajouter une plage'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Nuit'));
    await pTester.tap(find.text('sam.'));
    await pTester.tap(find.text('dim.'));
    await pTester.pump();
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();

    final vSlot = vStore.saved.rooms.single.schedule.single;
    expect(vSlot.minute, 22 * 60 + 30);
    expect(vSlot.profile, ProfileKind.night);
    expect(vSlot.weekdays, {1, 2, 3, 4, 5});
  });

  testWidgets('renoncer à l\'heure ou au dialogue n\'ajoute rien', (pTester) async {
    await open(pTester);
    vTime = null;

    await pTester.tap(find.text('Ajouter une plage'));
    await pTester.pumpAndSettle();

    expect(vStore.saved.rooms.single.schedule, isEmpty);

    vTime = const TimeOfDay(hour: 8, minute: 0);
    await pTester.tap(find.text('Ajouter une plage'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Annuler'));
    await pTester.pumpAndSettle();

    expect(vStore.saved.rooms.single.schedule, isEmpty);
  });

  testWidgets('sans aucun jour, on ne peut pas enregistrer', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Ajouter une plage'));
    await pTester.pumpAndSettle();
    for (final vDay in ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.']) {
      await pTester.tap(find.text(vDay));
    }
    await pTester.pump();

    expect(pTester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enregistrer')).onPressed, isNull);
  });
}
