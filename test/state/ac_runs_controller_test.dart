import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/storage/ac_runs_store.dart';
import 'package:home/storage/ac_store.dart';

import '../support/fake_daikin.dart';

const _host = '192.168.1.20';

void main() {
  late FakeDaikinLink vLink;
  late MemoryAcRunsStore vRunsStore;
  var vNow = DateTime(2026, 12, 7, 10);

  AcController controller() => AcController(
    MemoryAcStore([const AcUnit(name: 'Salon', host: _host)]),
    vLink,
    runsStore: vRunsStore,
    clock: () => vNow,
  );

  setUp(() {
    vNow = DateTime(2026, 12, 7, 10);
    vLink = FakeDaikinLink()..states[_host] = FakeDaikinLink.coolingAt22();
    vRunsStore = MemoryAcRunsStore();
  });

  test('chaque lecture d\'une clim en marche compte ses minutes', () async {
    final vController = controller();
    await vController.load();

    await vController.refresh();
    vNow = vNow.add(const Duration(minutes: 5));
    await vController.refresh();
    vNow = vNow.add(const Duration(minutes: 5));
    await vController.refresh();

    expect(vController.runs.logOf(_host).minutesByDay['2026-12-07'], 10);
    expect(vRunsStore.saved.logOf(_host).minutesByDay['2026-12-07'], 10);
  });

  test('une clim qui ne répond pas n\'ajoute rien', () async {
    vLink.unreachable.add(_host);
    final vController = controller();
    await vController.load();

    await vController.refresh();

    expect(vController.runs.logs, isEmpty);
  });

  test('les réglages de coût se rangent et se rechargent', () async {
    final vController = controller();
    await vController.load();

    await vController.setHeating(
      pKwByHost: {_host: 1.4},
      pPricePerKwh: 0.22,
      pMonthlyBudget: 90,
    );

    final vOther = controller();
    await vOther.load();
    expect(vOther.runs.kwByHost, {_host: 1.4});
    expect(vOther.runs.pricePerKwh, 0.22);
    expect(vOther.runs.monthlyBudget, 90);
  });
}
