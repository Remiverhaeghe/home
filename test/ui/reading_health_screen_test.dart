import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/read_health.dart';
import 'package:home/storage/background_files.dart';
import 'package:home/ui/reading_health_screen.dart';

import '../support/fake_background.dart';
import '../support/localized.dart';

void main() {
  final vNow = DateTime(2026, 12, 7, 14);
  late Directory vFolder;
  late BackgroundFiles vFiles;
  late FakeBackgroundControl vControl;

  setUp(() {
    vFolder = Directory.systemTemp.createTempSync('home_health_screen');
    vFiles = BackgroundFiles(vFolder);
    vControl = FakeBackgroundControl();
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<void> open(WidgetTester pTester, {ReadHealth? pHealth}) async {
    if (pHealth != null) {
      await pTester.runAsync(() => vFiles.saveHealth(pHealth));
    }
    await pTester.pumpWidget(
      localized(ReadingHealthScreen(files: vFiles, background: vControl, clock: () => vNow)),
    );
    for (var vTry = 0; vTry < 20; vTry++) {
      await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await pTester.pump();
    }
  }

  testWidgets('sans tour de relevé, l\'écran invite à activer le suivi', (pTester) async {
    await open(pTester);

    expect(find.textContaining('Aucun tour de relevé'), findsOneWidget);
  });

  testWidgets('chaque capteur montre son dernier relevé, sa série et sa réussite', (pTester) async {
    final vHealth = const ReadHealth()
        .record('Salon', vNow.subtract(const Duration(minutes: 20)), pOk: true)
        .record('Salon', vNow.subtract(const Duration(minutes: 10)), pOk: false)
        .record('Salon', vNow, pOk: false);
    await open(pTester, pHealth: vHealth);

    expect(find.text('Salon'), findsOneWidget);
    expect(find.textContaining('2 tours manqués d\'affilée'), findsOneWidget);
    expect(find.textContaining('Réussite sur 7 jours : 33 %'), findsOneWidget);
    expect(find.textContaining('Aujourd\'hui : 1 réussis, 2 manqués'), findsOneWidget);
    expect(find.textContaining('Dernier relevé réussi'), findsOneWidget);
  });

  testWidgets('un capteur qui n\'a jamais répondu le dit', (pTester) async {
    await open(pTester, pHealth: const ReadHealth().record('Chambre', vNow, pOk: false));

    expect(find.text('Aucun relevé réussi en arrière-plan'), findsOneWidget);
  });

  testWidgets('l\'économie de batterie se signale et se demande', (pTester) async {
    await open(pTester);

    expect(find.textContaining('Android peut couper le relevé'), findsOneWidget);

    await pTester.tap(find.byKey(const Key('battery-allow')));
    for (var vTry = 0; vTry < 10; vTry++) {
      await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await pTester.pump();
    }

    expect(vControl.batteryRequests, 1);
    expect(find.textContaining('Home n\'est pas limitée'), findsOneWidget);
    expect(find.byKey(const Key('battery-allow')), findsNothing);
  });
}
