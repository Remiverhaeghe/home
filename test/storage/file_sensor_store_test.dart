import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/storage/file_sensor_store.dart';

import '../support/sensors.dart';

void main() {
  late Directory vFolder;

  setUp(() => vFolder = Directory.systemTemp.createTempSync('home_test'));
  tearDown(() => vFolder.deleteSync(recursive: true));

  test('sans fichier, aucun capteur', () async {
    final vStore = FileSensorStore(File('${vFolder.path}/capteurs.json'));

    expect(await vStore.load(), isEmpty);
  });

  test('ce qui est enregistré se relit, sans fichier temporaire laissé', () async {
    final vFile = File('${vFolder.path}/capteurs.json');
    final vStore = FileSensorStore(vFile);

    await vStore.save([bathroomSensor()]);
    final vBack = await vStore.load();

    expect(vBack.single.name, 'Salle de bain');
    expect(vBack.single.readings, hasLength(3));
    expect(File('${vFile.path}.tmp').existsSync(), isFalse);
  });

  test('un fichier abîmé est ignoré au lieu de bloquer l\'appli', () async {
    final vFile = File('${vFolder.path}/capteurs.json')..writeAsStringSync('{ pas du json');

    expect(await FileSensorStore(vFile).load(), isEmpty);
  });
}
