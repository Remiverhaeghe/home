import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/boost.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/plan_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/plan_store.dart';
import 'package:home/storage/sensor_store.dart';

import '../support/fake_daikin.dart';

final _now = DateTime(2026, 12, 7, 14);

PlanController _plan(PlanStore pStore) => PlanController(
  pStore,
  AcController(MemoryAcStore(), FakeDaikinLink()),
  SensorsController(MemorySensorStore()),
);

void main() {
  test('un coup de chaud est borné, arrondi, et se termine à l\'heure dite', () async {
    final vPlan = _plan(MemoryPlanStore());

    await vPlan.startBoost('h1', BoostKind.shower, 40, 1000, _now);

    final vBoost = vPlan.boostOf('h1', _now)!;
    expect(vBoost.temp, 28);
    expect(vBoost.until, _now.add(const Duration(minutes: 240)));
    expect(vPlan.boostOf('h1', _now.add(const Duration(minutes: 240))), isNull);
    expect(vPlan.boostOf('autre', _now), isNull);

    await vPlan.startBoost('h1', BoostKind.bath, 20.3, 1, _now);
    expect(vPlan.boostOf('h1', _now)!.temp, 20.5);
    expect(vPlan.boostOf('h1', _now)!.until, _now.add(const Duration(minutes: 15)));
  });

  test('un nouveau coup de chaud remplace celui de la même clim, pas ceux des autres', () async {
    final vPlan = _plan(MemoryPlanStore());
    await vPlan.startBoost('h1', BoostKind.shower, 24, 45, _now);
    await vPlan.startBoost('h2', BoostKind.laundry, 22, 180, _now);

    await vPlan.startBoost('h1', BoostKind.bath, 25, 90, _now);

    expect(vPlan.boosts, hasLength(2));
    expect(vPlan.boostOf('h1', _now)!.kind, BoostKind.bath);
    expect(vPlan.boostOf('h2', _now)!.kind, BoostKind.laundry);
  });

  test('arrêter retire le coup de chaud, et les autres réglages restent', () async {
    final vStore = MemoryPlanStore();
    final vPlan = _plan(vStore);
    await vPlan.setStoveColdBelow(18);
    await vPlan.startBoost('h1', BoostKind.shower, 24, 45, _now);

    await vPlan.stopBoost('h1');

    expect(vPlan.boostOf('h1', _now), isNull);
    expect(vStore.saved.stoveColdBelow, 18);
  });

  test('les coups de chaud sont rangés dans reglages-plan.json avec le seuil', () async {
    final vFolder = Directory.systemTemp.createTempSync('home_boost');
    addTearDown(() => vFolder.deleteSync(recursive: true));
    final vStore = FilePlanStore(vFolder);
    final vPlan = _plan(vStore);
    await vPlan.setStoveColdBelow(15);
    await vPlan.startBoost('h1', BoostKind.shower, 24, 45, _now);

    final vLoaded = await vStore.load();

    expect(vLoaded.stoveColdBelow, 15);
    expect(vLoaded.boosts.single.host, 'h1');

    File('${vFolder.path}/reglages-plan.json').writeAsStringSync('pas du json');
    expect((await vStore.load()).boosts, isEmpty);
  });
}
