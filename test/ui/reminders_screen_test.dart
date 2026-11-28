import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reminders.dart';
import 'package:home/storage/background_files.dart';
import 'package:home/ui/reminders_screen.dart';

import '../support/localized.dart';

void main() {
  final vNow = DateTime(2026, 12, 10, 9);
  late Directory vFolder;
  late BackgroundFiles vFiles;

  setUp(() {
    vFolder = Directory.systemTemp.createTempSync('home_reminders');
    vFiles = BackgroundFiles(vFolder);
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<void> settle(WidgetTester pTester) async {
    for (var vTry = 0; vTry < 10; vTry++) {
      await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await pTester.pump();
    }
  }

  Future<void> open(WidgetTester pTester) async {
    await pTester.pumpWidget(localized(RemindersScreen(files: vFiles, clock: () => vNow)));
    await settle(pTester);
  }

  testWidgets('sans rappel, l\'écran invite à en ajouter', (pTester) async {
    await open(pTester);

    expect(find.textContaining('Aucun rappel'), findsOneWidget);
  });

  testWidgets('un rappel ajouté est rangé dans le fichier du service', (pTester) async {
    await open(pTester);

    await pTester.tap(find.byKey(const Key('reminder-add')));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.byKey(const Key('reminder-name')), 'Filtres du salon');
    await pTester.enterText(find.byKey(const Key('reminder-days')), '30');
    await pTester.tap(find.byKey(const Key('reminder-save')));
    await pTester.pumpAndSettle();
    await settle(pTester);

    final vSaved = await pTester.runAsync(vFiles.loadReminders);
    expect(vSaved, hasLength(1));
    expect(vSaved!.single.everyDays, 30);
    expect(find.text('Filtres du salon'), findsOneWidget);
    expect(find.textContaining('Dans 30 jours'), findsOneWidget);
  });

  testWidgets('un rappel échu le dit, et « fait » repart d\'aujourd\'hui', (pTester) async {
    await pTester.runAsync(
      () => vFiles.saveReminders([
        Reminder(name: 'Piles', everyDays: 10, lastDone: DateTime(2026, 11, 28)),
      ]),
    );
    await open(pTester);
    expect(find.textContaining('À faire depuis 2 jours'), findsOneWidget);

    await pTester.tap(find.byKey(const Key('reminder-done-0')));
    await settle(pTester);

    final vSaved = await pTester.runAsync(vFiles.loadReminders);
    expect(vSaved!.single.lastDone, vNow);
    expect(find.textContaining('Dans 10 jours'), findsOneWidget);
  });

  testWidgets('supprimer retire le rappel', (pTester) async {
    await pTester.runAsync(
      () => vFiles.saveReminders([Reminder(name: 'Piles', everyDays: 10, lastDone: vNow)]),
    );
    await open(pTester);

    await pTester.tap(find.byKey(const Key('reminder-delete-0')));
    await settle(pTester);

    expect(await pTester.runAsync(vFiles.loadReminders), isEmpty);
    expect(find.text('Piles'), findsNothing);
  });
}
