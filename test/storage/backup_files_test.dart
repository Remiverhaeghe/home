import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/storage/backup_files.dart';

void main() {
  late Directory vFolder;
  late BackupFiles vFiles;

  setUp(() {
    vFolder = Directory.systemTemp.createTempSync('home_backup');
    vFiles = BackupFiles(vFolder);
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  test('seuls les fichiers de données présents sont collectés', () async {
    File('${vFolder.path}/maison.json').writeAsStringSync('{"a":1}');
    File('${vFolder.path}/autre.txt').writeAsStringSync('x');

    expect(await vFiles.collect(), {'maison.json': '{"a":1}'});
  });

  test('la restauration écrit les fichiers et garde les anciens en .avant', () async {
    File('${vFolder.path}/maison.json').writeAsStringSync('{"vieux":true}');

    final vCount = await vFiles.restore({'maison.json': '{"neuf":true}', 'meteo.json': '{}'});

    expect(vCount, 2);
    expect(File('${vFolder.path}/maison.json').readAsStringSync(), '{"neuf":true}');
    expect(File('${vFolder.path}/maison.json.avant').readAsStringSync(), '{"vieux":true}');
    expect(File('${vFolder.path}/meteo.json').readAsStringSync(), '{}');
    expect(File('${vFolder.path}/meteo.json.avant').existsSync(), isFalse);
  });

  test('un nom hors liste n\'est jamais écrit', () async {
    final vCount = await vFiles.restore({'../evil.json': '{}', 'evil.json': '{}'});

    expect(vCount, 0);
    expect(vFolder.listSync(), isEmpty);
  });
}
