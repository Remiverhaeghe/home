import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/pellet.dart';
import 'package:home/state/pellet_controller.dart';
import 'package:home/storage/pellet_runs_store.dart';
import 'package:home/storage/pellet_store.dart';

import '../support/fake_pellet.dart';

const _stove = PelletStove(
  name: 'Poêle',
  host: '192.168.1.60',
  serial: '123456',
  password: 'abcd1234',
);

void main() {
  test('chaque lecture de l\'état est rangée dans le journal de marche', () async {
    var vNow = DateTime(2026, 12, 7, 10);
    final vRunsStore = MemoryPelletRunsStore();
    final vLink = FakePelletLink();
    final vController = PelletController(
      MemoryPelletStore(_stove),
      vLink,
      runsStore: vRunsStore,
      clock: () => vNow,
    );
    await vController.load();

    await vController.refresh();
    expect(vRunsStore.saved.lastAt, vNow);

    await vLink.setPower(_stove, pOn: true);
    vNow = vNow.add(const Duration(minutes: 5));
    await vController.refresh();
    vNow = vNow.add(const Duration(minutes: 5));
    await vController.refresh();

    expect(vRunsStore.saved.minutesByDay['2026-12-07'], 5);
    expect(vRunsStore.saved.lastOn, isTrue);
  });

  test('le débit se range, et se recharge', () async {
    final vRunsStore = MemoryPelletRunsStore();
    final vController = PelletController(
      MemoryPelletStore(_stove),
      FakePelletLink(),
      runsStore: vRunsStore,
    );

    await vController.setFlow(pKgPerHour: 1.3, pBagKg: 15, pBagPrice: 7);
    expect(vController.runs.kgPerHour, 1.3);
    expect(vController.runs.bagPrice, 7);
    expect(vRunsStore.saved.kgPerHour, 1.3);

    final vOther = PelletController(
      MemoryPelletStore(_stove),
      FakePelletLink(),
      runsStore: vRunsStore,
    );
    await vOther.load();
    expect(vOther.runs.kgPerHour, 1.3);
  });
}
