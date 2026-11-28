import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/alert_history.dart';
import 'package:home/logic/alerts.dart';
import 'package:home/storage/background_files.dart';
import 'package:home/ui/quiet_hours_section.dart';

import '../support/localized.dart';

void main() {
  late Directory vFolder;

  setUp(() => vFolder = Directory.systemTemp.createTempSync('home_quiet'));
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<void> settle(WidgetTester pTester) async {
    await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await pTester.pump();
  }

  testWidgets('les deux heures choisies sont rangées dans le fichier du service', (pTester) async {
    pTester.view.physicalSize = const Size(1200, 2000);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    final vFiles = BackgroundFiles(vFolder);
    await pTester.pumpWidget(localized(Scaffold(body: QuietHoursSection(files: vFiles))));
    await settle(pTester);

    final vFrom = pTester.widget<DropdownButton<int?>>(
      find.descendant(of: find.byKey(const Key('quiet-from')), matching: find.byType(DropdownButton<int?>)),
    );
    final vTo = pTester.widget<DropdownButton<int?>>(
      find.descendant(of: find.byKey(const Key('quiet-to')), matching: find.byType(DropdownButton<int?>)),
    );
    await pTester.runAsync(() async => vFrom.onChanged!(22));
    await pTester.pump();
    await pTester.runAsync(() async => vTo.onChanged!(7));
    await pTester.pump();

    var vQuiet = await pTester.runAsync(vFiles.quietHours);
    for (var vTry = 0; vTry < 20 && vQuiet == null; vTry++) {
      await settle(pTester);
      vQuiet = await pTester.runAsync(vFiles.quietHours);
    }

    expect(vQuiet?.startHour, 22);
    expect(vQuiet?.endHour, 7);
  });

  testWidgets('l\'historique montre la plus récente en premier', (pTester) async {
    final vFiles = BackgroundFiles(vFolder);
    await pTester.runAsync(() async {
      await vFiles.saveAlertHistory(
        appendAlerts(
          appendAlerts([], [const SensorAlert(sensorName: 'Cave', kind: AlertKind.frost)], DateTime(2026, 11, 27, 6)),
          [const SensorAlert(sensorName: 'Salon', kind: AlertKind.silent)],
          DateTime(2026, 11, 28, 6),
        ),
      );
    });
    await pTester.pumpWidget(localized(Scaffold(body: QuietHoursSection(files: vFiles))));
    await settle(pTester);

    await pTester.tap(find.byIcon(Icons.history));
    await pTester.pumpAndSettle();
    await settle(pTester);

    expect(find.textContaining('Salon'), findsOneWidget);
    expect(find.textContaining('Cave'), findsOneWidget);
    expect(
      pTester.getTopLeft(find.textContaining('Salon')).dy,
      lessThan(pTester.getTopLeft(find.textContaining('Cave')).dy),
    );
  });
}
