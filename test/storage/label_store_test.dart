import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/storage/label_store.dart';

void main() {
  late Directory vFolder;
  late File vFile;

  setUp(() {
    vFolder = Directory.systemTemp.createTempSync('noms');
    vFile = File('${vFolder.path}/noms-capteurs.json');
  });

  tearDown(() => vFolder.deleteSync(recursive: true));

  test('sans fichier, il n\'y a aucun nom', () async {
    expect(await FileLabelStore(vFile).load(), isEmpty);
  });

  test('les noms écrits se relisent', () async {
    final vStore = FileLabelStore(vFile);

    await vStore.save({'A': 'Salon', 'B': 'Cave'});

    expect(await vStore.load(), {'A': 'Salon', 'B': 'Cave'});
  });

  test('un fichier abîmé ou mal formé est ignoré', () async {
    vFile.writeAsStringSync('pas du json');
    expect(await FileLabelStore(vFile).load(), isEmpty);

    vFile.writeAsStringSync('[1,2]');
    expect(await FileLabelStore(vFile).load(), isEmpty);

    vFile.writeAsStringSync('{"A":"  ","B":3,"C":"Cuisine"}');
    expect(await FileLabelStore(vFile).load(), {'C': 'Cuisine'});
  });
}
