import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/storage/ac_store.dart';

void main() {
  late Directory vFolder;

  setUp(() => vFolder = Directory.systemTemp.createTempSync('home_ac_test'));
  tearDown(() => vFolder.deleteSync(recursive: true));

  test('sans fichier, aucune climatisation', () async {
    expect(await FileAcStore(File('${vFolder.path}/c.json')).load(), isEmpty);
  });

  test('ce qui est enregistré se relit, sans fichier temporaire laissé', () async {
    final vFile = File('${vFolder.path}/c.json');
    final vStore = FileAcStore(vFile);

    await vStore.save([const AcUnit(name: 'Salon', host: '192.168.1.20')]);

    expect((await vStore.load()).single.name, 'Salon');
    expect(File('${vFile.path}.tmp').existsSync(), isFalse);
  });

  test('la mémoire garde et rend ce qu\'on lui donne', () async {
    final vStore = MemoryAcStore();

    await vStore.save([const AcUnit(name: 'Cave', host: '10.0.0.2')]);

    expect((await vStore.load()).single.host, '10.0.0.2');
  });
}
