import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/storage/detail_log.dart';
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
    await pTester.pumpWidget(localized(AboutScreen(log: vLog, saveFile: (_, _) async => false)));
    await pTester.pumpAndSettle();

    await pTester.tap(find.text('Enregistrer le journal'));
    await pTester.pumpAndSettle();

    expect(find.text('Journal enregistré.'), findsNothing);
  });

  testWidgets('les nouveautés de la dernière version se déplient', (pTester) async {
    await pTester.pumpWidget(
      localized(
        AboutScreen(
          log: MemoryErrorLogStore(),
          saveFile: (_, _) async => true,
          loadChangelog: () async => '## 0.2.0\n\n### Ajouté\n\n- Un menu `Plus`.\n',
        ),
      ),
    );
    await pTester.pumpAndSettle();
    expect(find.text('Un menu Plus.'), findsNothing);

    await pTester.tap(find.text('Nouveautés'));
    await pTester.pumpAndSettle();

    expect(find.text('0.2.0'), findsOneWidget);
    expect(find.text('Ajouté'), findsOneWidget);
    expect(find.text('Un menu Plus.'), findsOneWidget);
  });

  testWidgets('un CHANGELOG illisible ne montre aucune rubrique', (pTester) async {
    await pTester.pumpWidget(
      localized(
        AboutScreen(
          log: MemoryErrorLogStore(),
          saveFile: (_, _) async => true,
          loadChangelog: () async => throw StateError('absent'),
        ),
      ),
    );
    await pTester.pumpAndSettle();

    expect(find.text('Nouveautés'), findsNothing);
    expect(find.textContaining('version 0.1.0'), findsOneWidget);
  });

  testWidgets('le journal détaillé s\'active, s\'affiche et se vide', (pTester) async {
    final vDetail = MemoryDetailLog(pNow: () => DateTime(2026, 11, 28, 9));
    await pTester.pumpWidget(
      localized(
        AboutScreen(
          log: MemoryErrorLogStore(),
          saveFile: (_, _) async => true,
          detail: vDetail,
        ),
      ),
    );
    await pTester.pumpAndSettle();

    expect(find.text('Rien d\'enregistré pour le moment.'), findsOneWidget);

    await pTester.scrollUntilVisible(find.text('Journal détaillé'), 200);
    await pTester.tap(find.byType(Switch));
    await pTester.pumpAndSettle();
    expect(vDetail.on, isTrue);

    await vDetail.note('tour', 'début');
    await pTester.tap(find.text('Actualiser'));
    await pTester.pumpAndSettle();
    expect(find.textContaining('[tour] début'), findsOneWidget);
  });
}
