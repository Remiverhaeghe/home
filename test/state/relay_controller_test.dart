import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/relay.dart';
import 'package:home/state/relay_controller.dart';
import 'package:home/storage/relay_store.dart';

import '../support/fake_relay.dart';

void main() {
  const vGarage = RelayButton(name: 'Garage', host: '192.168.1.40', kind: RelayKind.garage);
  late FakeRelayLink vLink;
  late MemoryRelayStore vStore;
  late DateTime vNow;
  late RelayController vController;

  setUp(() {
    vLink = FakeRelayLink();
    vStore = MemoryRelayStore();
    vNow = DateTime(2026, 12, 1, 8);
    vController = RelayController(vStore, vLink, clock: () => vNow);
  });

  group('ajout', () {
    test('un bouton valide est rangé nettoyé et enregistré', () async {
      final vProblem = await vController.add(
        const RelayButton(name: ' Garage ', host: ' 192.168.1.40 ', pulseSeconds: 50),
      );

      expect(vProblem, isNull);
      expect(vController.buttons.single.name, 'Garage');
      expect(vController.buttons.single.host, '192.168.1.40');
      expect(vController.buttons.single.pulseSeconds, maxPulseSeconds);
      expect(vStore.saved, hasLength(1));
    });

    test('un nom vide est refusé', () async {
      expect(
        await vController.add(const RelayButton(name: '  ', host: '192.168.1.40')),
        RelayAddProblem.emptyName,
      );
      expect(vController.buttons, isEmpty);
    });

    test('une adresse hors de la maison est refusée', () async {
      expect(
        await vController.add(const RelayButton(name: 'Garage', host: '8.8.8.8')),
        RelayAddProblem.notPrivate,
      );
      expect(vStore.saved, isEmpty);
    });
  });

  test('load relit les boutons enregistrés', () async {
    vStore.saved = [vGarage];

    await vController.load();

    expect(vController.buttons.single.name, 'Garage');
  });

  group('appui', () {
    test('envoie l\'impulsion au boîtier', () async {
      expect(await vController.press(vGarage), PressResult.sent);
      expect(vLink.pulses.single.host, '192.168.1.40');
    });

    test('un second appui trop proche est ignoré, puis permis après le délai', () async {
      await vController.press(vGarage);
      vNow = vNow.add(pressLockout - const Duration(seconds: 1));

      expect(await vController.press(vGarage), PressResult.tooSoon);
      expect(vLink.pulses, hasLength(1));

      vNow = vNow.add(const Duration(seconds: 1));

      expect(await vController.press(vGarage), PressResult.sent);
      expect(vLink.pulses, hasLength(2));
    });

    test('un autre bouton n\'est pas bloqué', () async {
      await vController.press(vGarage);

      expect(
        await vController.press(const RelayButton(name: 'Velux', host: '192.168.1.41')),
        PressResult.sent,
      );
    });

    test('un boîtier muet : échec, et rien n\'est compté comme appui', () async {
      vLink.fail = true;

      expect(await vController.press(vGarage), PressResult.failed);

      vLink.fail = false;

      expect(await vController.press(vGarage), PressResult.sent);
    });
  });

  test('retirer un bouton l\'enlève de la liste et du fichier', () async {
    await vController.add(vGarage);
    final vAdded = vController.buttons.single;

    await vController.remove(vAdded);

    expect(vController.buttons, isEmpty);
    expect(vStore.saved, isEmpty);
  });
}
