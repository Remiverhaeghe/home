import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/alerts.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/plan_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/plan_store.dart';
import 'package:home/storage/sensor_store.dart';

import '../support/fake_daikin.dart';

PlanController _plan(PlanStore pStore) => PlanController(
  pStore,
  AcController(MemoryAcStore(), FakeDaikinLink()),
  SensorsController(MemorySensorStore()),
);

void main() {
  test('le seuil d\'humidité vaut 70 % au départ', () {
    expect(_plan(MemoryPlanStore()).humidityAlertAt, 70);
  });

  test('il se règle au pour cent, borné, et reste après un autre réglage', () async {
    final vStore = MemoryPlanStore();
    final vPlan = _plan(vStore);

    await vPlan.setHumidityAlertAt(64.4);
    expect(vPlan.humidityAlertAt, 64);
    await vPlan.setHumidityAlertAt(10);
    expect(vPlan.humidityAlertAt, humidityAlertMin);
    await vPlan.setHumidityAlertAt(99);
    expect(vPlan.humidityAlertAt, humidityAlertMax);

    await vPlan.setHumidityAlertAt(65);
    await vPlan.setVacation(null);
    await vPlan.setRules(const []);
    await vPlan.setStoveColdBelow(15);
    expect(vStore.saved.humidityAlertAt, 65);
  });

  test('le passage du plan alerte selon le seuil réglé', () async {
    final vNow = DateTime(2026, 12, 7, 14);
    final vSensor = Sensor(
      name: 'Bain',
      readings: [Reading(at: vNow, temp: 21, humidity: 68)],
    );
    final vSensors = SensorsController(MemorySensorStore([vSensor]));
    await vSensors.load();
    final vPlan = PlanController(
      MemoryPlanStore(),
      AcController(MemoryAcStore(), FakeDaikinLink()),
      vSensors,
    );
    await vPlan.load();

    expect(await vPlan.tick(vNow), isEmpty);

    await vPlan.setHumidityAlertAt(65);
    expect((await vPlan.tick(vNow)).single.kind, AlertKind.humidity);
  });

  group('fichier reglages-plan.json', () {
    late Directory vFolder;

    setUp(() => vFolder = Directory.systemTemp.createTempSync('home_plan_humidite'));
    tearDown(() => vFolder.deleteSync(recursive: true));

    test('le seuil est écrit puis relu', () async {
      final vStore = FilePlanStore(vFolder);

      await vStore.save(const PlanSettings(humidityAlertAt: 62));

      expect((await vStore.load()).humidityAlertAt, 62);
    });

    test('sans fichier, abîmé ou hors bornes : 70 %', () async {
      final vStore = FilePlanStore(vFolder);
      expect((await vStore.load()).humidityAlertAt, 70);

      for (final vContent in ['pas du json', '{"alerteHumidite": 99}', '[1]', '{}']) {
        File('${vFolder.path}/reglages-plan.json').writeAsStringSync(vContent);
        expect((await vStore.load()).humidityAlertAt, 70, reason: vContent);
      }
    });
  });
}
