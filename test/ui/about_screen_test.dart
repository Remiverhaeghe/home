import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/storage/error_log_store.dart';
import 'package:home/ui/about_screen.dart';

import '../support/localized.dart';

void main() {
  testWidgets('sans erreur, l\'écran le dit et montre la version', (pTester) async {
    await pTester.pumpWidget(
      localized(AboutScreen(log: MemoryErrorLogStore(), saveFile: (_, _) async => true)),
    );
    await pTester.pumpAndSettle();

    expect(find.textContaining('version 0.1.0'), findsOneWidget);
    expect(find.text('Aucune erreur pour le moment.'), findsOneWidget);
    expect(find.text('Vider'), findsNothing);
  });

  testWidgets('le journal s\'enregistre dans un fichier, puis se vide', (pTester) async {
    final vLog = MemoryErrorLogStore()..text = '2026-12-07 09:05 StateError panne';
    String? vName;
    Uint8List? vBytes;
    await pTester.pumpWidget(
      localized(
        AboutScreen(
          log: vLog,
          saveFile: (pName, pBytes) async {
            vName = pName;
            vBytes = pBytes;

            return true;
          },
        ),
      ),
    );
    await pTester.pumpAndSettle();

    await pTester.tap(find.text('Enregistrer le journal'));
    await pTester.pumpAndSettle();
    expect(vName, 'home-journal.txt');
    expect(utf8.decode(vBytes!), contains('StateError'));
    expect(find.text('Journal enregistré.'), findsOneWidget);

    await pTester.tap(find.text('Vider'));
    await pTester.pumpAndSettle();
    expect(vLog.text, '');
    expect(find.text('Aucune erreur pour le moment.'), findsOneWidget);
  });

  testWidgets('renoncer à l\'enregistrement n\'affiche rien', (pTester) async {
    final vLog = MemoryErrorLogStore()..text = 'erreur';
    await pTester.pumpWidget(
      localized(AboutScreen(log: vLog, saveFile: (_, _) async => false)),
    );
    await pTester.pumpAndSettle();

    await pTester.tap(find.text('Enregistrer le journal'));
    await pTester.pumpAndSettle();

    expect(find.text('Journal enregistré.'), findsNothing);
  });
}
