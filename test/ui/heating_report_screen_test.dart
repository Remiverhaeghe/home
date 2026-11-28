import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/heating_costs.dart';
import 'package:home/logic/pellet.dart';
import 'package:home/logic/pellet_runs.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/pellet_controller.dart';
import 'package:home/storage/ac_runs_store.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/pellet_runs_store.dart';
import 'package:home/storage/pellet_store.dart';
import 'package:home/ui/heating_report_screen.dart';

import '../support/fake_daikin.dart';
import '../support/fake_pellet.dart';
import '../support/localized.dart';

const _host = '192.168.1.20';
final _now = DateTime(2026, 12, 7, 12);

void main() {
  late MemoryAcRunsStore vRunsStore;

  Future<AcController> controller({List<AcUnit>? pUnits, AcRuns? pRuns}) async {
    vRunsStore = MemoryAcRunsStore(pRuns ?? const AcRuns());
    final vAc = AcController(
      MemoryAcStore(pUnits ?? [const AcUnit(name: 'Salon', host: _host)]),
      FakeDaikinLink(),
      runsStore: vRunsStore,
    );
    await vAc.load();

    return vAc;
  }

  Future<void> open(WidgetTester pTester, AcController pAc, {PelletController? pPellet}) async {
    pTester.view.physicalSize = const Size(1200, 3000);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    await pTester.pumpWidget(
      localized(HeatingReportScreen(ac: pAc, pellet: pPellet, clock: () => _now)),
    );
  }

  testWidgets('sans appareil, l\'écran invite à en ajouter', (pTester) async {
    final vAc = await controller(pUnits: const []);

    await open(pTester, vAc);

    expect(find.textContaining('Ajoute une climatisation'), findsOneWidget);
  });

  testWidgets('les heures sont montrées, le coût demande la puissance et le prix', (pTester) async {
    final vAc = await controller(
      pRuns: const AcRuns(
        logs: {
          _host: RunLog(minutesByDay: {'2026-12-07': 180, '2026-11-30': 60}),
        },
      ),
    );

    await open(pTester, vAc);

    expect(find.textContaining('3,0 h cette semaine, 1,0 h la semaine d\'avant'), findsOneWidget);
    expect(find.textContaining('sur 7 jours'), findsNothing);
    expect(find.textContaining('Pour estimer le coût'), findsOneWidget);
  });

  testWidgets('avec puissance, prix et budget : énergie, coût, budget et repère du degré', (
    pTester,
  ) async {
    final vAc = await controller(
      pRuns: const AcRuns(
        logs: {
          _host: RunLog(minutesByDay: {'2026-12-07': 600}),
        },
        kwByHost: {_host: 1.0},
        pricePerKwh: 0.5,
        monthlyBudget: 6,
      ),
    );

    await open(pTester, vAc);

    expect(find.textContaining('Environ 10,0 kWh sur 7 jours'), findsOneWidget);
    expect(find.textContaining('Environ 5,00 € sur 7 jours'), findsOneWidget);
    expect(find.textContaining('environ 5,00 € sur 30 jours'), findsOneWidget);
    expect(find.textContaining('Proche du budget de 6,00 €'), findsOneWidget);
    expect(find.textContaining('7 %'), findsOneWidget);
    expect(find.textContaining('0,35 €'), findsOneWidget);
  });

  testWidgets('dépasser le budget est dit', (pTester) async {
    final vAc = await controller(
      pRuns: const AcRuns(
        logs: {
          _host: RunLog(minutesByDay: {'2026-12-07': 600}),
        },
        kwByHost: {_host: 1.0},
        pricePerKwh: 0.5,
        monthlyBudget: 4,
      ),
    );

    await open(pTester, vAc);

    expect(find.textContaining('Au-dessus du budget de 4,00 €'), findsOneWidget);
  });

  testWidgets('le poêle compte dans le total quand son débit et le prix du sac sont donnés', (
    pTester,
  ) async {
    final vAc = await controller(
      pRuns: const AcRuns(
        logs: {
          _host: RunLog(minutesByDay: {'2026-12-07': 600}),
        },
        kwByHost: {_host: 1.0},
        pricePerKwh: 0.5,
      ),
    );
    final vPellet = PelletController(
      MemoryPelletStore(
        const PelletStove(name: 'Poêle', host: '192.168.1.60', serial: 'S', password: 'P'),
      ),
      FakePelletLink(),
      runsStore: MemoryPelletRunsStore(
        const PelletRuns(
          minutesByDay: {'2026-12-07': 120},
          kgPerHour: 1.5,
          bagKg: 15,
          bagPrice: 6,
        ),
      ),
    );
    await vPellet.load();

    await open(pTester, vAc, pPellet: vPellet);

    // Clim 5,00 € + poêle 2 h x 1,5 kg = 3 kg, soit 0,2 sac à 6 € = 1,20 €
    expect(find.textContaining('environ 6,20 € sur 30 jours'), findsOneWidget);
    expect(find.text('Poêle'), findsOneWidget);
  });

  testWidgets('les réglages se saisissent et s\'enregistrent', (pTester) async {
    final vAc = await controller();
    await open(pTester, vAc);

    await pTester.tap(find.text('Prix, puissances et budget'));
    await pTester.pumpAndSettle();
    final vFields = find.byType(TextField);
    await pTester.enterText(vFields.at(0), '0,25');
    await pTester.enterText(vFields.at(1), '80');
    await pTester.enterText(vFields.at(2), '1,4');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();

    expect(vRunsStore.saved.pricePerKwh, 0.25);
    expect(vRunsStore.saved.monthlyBudget, 80);
    expect(vRunsStore.saved.kwByHost, {_host: 1.4});
  });

  testWidgets('annuler la saisie ne change rien', (pTester) async {
    final vAc = await controller();
    await open(pTester, vAc);

    await pTester.tap(find.text('Prix, puissances et budget'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Annuler'));
    await pTester.pumpAndSettle();

    expect(vRunsStore.saved.pricePerKwh, isNull);
  });
}
