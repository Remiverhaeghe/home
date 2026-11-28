import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/backup.dart';
import 'package:home/storage/backup_files.dart';
import 'package:home/ui/backup_screen.dart';

import '../support/localized.dart';

void main() {
  late Directory vFolder;
  late BackupFiles vFiles;
  String? vPicked;
  String? vSavedName;
  Uint8List? vSavedBytes;
  var vRestoredCalls = 0;

  setUp(() {
    vFolder = Directory.systemTemp.createTempSync('home_backup_ui');
    vFiles = BackupFiles(vFolder);
    vPicked = null;
    vSavedName = null;
    vSavedBytes = null;
    vRestoredCalls = 0;
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<void> open(WidgetTester pTester) => pTester.pumpWidget(
    localized(
      BackupScreen(
        files: vFiles,
        pickFile: () async => vPicked,
        saveFile: (pName, pBytes) async {
          vSavedName = pName;
          vSavedBytes = pBytes;

          return true;
        },
        onRestored: () async => vRestoredCalls++,
        clock: () => DateTime(2026, 11, 27, 21),
      ),
    ),
  );

  testWidgets('la sauvegarde contient les fichiers présents et porte la date', (pTester) async {
    File('${vFolder.path}/maison.json').writeAsStringSync('{"a":1}');
    await open(pTester);

    await pTester.runAsync(() async {
      await pTester.tap(find.text('Enregistrer une sauvegarde'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pTester.pumpAndSettle();

    expect(vSavedName, 'home-sauvegarde-2026-11-27.json');
    expect(parseBackup(utf8.decode(vSavedBytes!)).backup?.files, {'maison.json': '{"a":1}'});
    expect(find.text('Sauvegarde enregistrée.'), findsOneWidget);
  });

  testWidgets('un fichier qui n\'est pas une sauvegarde est refusé', (pTester) async {
    vPicked = '{"autre":1}';
    await open(pTester);

    await pTester.tap(find.text('Restaurer une sauvegarde'));
    await pTester.pumpAndSettle();

    expect(find.textContaining('n\'est pas une sauvegarde de Home'), findsOneWidget);
    expect(vRestoredCalls, 0);
  });

  testWidgets('la restauration demande confirmation puis relit les données', (pTester) async {
    vPicked = backupJson({'maison.json': '{"neuf":true}'}, DateTime(2026, 11, 1));
    await open(pTester);

    await pTester.tap(find.text('Restaurer une sauvegarde'));
    await pTester.pumpAndSettle();
    expect(find.text('Restaurer cette sauvegarde ?'), findsOneWidget);

    await pTester.tap(find.widgetWithText(FilledButton, 'Restaurer'));
    await pTester.pump();
    await pTester.runAsync(() async {
      final vTarget = File('${vFolder.path}/maison.json');
      for (var vTry = 0; vTry < 100 && !vTarget.existsSync(); vTry++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await pTester.pumpAndSettle();

    expect(File('${vFolder.path}/maison.json').readAsStringSync(), '{"neuf":true}');
    expect(vRestoredCalls, 1);
    expect(find.text('1 fichiers restaurés.'), findsOneWidget);
  });

  testWidgets('annuler la confirmation ne touche à rien', (pTester) async {
    vPicked = backupJson({'maison.json': '{"neuf":true}'}, DateTime(2026, 11, 1));
    await open(pTester);

    await pTester.tap(find.text('Restaurer une sauvegarde'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Annuler'));
    await pTester.pumpAndSettle();

    expect(File('${vFolder.path}/maison.json').existsSync(), isFalse);
    expect(vRestoredCalls, 0);
  });
}
