import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/pellet.dart';
import 'package:home/logic/vacation.dart';
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

  group('arrêt sans ordre de Home', () {
    late FakePelletLink vLink;
    late PelletController vController;
    var vNow = DateTime(2026, 12, 7, 10);

    setUp(() async {
      vNow = DateTime(2026, 12, 7, 10);
      vLink = FakePelletLink();
      vController = PelletController(
        MemoryPelletStore(_stove),
        vLink,
        runsStore: MemoryPelletRunsStore(),
        clock: () => vNow,
      );
      await vController.load();
    });

    test('un poêle qui marchait et qui s\'éteint seul est signalé, jusqu\'au rallumage', () async {
      await vLink.setPower(_stove, pOn: true);
      await vController.refresh();
      expect(vController.unexpectedStopAt, isNull);

      vNow = vNow.add(const Duration(minutes: 5));
      await vLink.setPower(_stove, pOn: false);
      await vController.refresh();
      expect(vController.unexpectedStopAt, vNow);

      await vLink.setPower(_stove, pOn: true);
      await vController.refresh();
      expect(vController.unexpectedStopAt, isNull);
    });

    test('un arrêt demandé par Home n\'est pas signalé', () async {
      await vLink.setPower(_stove, pOn: true);
      await vController.refresh();

      await vController.setPower(pOn: false);

      expect(vController.unexpectedStopAt, isNull);
    });

    test('un arrêt refusé par le poêle laisse la détection active', () async {
      await vLink.setPower(_stove, pOn: true);
      await vController.refresh();
      vLink.fail = true;

      expect(await vController.setPower(pOn: false), PelletResult.failed);
      vLink.fail = false;
      await vLink.setPower(_stove, pOn: false);
      await vController.refresh();

      expect(vController.unexpectedStopAt, isNotNull);
    });

    test('un poêle déjà éteint à la première lecture ne donne rien', () async {
      await vController.refresh();

      expect(vController.unexpectedStopAt, isNull);
    });
  });

  group('arrêt programmé et stock', () {
    test(
      'le service éteint le poêle dans la fenêtre de l\'arrêt programmé, pas avant ni après',
      () async {
        final vLink = FakePelletLink();
        await vLink.setPower(_stove, pOn: true);
        final vController = PelletController(
          MemoryPelletStore(_stove),
          vLink,
          runsStore: MemoryPelletRunsStore(),
        );
        await vController.load();
        await vController.setStopAt(23 * 60);

        expect(await vController.refreshAndStopIfAway(null, DateTime(2026, 12, 7, 22, 50)), isTrue);
        expect(vLink.powers, isEmpty);

        expect(await vController.refreshAndStopIfAway(null, DateTime(2026, 12, 7, 23, 5)), isFalse);
        expect(vLink.powers, [false]);

        // Rallumé à la main plus tard : hors de la fenêtre, il reste allumé
        await vLink.setPower(_stove, pOn: true);
        expect(await vController.refreshAndStopIfAway(null, DateTime(2026, 12, 8, 8)), isTrue);
      },
    );

    test('le stock et l\'arrêt se rangent et se rechargent', () async {
      final vRunsStore = MemoryPelletRunsStore();
      final vController = PelletController(
        MemoryPelletStore(_stove),
        FakePelletLink(),
        runsStore: vRunsStore,
        clock: () => DateTime(2026, 12, 7, 9),
      );

      await vController.setStock(6);
      await vController.setStopAt(22 * 60);

      expect(vRunsStore.saved.stockBags, 6);
      expect(vRunsStore.saved.stockAt, DateTime(2026, 12, 7, 9));
      expect(vRunsStore.saved.stopAtMinute, 22 * 60);

      await vController.setStopAt(null);
      expect(vRunsStore.saved.stopAtMinute, isNull);
    });
  });
}
