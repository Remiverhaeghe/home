import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/pending_readings.dart';
import 'package:home/logic/reading.dart';
import 'package:home/storage/background_files.dart';

void main() {
  late Directory vFolder;
  late BackgroundFiles vFiles;

  setUp(() {
    vFolder = Directory.systemTemp.createTempSync('home_bg_test');
    vFiles = BackgroundFiles(vFolder);
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  String line(String pSensor, int pMinute) =>
      pendingLine(pSensor, Reading(at: DateTime(2026, 12, 1, 8, pMinute), temp: 21, humidity: 50));

  test('sans fichier, aucun capteur suivi et aucun relevé en attente', () async {
    expect(await vFiles.loadFollowed(), isEmpty);
    expect(await vFiles.takePending(), isEmpty);
  });

  test('les capteurs suivis enregistrés se relisent', () async {
    await vFiles.saveFollowed([const FollowedDevice(id: 'AA', name: 'TP357 (1A2B)')]);

    final vBack = await vFiles.loadFollowed();

    expect(vBack.single.id, 'AA');
    expect(vBack.single.name, 'TP357 (1A2B)');
  });

  test('les lignes ajoutées sont reprises, puis le fichier est vidé', () async {
    await vFiles.appendPending(line('A', 0));
    await vFiles.appendPending(line('B', 5));

    final vTaken = await vFiles.takePending();

    expect(vTaken.map((pItem) => pItem.sensor), ['A', 'B']);
    expect(await vFiles.takePending(), isEmpty);
    expect(vFolder.listSync().whereType<File>().any((pF) => pF.path.contains('releves')), isFalse);
  });

  test('une ligne ajoutée après la reprise va dans un nouveau fichier', () async {
    await vFiles.appendPending(line('A', 0));
    await vFiles.takePending();

    await vFiles.appendPending(line('A', 5));

    expect((await vFiles.takePending()).single.reading.at.minute, 5);
  });

  test('une dernière ligne coupée est ignorée, les autres sont gardées', () async {
    await vFiles.appendPending(line('A', 0));
    await File(
      '${vFolder.path}/releves_en_attente.jsonl',
    ).writeAsString('{"sensor": "A", "at": "2026-12-01T08:', mode: FileMode.append);

    expect(await vFiles.takePending(), hasLength(1));
  });

  test('regarder les relevés en attente ne les retire pas', () async {
    expect(await vFiles.peekPending(), isEmpty);
    await vFiles.appendPending(line('A', 0));

    expect((await vFiles.peekPending()).single.sensor, 'A');
    expect((await vFiles.peekPending()).single.sensor, 'A');
    expect(await vFiles.takePending(), hasLength(1));
  });

  test('l\'appli ouverte se signale pour une durée limitée', () async {
    final vNow = DateTime(2026, 12, 1, 8);
    const vWindow = Duration(minutes: 7);
    expect(await vFiles.isAppOpen(vNow, vWindow), isFalse);

    await vFiles.markAppOpen(vNow);

    expect(await vFiles.isAppOpen(vNow.add(const Duration(minutes: 6)), vWindow), isTrue);
    expect(await vFiles.isAppOpen(vNow.add(const Duration(minutes: 7)), vWindow), isFalse);
  });

  test(
    'la fréquence du relevé vaut 5 minutes tant qu\'une valeur valable n\'est pas écrite',
    () async {
      final vFolder = Directory.systemTemp.createTempSync('home_interval');
      addTearDown(() => vFolder.deleteSync(recursive: true));
      final vFiles = BackgroundFiles(vFolder);
      expect(await vFiles.readIntervalMinutes(), 5);

      await vFiles.setReadIntervalMinutes(30);
      expect(await vFiles.readIntervalMinutes(), 30);

      await vFiles.setReadIntervalMinutes(7);
      expect(await vFiles.readIntervalMinutes(), 5);
    },
  );
}
