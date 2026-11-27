import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/background/plan_runner.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/pending_readings.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/reading.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/background_files.dart';
import 'package:home/storage/file_sensor_store.dart';
import 'package:home/storage/plan_store.dart';

import '../support/fake_daikin.dart';

void main() {
  const vHost = '192.168.1.20';
  final vNow = DateTime(2026, 12, 1, 12);
  late Directory vFolder;
  late FakeDaikinLink vLink;
  late BackgroundFiles vFiles;

  setUp(() async {
    vFolder = Directory.systemTemp.createTempSync('home_runner_test');
    vFiles = BackgroundFiles(vFolder);
    vLink = FakeDaikinLink()
      ..names[vHost] = 'Salon'
      ..states[vHost] = FakeDaikinLink.coolingAt22();
    await FileAcStore(
      File('${vFolder.path}/climatisations.json'),
    ).save([const AcUnit(name: 'Salon', host: vHost, sensorName: 'Salon')]);
    await FileSensorStore(File('${vFolder.path}/capteurs.json')).save([
      Sensor(
        name: 'Salon',
        readings: [Reading(at: vNow.subtract(const Duration(hours: 1)), temp: 20, humidity: 50)],
      ),
    ]);
    await FilePlanStore(vFolder).save(
      const PlanSettings(rooms: [Room(acHost: vHost, targets: RoomTargets(eco: 19))]),
    );
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<void> coldReading() => vFiles.appendPending(
    pendingLine('Salon', Reading(at: vNow.subtract(const Duration(minutes: 2)), temp: 15, humidity: 50)),
  );

  test('appli fermée, le plan se sert des relevés en attente et commande la clim', () async {
    await coldReading();

    await PlanRunner(pFolder: vFolder, pLink: vLink).run(vNow);

    expect(vLink.written, hasLength(1));
    expect(vLink.written.single.$2.setpoint, '19.0');
    expect(await vFiles.peekPending(), hasLength(1));
  });

  test('appli ouverte, le service laisse l\'appli appliquer le plan', () async {
    await coldReading();
    await vFiles.markAppOpen(vNow.subtract(const Duration(minutes: 3)));

    final vAlerts = await PlanRunner(pFolder: vFolder, pLink: vLink).run(vNow);

    expect(vAlerts, isEmpty);
    expect(vLink.written, isEmpty);
  });

  test('un tour sans relevé récent ne commande rien', () async {
    await PlanRunner(pFolder: vFolder, pLink: vLink).run(vNow);

    expect(vLink.written, isEmpty);
  });
}
