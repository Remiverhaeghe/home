import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await pTester.pump();

    final vSwitch = find.byType(Switch);
    await pTester.ensureVisible(vSwitch);
    expect(pTester.widget<Switch>(vSwitch).value, isFalse);

    await pTester.tap(vSwitch);
    var vOn = false;
    for (var vTry = 0; vTry < 20 && !vOn; vTry++) {
      await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await pTester.pump();
      vOn = await pTester.runAsync(vFiles.summaryEnabled) ?? false;
    }

    expect(vOn, isTrue);
    expect(pTester.widget<Switch>(find.byType(Switch)).value, isTrue);
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
