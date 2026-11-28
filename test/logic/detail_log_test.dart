import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/detail_log.dart';
import 'package:home/storage/detail_log.dart';

void main() {
  test('une ligne porte la date à la seconde, le sujet et un message sans adresse', () {
    final vLine = detailEntry(
      DateTime(2026, 11, 28, 9, 5, 7),
      'capteur 2',
      'essai 1 sans mesure sur 192.168.1.20',
    );

    expect(vLine, '2026-11-28 09:05:07 [capteur 2] essai 1 sans mesure sur ***');
  });

  test('désactivé, le journal ne garde rien ; activé, il note et se vide', () async {
    final vLog = MemoryDetailLog(pNow: () => DateTime(2026, 11, 28, 10));

    await vLog.note('tour', 'début');
    expect(await vLog.read(), isEmpty);

    await vLog.setOn(pOn: true);
    await vLog.note('tour', 'début');
    await vLog.note('tour', 'fin');
    expect((await vLog.read()).split('\n'), hasLength(2));

    await vLog.clear();
    expect(await vLog.read(), isEmpty);
    expect(await vLog.isOn(), isTrue);
  });

  test('le journal garde seulement les dernières lignes', () async {
    final vLog = MemoryDetailLog(pNow: () => DateTime(2026, 11, 28), on: true);

    for (var vIndex = 0; vIndex < maxDetailLines + 20; vIndex++) {
      await vLog.note('tour', 'ligne $vIndex');
    }
    final vLines = (await vLog.read()).split('\n');

    expect(vLines, hasLength(maxDetailLines));
    expect(vLines.last, endsWith('ligne ${maxDetailLines + 19}'));
  });

  test('le fichier suit l\'interrupteur et la lecture se fait entre deux processus', () async {
    final vFolder = Directory.systemTemp.createTempSync('detail');
    addTearDown(() => vFolder.deleteSync(recursive: true));
    final vApp = FileDetailLog(vFolder, pNow: () => DateTime(2026, 11, 28, 8));
    final vService = FileDetailLog(vFolder, pNow: () => DateTime(2026, 11, 28, 8, 5));

    await vService.note('tour', 'ignorée');
    expect(await vApp.read(), isEmpty);

    await vApp.setOn(pOn: true);
    await vService.note('tour', 'début');

    expect(await vApp.read(), '2026-11-28 08:05:00 [tour] début');

    await vApp.setOn(pOn: false);
    await vService.note('tour', 'ignorée aussi');
    expect(await vApp.read(), '2026-11-28 08:05:00 [tour] début');
    await vApp.clear();
    expect(await vApp.read(), isEmpty);
  });

  test('des notes lancées sans attendre ne se perdent pas et restent dans l\'ordre', () async {
    final vFolder = Directory.systemTemp.createTempSync('detail_order');
    addTearDown(() => vFolder.deleteSync(recursive: true));
    final vLog = FileDetailLog(vFolder, pNow: () => DateTime(2026, 11, 28, 8));
    await vLog.setOn(pOn: true);

    await Future.wait([
      vLog.note('capteur 1', 'connexion lancée'),
      vLog.note('capteur 1', 'connexion : connected'),
      vLog.note('capteur 1', 'trame de 11 octets'),
    ]);

    final vLines = (await vLog.read()).split('\n');
    expect(vLines, hasLength(3));
    expect(vLines.first, endsWith('connexion lancée'));
    expect(vLines.last, endsWith('trame de 11 octets'));
  });
}
