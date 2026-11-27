import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/backup.dart';

void main() {
  test('la sauvegarde rend exactement le texte des fichiers', () {
    const vFiles = {'capteurs.json': '{"version": 1,\n "sensors": []}', 'maison.json': '{"a":1}'};

    final vParsed = parseBackup(backupJson(vFiles, DateTime(2026, 11, 27, 21)));

    expect(vParsed.problem, isNull);
    expect(vParsed.backup?.files, vFiles);
    expect(vParsed.backup?.createdAt, DateTime(2026, 11, 27, 21));
    expect(vParsed.backup?.hasSecrets, isFalse);
  });

  test('le poêle signale un fichier à garder en lieu sûr', () {
    final vParsed = parseBackup(backupJson({'poele.json': '{}'}, DateTime(2026)));

    expect(vParsed.backup?.hasSecrets, isTrue);
  });

  test('un fichier qui n\'est pas du JSON ou pas une sauvegarde est refusé', () {
    expect(parseBackup('pas du json').problem, BackupProblem.notJson);
    expect(parseBackup('[]').problem, BackupProblem.notBackup);
    expect(parseBackup('{"app":"atelier","files":{}}').problem, BackupProblem.notBackup);
    expect(parseBackup('{"app":"home"}').problem, BackupProblem.notBackup);
  });

  test('une autre version est refusée', () {
    expect(
      parseBackup('{"app":"home","version":2,"files":{}}').problem,
      BackupProblem.wrongVersion,
    );
  });

  test('seuls les fichiers connus et lisibles sont gardés', () {
    final vText = jsonEncode({
      'app': 'home',
      'version': 1,
      'files': {
        'maison.json': '{"ok":true}',
        '../evil.json': '{}',
        'relais.json': 'pas du json',
        'meteo.json': 3,
      },
    });

    final vParsed = parseBackup(vText);

    expect(vParsed.backup?.files.keys, ['maison.json']);
    expect(vParsed.backup?.createdAt, isNull);
  });

  test('une sauvegarde sans fichier utilisable est vide', () {
    final vText = jsonEncode({
      'app': 'home',
      'version': 1,
      'files': {'x.json': '{}'},
    });

    expect(parseBackup(vText).problem, BackupProblem.empty);
  });

  test('les fichiers inconnus ne sont pas écrits', () {
    final vText = backupJson({'capteurs.json': '{}', 'autre.json': '{}'}, DateTime(2026));

    expect((jsonDecode(vText) as Map)['files'], {'capteurs.json': '{}'});
  });
}
