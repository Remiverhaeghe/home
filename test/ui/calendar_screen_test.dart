import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/house_calendar.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/plan_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/plan_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/calendar_screen.dart';

import '../support/fake_daikin.dart';
import '../support/localized.dart';

void main() {
  late MemoryPlanStore vStore;
  late PlanController vPlan;

  setUp(() {
    vStore = MemoryPlanStore();
    vPlan = PlanController(
      vStore,
      AcController(MemoryAcStore(), FakeDaikinLink()),
      SensorsController(MemorySensorStore()),
    );
  });

  Future<void> open(WidgetTester pTester) async {
    await vPlan.load();
    await pTester.pumpWidget(
      localized(CalendarScreen(plan: vPlan, clock: () => DateTime(2026, 12, 10))),
    );
    await pTester.pumpAndSettle();
  }

  testWidgets('le mois et ses jours s\'affichent', (pTester) async {
    await open(pTester);

    expect(find.text('décembre 2026'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('un jour choisi à la main est rangé, puis retiré', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('24'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Jour de repos'));
    await pTester.pumpAndSettle();

    expect(vStore.saved.calendar.overrides, {DateTime(2026, 12, 24): DayOverride.rest});

    await pTester.tap(find.text('24'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Selon le calendrier'));
    await pTester.pumpAndSettle();

    expect(vStore.saved.calendar.overrides, isEmpty);
  });

  testWidgets('fermer la boîte sans choisir ne change rien', (pTester) async {
    await open(pTester);
    await vPlan.setCalendar(HouseCalendar(overrides: {DateTime(2026, 12, 3): DayOverride.remote}));

    await pTester.tap(find.text('3'));
    await pTester.pumpAndSettle();
    await pTester.tapAt(const Offset(5, 5));
    await pTester.pumpAndSettle();

    expect(vStore.saved.calendar.overrides, hasLength(1));
  });

  testWidgets('le jour férié se dit dans la boîte du jour', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('25'));
    await pTester.pumpAndSettle();

    expect(find.text('Jour férié : Noël'), findsOneWidget);
  });

  testWidgets('la règle des fériés et les jours de télétravail se règlent', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Comme un samedi'));
    await pTester.pumpAndSettle();
    expect(vStore.saved.calendar.holidays, HolidayRule.saturday);

    await pTester.scrollUntilVisible(find.byType(FilterChip).first, 200);
    await pTester.tap(find.widgetWithText(FilterChip, 'mar.'));
    await pTester.pumpAndSettle();
    expect(vStore.saved.calendar.remoteWeekdays, {2});
  });

  testWidgets('on passe au mois suivant', (pTester) async {
    await open(pTester);

    await pTester.tap(find.byTooltip('Mois suivant'));
    await pTester.pumpAndSettle();

    expect(find.text('janvier 2027'), findsOneWidget);
  });
}
