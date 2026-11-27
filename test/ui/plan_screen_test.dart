import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/plan_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/plan_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/plan_screen.dart';

import '../support/fake_daikin.dart';
import '../support/localized.dart';

void main() {
  const vHost = '192.168.1.20';
  final vNow = DateTime(2026, 12, 1, 12);
  late MemoryPlanStore vStore;
  late PlanController vPlan;
  late AcController vAc;
  late SensorsController vSensors;
  DateTimeRange? vChosen;

  Future<void> open(WidgetTester pTester, {List<AcUnit>? pUnits, double pTemp = 20}) async {
    vAc = AcController(MemoryAcStore(pUnits ?? [const AcUnit(name: 'Salon', host: vHost)]), FakeDaikinLink());
    vSensors = SensorsController(
      MemorySensorStore([
        Sensor(name: 'Salon', readings: [Reading(at: vNow, temp: pTemp, humidity: 50)]),
      ]),
    );
    vStore = MemoryPlanStore();
    vPlan = PlanController(vStore, vAc, vSensors);
    await vAc.load();
    await vSensors.load();
    await pTester.pumpWidget(
      localized(
        PlanScreen(
          plan: vPlan,
          ac: vAc,
          sensors: vSensors,
          pickRange: (_) async => vChosen,
          clock: () => vNow,
        ),
      ),
    );
  }

  setUp(() => vChosen = null);

  testWidgets('sans climatisation, l\'écran invite à en ajouter une', (pTester) async {
    await open(pTester, pUnits: []);

    expect(find.textContaining('Ajoute d\'abord une climatisation'), findsOneWidget);
  });

  testWidgets('monter une température l\'enregistre avec le planning par défaut', (pTester) async {
    await open(pTester);
    expect(find.text('Confort : 21,0 °C'), findsOneWidget);

    await pTester.tap(find.byTooltip('Monter Confort'));
    await pTester.pump();
    await pTester.tap(find.byTooltip('Baisser Nuit'));
    await pTester.pump();

    expect(find.text('Confort : 21,5 °C'), findsOneWidget);
    expect(find.text('Nuit : 16,5 °C'), findsOneWidget);
    expect(vStore.saved.rooms.single.targets.comfort, 21.5);
    expect(vStore.saved.rooms.single.schedule, isNotEmpty);
  });

  testWidgets('une température reste entre 10 et 30 °C', (pTester) async {
    await open(pTester);
    vPlan.setRoom(
      const Room(
        acHost: vHost,
        targets: RoomTargets(comfort: 30, night: 10),
        schedule: defaultSchedule,
      ),
    );
    await pTester.pump();

    await pTester.tap(find.byTooltip('Monter Confort'));
    await pTester.pump();
    await pTester.tap(find.byTooltip('Baisser Nuit'));
    await pTester.pump();

    expect(vStore.saved.rooms.single.targets.comfort, 30);
    expect(vStore.saved.rooms.single.targets.night, 10);
  });

  testWidgets('programmer puis annuler une absence', (pTester) async {
    await open(pTester);
    vChosen = DateTimeRange(start: DateTime(2026, 12, 18), end: DateTime(2026, 12, 27));

    await pTester.tap(find.text('Programmer une absence'));
    await pTester.pump();

    expect(vStore.saved.vacation?.from, DateTime(2026, 12, 18));
    expect(vStore.saved.vacation?.until, DateTime(2026, 12, 28));
    expect(find.textContaining('Absent du'), findsOneWidget);

    await pTester.tap(find.text('Annuler l\'absence'));
    await pTester.pump();

    expect(vStore.saved.vacation, isNull);
    expect(find.text('Programmer une absence'), findsOneWidget);
  });

  testWidgets('renoncer au choix des dates ne programme rien', (pTester) async {
    await open(pTester);

    await pTester.tap(find.text('Programmer une absence'));
    await pTester.pump();

    expect(vStore.saved.vacation, isNull);
  });

  testWidgets('une alerte de gel est affichée', (pTester) async {
    await open(pTester, pTemp: 3);

    expect(find.textContaining('risque de gel'), findsOneWidget);
    expect(find.text('Aucune alerte.'), findsNothing);
  });

  testWidgets('sans alerte, l\'écran le dit', (pTester) async {
    await open(pTester);

    expect(find.text('Aucune alerte.'), findsOneWidget);
  });
}
