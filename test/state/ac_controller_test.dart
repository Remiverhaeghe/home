import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/daikin.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/storage/ac_store.dart';

import '../support/fake_daikin.dart';

void main() {
  const vHost = '192.168.1.20';
  late FakeDaikinLink vLink;
  late MemoryAcStore vStore;
  late AcController vController;

  setUp(() {
    vLink = FakeDaikinLink()
      ..names[vHost] = 'Salon'
      ..states[vHost] = FakeDaikinLink.coolingAt22();
    vStore = MemoryAcStore();
    vController = AcController(vStore, vLink);
  });

  group('ajout', () {
    test('une climatisation qui répond est ajoutée sous son nom, enregistrée et lue', () async {
      final vProblem = await vController.add(' $vHost ');

      expect(vProblem, isNull);
      expect(vController.units.single.name, 'Salon');
      expect(vController.units.single.host, vHost);
      expect(vStore.saved.single.host, vHost);
      expect(vController.statusOf(vHost)!.state!.control.power, isTrue);
    });

    test('le nom choisi passe avant celui du module', () async {
      await vController.add(vHost, pName: ' Séjour ');

      expect(vController.units.single.name, 'Séjour');
    });

    test('un nom vide laisse le nom du module, et sans nom du tout l\'adresse sert de nom', () async {
      await vController.add(vHost, pName: '  ');
      expect(vController.units.single.name, 'Salon');

      vLink
        ..names['192.168.1.21'] = ''
        ..states['192.168.1.21'] = FakeDaikinLink.coolingAt22();
      await vController.add('192.168.1.21');
      expect(vController.units.last.name, '192.168.1.21');
    });

    test('une adresse d\'Internet est refusée sans appeler le module', () async {
      vLink.names['8.8.8.8'] = 'Intrus';

      expect(await vController.add('8.8.8.8'), AddProblem.notPrivate);
      expect(vController.units, isEmpty);
    });

    test('une climatisation déjà là n\'est pas ajoutée deux fois', () async {
      await vController.add(vHost);

      expect(await vController.add(vHost), AddProblem.alreadyKnown);
      expect(vController.units, hasLength(1));
    });

    test('un module qui ne répond pas n\'est pas ajouté', () async {
      expect(await vController.add('192.168.1.99'), AddProblem.unreachable);
      expect(vController.units, isEmpty);
      expect(vStore.saved, isEmpty);
    });

    test('la recherche rend les adresses trouvées par la liaison', () async {
      vLink.found.addAll(['192.168.1.20', '192.168.1.21']);

      expect(await vController.discover().toList(), ['192.168.1.20', '192.168.1.21']);
    });
  });

  group('lecture', () {
    test('charger rend les climatisations enregistrées', () async {
      vStore.saved = [const AcUnit(name: 'Salon', host: vHost)];

      await vController.load();

      expect(vController.units.single.name, 'Salon');
    });

    test('actualiser lit chaque appareil, un injoignable est marqué comme tel', () async {
      vStore.saved = [
        const AcUnit(name: 'Salon', host: vHost),
        const AcUnit(name: 'Cave', host: '192.168.1.22'),
      ];
      await vController.load();
      var vNotified = 0;
      vController.addListener(() => vNotified++);

      await vController.refresh();

      expect(vController.statusOf(vHost)!.failed, isFalse);
      expect(vController.statusOf('192.168.1.22')!.failed, isTrue);
      expect(vController.statusOf('192.168.1.22')!.state, isNull);
      expect(vNotified, 1);
    });

    test('un appareil inconnu n\'a pas encore d\'état', () {
      expect(vController.statusOf(vHost), isNull);
    });
  });

  group('commandes', () {
    setUp(() async => vController.add(vHost));

    test('arrêt : les six paramètres partent, puis l\'appareil est relu', () async {
      final vOk = await vController.setPower(vHost, pOn: false);

      expect(vOk, isTrue);
      expect(vLink.written.single.$1, vHost);
      expect(vLink.written.single.$2.toQuery(), 'pow=0&mode=3&stemp=22.0&shum=0&f_rate=A&f_dir=0');
      expect(vController.statusOf(vHost)!.state!.control.power, isFalse);
    });

    test('mode chaud', () async {
      await vController.setMode(vHost, DaikinMode.heat);

      expect(vLink.written.single.$2.modeCode, '4');
      expect(vController.statusOf(vHost)!.state!.control.mode, DaikinMode.heat);
    });

    test('un mode que Home ne commande pas n\'envoie rien', () async {
      expect(await vController.setMode(vHost, DaikinMode.dry), isFalse);
      expect(vLink.written, isEmpty);
    });

    test('consigne', () async {
      await vController.setSetpoint(vHost, 23.5);

      expect(vLink.written.single.$2.setpoint, '23.5');
      expect(vController.statusOf(vHost)!.state!.control.setpointDegrees, 23.5);
    });

    test('un appareil qui refuse la commande est signalé, et relu quand même', () async {
      vLink.refuseWrites = true;

      expect(await vController.setPower(vHost, pOn: false), isFalse);
      expect(vController.statusOf(vHost)!.state!.control.power, isTrue);
    });

    test('un appareil qui ne répond plus n\'est pas commandé', () async {
      vLink.unreachable.add(vHost);
      await vController.refresh();

      expect(await vController.setPower(vHost, pOn: false), isFalse);
      expect(vLink.written, isEmpty);
    });

    test('un appareil jamais lu n\'est pas commandé', () async {
      expect(await vController.setPower('192.168.1.50', pOn: true), isFalse);
    });
  });

  group('liste', () {
    setUp(() async => vController.add(vHost));

    test('relier un capteur l\'enregistre, le délier l\'efface', () async {
      await vController.linkSensor(vHost, 'TP357 (1A2B)');
      expect(vStore.saved.single.sensorName, 'TP357 (1A2B)');

      await vController.linkSensor(vHost, null);
      expect(vStore.saved.single.sensorName, isNull);
    });

    test('relier un capteur ne touche pas aux autres climatisations', () async {
      vLink
        ..names['192.168.1.21'] = 'Chambre'
        ..states['192.168.1.21'] = FakeDaikinLink.coolingAt22();
      await vController.add('192.168.1.21');

      await vController.linkSensor(vHost, 'Cave');

      expect(vController.units.last.sensorName, isNull);
    });

    test('retirer une climatisation l\'enlève de la liste, de l\'état et du fichier', () async {
      await vController.remove(vHost);

      expect(vController.units, isEmpty);
      expect(vController.statusOf(vHost), isNull);
      expect(vStore.saved, isEmpty);
    });
  });
}
