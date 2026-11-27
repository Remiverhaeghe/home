import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/app.dart';
import 'package:home/logic/pending_readings.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/background_files.dart';
import 'package:home/storage/sensor_store.dart';

void main() {
  late Directory vFolder;
  late BackgroundFiles vFiles;
  late SensorsController vController;

  setUp(() {
    vFolder = Directory.systemTemp.createTempSync('home_sync_test');
    vFiles = BackgroundFiles(vFolder);
    vController = SensorsController(MemorySensorStore());
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<void> addPending(WidgetTester pTester, int pMinute) => pTester.runAsync(
    () => vFiles.appendPending(
      pendingLine(
        'TP357 (1A2B)',
        Reading(at: DateTime(2026, 12, 1, 8, pMinute), temp: 21, humidity: 50),
      ),
    ),
  );

  /// Lance [pAction], puis laisse la lecture réelle des fichiers aller jusqu'au bout.
  /// Seule l'attente est en vrai temps : les rendus restent dans le temps du test.
  Future<void> real(WidgetTester pTester, Future<void> Function() pAction) async {
    await pAction();
    // Chaque étape réelle d'un fichier ne reprend qu'au rendu suivant : plusieurs tours.
    for (var vRound = 0; vRound < 8; vRound++) {
      await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await pTester.pump();
    }
  }

  testWidgets('à l\'ouverture, les relevés pris en arrière-plan sont rangés', (pTester) async {
    await addPending(pTester, 0);

    await real(pTester, () => pTester.pumpWidget(HomeApp(controller: vController, files: vFiles)));

    expect(vController.sensors.single.name, 'TP357 (1A2B)');
    expect(find.text('TP357 (1A2B)'), findsOneWidget);
  });

  testWidgets('au retour dans l\'appli, les nouveaux relevés sont rangés', (pTester) async {
    await real(pTester, () => pTester.pumpWidget(HomeApp(controller: vController, files: vFiles)));
    expect(vController.sensors, isEmpty);

    await addPending(pTester, 5);
    await real(
      pTester,
      () async => pTester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused),
    );
    expect(vController.sensors, isEmpty);
    await real(
      pTester,
      () async => pTester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );

    expect(vController.sensors.single.readings, hasLength(1));
  });

  testWidgets('sans fichiers, l\'appli s\'ouvre sans rien ranger', (pTester) async {
    await pTester.pumpWidget(HomeApp(controller: vController));
    await pTester.pump();

    expect(vController.sensors, isEmpty);
    expect(find.text('Capteurs de la maison'), findsOneWidget);
  });
}
