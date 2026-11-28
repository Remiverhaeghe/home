import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/storage/error_log_store.dart';

void main() {
  test('en mémoire, on ajoute, on lit, on vide', () async {
    final vStore = MemoryErrorLogStore();

    await vStore.append('a');
    await vStore.append('b');
    expect(await vStore.read(), 'a\nb');

    await vStore.clear();
    expect(await vStore.read(), '');
  });

  test('en fichier, sans fichier le journal est vide et vider passe', () async {
    final vDir = Directory.systemTemp.createTempSync('journal');
    addTearDown(() => vDir.deleteSync(recursive: true));
    final vStore = FileErrorLogStore(File('${vDir.path}/journal-erreurs.txt'));

    expect(await vStore.read(), '');
    await vStore.clear();

    await vStore.append('a');
    await vStore.append('b');
    expect(await vStore.read(), 'a\nb');

    await vStore.clear();
    expect(await vStore.read(), '');
  });
}
