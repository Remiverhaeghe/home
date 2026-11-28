import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/background/plan_runner.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/pending_readings.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/pellet.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/vacation.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/background_files.dart';
import 'package:home/storage/file_sensor_store.dart';
import 'package:home/storage/pellet_store.dart';
import 'package:home/storage/plan_store.dart';

import '../support/fake_daikin.dart';
import '../support/fake_pellet.dart';

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
      const PlanSettings(
        rooms: [Room(acHost: vHost, targets: RoomTargets(eco: 19))],
      ),
    );
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<void> coldReading() => vFiles.appendPending(
    pendingLine(
      'Salon',
      Reading(at: vNow.subtract(const Duration(minutes: 2)), temp: 15, humidity: 50),
    ),
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

  group('poêle', () {
    late FakePelletLink vPellet;

    setUp(() async {
      vPellet = FakePelletLink()
        ..state = const PelletState(
          isOn: true,
          phase: PelletPhase.running,
          code: 7,
          roomC: 20,
          targetC: 21,
          powerLevel: 3,
        );
      await FilePelletStore(File('${vFolder.path}/poele.json')).save(
        const PelletStove(name: 'Poêle', host: '192.168.1.40', serial: 'S1', password: 'P1'),
      );
    });

    Future<void> saveVacation() => FilePlanStore(vFolder).save(
      PlanSettings(
        rooms: const [Room(acHost: vHost, targets: RoomTargets(eco: 19))],
        vacation: VacationMode(
          from: vNow.subtract(const Duration(days: 2)),
          until: vNow.add(const Duration(days: 10)),
        ),
      ),
    );

    test('en vacances, appli fermée, le service éteint le poêle qui marche', () async {
      await saveVacation();

      await PlanRunner(pFolder: vFolder, pLink: vLink, pPelletLink: vPellet).run(vNow);

      expect(vPellet.powers, [false]);
    });

    test('hors vacances, le service laisse le poêle marcher', () async {
      await PlanRunner(pFolder: vFolder, pLink: vLink, pPelletLink: vPellet).run(vNow);

      expect(vPellet.powers, isEmpty);
    });

    test('poêle injoignable : rien n\'est envoyé et le tour continue', () async {
      await saveVacation();
      vPellet.fail = true;

      await PlanRunner(pFolder: vFolder, pLink: vLink, pPelletLink: vPellet).run(vNow);

      expect(vPellet.powers, isEmpty);
    });

    test('appli ouverte, le service ne touche pas au poêle', () async {
      await saveVacation();
      await vFiles.markAppOpen(vNow.subtract(const Duration(minutes: 3)));

      await PlanRunner(pFolder: vFolder, pLink: vLink, pPelletLink: vPellet).run(vNow);

      expect(vPellet.powers, isEmpty);
    });
  });
}
