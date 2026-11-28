import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  test('le seuil de froid vaut 16 °C au départ', () {
    expect(_plan(MemoryPlanStore()).stoveColdBelow, 16);
  });

  test('il se règle au demi-degré, borné, et reste après un réglage des vacances', () async {
    final vStore = MemoryPlanStore();
    final vPlan = _plan(vStore);

    await vPlan.setStoveColdBelow(17.26);
    expect(vPlan.stoveColdBelow, 17.5);
    await vPlan.setStoveColdBelow(3);
    expect(vPlan.stoveColdBelow, 10);
    await vPlan.setStoveColdBelow(40);
    expect(vPlan.stoveColdBelow, 22);

    await vPlan.setStoveColdBelow(18);
    await vPlan.setVacation(null);
    await vPlan.setRules(const []);
    expect(vStore.saved.stoveColdBelow, 18);
  });

  group('fichier reglages-plan.json', () {
    late Directory vFolder;

    setUp(() => vFolder = Directory.systemTemp.createTempSync('home_plan_reglages'));
    tearDown(() => vFolder.deleteSync(recursive: true));

    test('le seuil est écrit puis relu', () async {
      final vStore = FilePlanStore(vFolder);

      await vStore.save(const PlanSettings(stoveColdBelow: 14.5));

      expect((await vStore.load()).stoveColdBelow, 14.5);
    });

    test('sans fichier, abîmé ou hors bornes : valeur par défaut', () async {
      final vStore = FilePlanStore(vFolder);
      expect((await vStore.load()).stoveColdBelow, 16);

      for (final vContent in ['pas du json', '{"poeleFroidSous": 99}', '[1]', '{}']) {
        File('${vFolder.path}/reglages-plan.json').writeAsStringSync(vContent);
        expect((await vStore.load()).stoveColdBelow, 16, reason: vContent);
      }
    });
  });
}
