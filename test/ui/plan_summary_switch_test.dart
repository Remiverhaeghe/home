import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/plan_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/background_files.dart';
import 'package:home/storage/plan_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/plan_screen.dart';

import '../support/fake_daikin.dart';
import '../support/localized.dart';

void main() {
  late Directory vFolder;

  setUp(() => vFolder = Directory.systemTemp.createTempSync('home_summary_switch'));
  tearDown(() => vFolder.deleteSync(recursive: true));

  testWidgets('l\'interrupteur du résumé écrit le fichier lu par le service', (pTester) async {
    pTester.view.physicalSize = const Size(1200, 4000);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    final vFiles = BackgroundFiles(vFolder);
    final vAc = AcController(
      MemoryAcStore([const AcUnit(name: 'Salon', host: '192.168.1.20')]),
      FakeDaikinLink(),
    );
    await vAc.load();
    final vSensors = SensorsController(MemorySensorStore());
    await pTester.pumpWidget(
      localized(
        PlanScreen(
          plan: PlanController(MemoryPlanStore(), vAc, vSensors),
          ac: vAc,
          sensors: vSensors,
          files: vFiles,
        ),
      ),
    );
    await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await pTester.pump();

    final vSwitch = find.byType(Switch);
    await pTester.ensureVisible(vSwitch);
    expect(pTester.widget<Switch>(vSwitch).value, isFalse);

    // L'écriture du fichier est réelle : elle se lance hors du temps simulé du test
    final vTile = pTester.widget<SwitchListTile>(find.byType(SwitchListTile));
    await pTester.runAsync(() async => vTile.onChanged!(true));
    var vOn = false;
    for (var vTry = 0; vTry < 20 && !vOn; vTry++) {
      await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await pTester.pump();
      vOn = await pTester.runAsync(vFiles.summaryEnabled) ?? false;
    }

    expect(vOn, isTrue);
    // L'interrupteur relit le fichier : laisser cette lecture aboutir avant de regarder l'écran
    await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await pTester.pump();
    expect(pTester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('l\'heure choisie du résumé est rangée dans le fichier du service', (pTester) async {
    pTester.view.physicalSize = const Size(1200, 4000);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    final vFiles = BackgroundFiles(vFolder);
    await pTester.runAsync(() => vFiles.setSummaryEnabled(pOn: true));
    final vAc = AcController(MemoryAcStore(), FakeDaikinLink());
    final vSensors = SensorsController(MemorySensorStore());
    await pTester.pumpWidget(
      localized(
        PlanScreen(
          plan: PlanController(MemoryPlanStore(), vAc, vSensors),
          ac: vAc,
          sensors: vSensors,
          files: vFiles,
        ),
      ),
    );
    final vChoice = find.byKey(const Key('summary-hour'));
    // Les fichiers se lisent pour de vrai : attendre que le choix d'heure apparaisse
    for (var vTry = 0; vTry < 40 && vChoice.evaluate().isEmpty; vTry++) {
      await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await pTester.pump();
    }
    await pTester.ensureVisible(vChoice);
    expect(pTester.widget<DropdownButton<int>>(vChoice).value, 8);

    await pTester.runAsync(() async => pTester.widget<DropdownButton<int>>(vChoice).onChanged!(10));
    expect(await pTester.runAsync(vFiles.summaryStartHour), 10);
    // L'écran relit les fichiers : attendre que le nouveau choix s'affiche
    for (var vTry = 0; vTry < 40 && pTester.widget<DropdownButton<int>>(vChoice).value != 10; vTry++) {
      await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await pTester.pump();
    }

    expect(pTester.widget<DropdownButton<int>>(vChoice).value, 10);
  });

  testWidgets('sans fichiers partagés, il n\'y a pas d\'interrupteur', (pTester) async {
    final vAc = AcController(MemoryAcStore(), FakeDaikinLink());
    final vSensors = SensorsController(MemorySensorStore());

    await pTester.pumpWidget(
      localized(
        PlanScreen(
          plan: PlanController(MemoryPlanStore(), vAc, vSensors),
          ac: vAc,
          sensors: vSensors,
        ),
      ),
    );

    expect(find.byType(Switch), findsNothing);
  });
}
