import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/background/day_summary_runner.dart';
import 'package:home/logic/house.dart';
import 'package:home/logic/reading.dart';
import 'package:home/storage/background_files.dart';
import 'package:home/storage/file_sensor_store.dart';
import 'package:home/storage/house_store.dart';

import '../support/fake_background.dart';

void main() {
  final vNow = DateTime(2026, 12, 7, 8, 30);
  late Directory vFolder;
  late BackgroundFiles vFiles;
  late FakeAlertNotifier vNotifier;

  setUp(() async {
    vFolder = Directory.systemTemp.createTempSync('home_summary_test');
    vFiles = BackgroundFiles(vFolder);
    vNotifier = FakeAlertNotifier();
    await FileSensorStore(File('${vFolder.path}/capteurs.json')).save([
      Sensor(
        name: 'Salon',
        readings: [Reading(at: vNow.subtract(const Duration(minutes: 10)), temp: 20, humidity: 50)],
      ),
    ]);
    await FileHouseStore(
      File('${vFolder.path}/maison.json'),
    ).save(const House(places: {'Salon': SensorPlace(room: 'Salon', floor: 0)}));
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<bool> run([DateTime? pAt]) =>
      sendDaySummaryIfDue(pFolder: vFolder, pNow: pAt ?? vNow, pNotifier: vNotifier);

  test('sans interrupteur, rien ne part', () async {
    expect(await run(), isFalse);
    expect(vNotifier.summaries, isEmpty);
  });

  test('voulu et dû : le résumé part une seule fois par jour', () async {
    await vFiles.setSummaryEnabled(pOn: true);

    expect(await run(), isTrue);
    expect(vNotifier.summaries.single, contains('Pièce la plus fraîche : Salon (20,0 °C).'));
    expect(await run(vNow.add(const Duration(hours: 2))), isFalse);
    expect(await run(vNow.add(const Duration(days: 1))), isTrue);
    expect(vNotifier.summaries, hasLength(2));
  });

  test('pas avant 8 h', () async {
    await vFiles.setSummaryEnabled(pOn: true);

    expect(await run(DateTime(2026, 12, 7, 6)), isFalse);
  });

  test('sans pièce rangée, rien ne part et l\'envoi n\'est pas noté', () async {
    await vFiles.setSummaryEnabled(pOn: true);
    await FileHouseStore(File('${vFolder.path}/maison.json')).save(const House());

    expect(await run(), isFalse);
    expect(await vFiles.lastSummary(), isNull);
  });

  test('l\'interrupteur se coupe', () async {
    await vFiles.setSummaryEnabled(pOn: true);
    await vFiles.setSummaryEnabled(pOn: false);

    expect(await vFiles.summaryEnabled(), isFalse);
    expect(await run(), isFalse);
  });
}
