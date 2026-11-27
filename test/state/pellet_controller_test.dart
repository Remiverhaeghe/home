import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/pellet.dart';
import 'package:home/state/pellet_controller.dart';
import 'package:home/storage/pellet_store.dart';

import '../support/fake_pellet.dart';

const _stove = PelletStove(
  name: 'Poêle',
  host: '192.168.1.60',
  serial: '123456',
  password: 'abcd1234',
);

void main() {
  late FakePelletLink vLink;
  late MemoryPelletStore vStore;
  late PelletController vController;

  setUp(() {
    vLink = FakePelletLink();
    vStore = MemoryPelletStore(_stove);
    vController = PelletController(vStore, vLink);
  });

  test('le poêle enregistré se recharge', () async {
    await vController.load();

    expect(vController.stove?.name, 'Poêle');
  });

  test('l\'enregistrement refuse un nom vide, une adresse publique et des identifiants vides', () async {
    PelletStove make({String name = 'P', String host = '192.168.1.5', String serial = 's'}) =>
        PelletStove(name: name, host: host, serial: serial, password: 'p');

    expect(await vController.setup(make(name: ' ')), PelletSetupProblem.emptyName);
    expect(await vController.setup(make(host: '8.8.8.8')), PelletSetupProblem.notPrivate);
    expect(await vController.setup(make(serial: ' ')), PelletSetupProblem.noLogin);
    expect(vStore.saved, same(_stove));
  });

  test('un poêle valide est rangé sans espaces superflus', () async {
    final vProblem = await vController.setup(
      const PelletStove(name: ' Salon ', host: ' 192.168.1.9 ', serial: ' 42 ', password: ' pw '),
    );

    expect(vProblem, isNull);
    expect(vStore.saved?.name, 'Salon');
    expect(vStore.saved?.host, '192.168.1.9');
    expect(vStore.saved?.serial, '42');
    expect(vStore.saved?.password, 'pw');
  });

  test('le relevé donne l\'état, une panne le signale', () async {
    await vController.load();
    await vController.refresh();

    expect(vController.state?.roomC, 18.5);
    expect(vController.failed, isFalse);

    vLink.fail = true;
    await vController.refresh();

    expect(vController.failed, isTrue);
  });

  test('sans poêle, un relevé ou un ordre ne fait rien', () async {
    vStore.saved = null;
    await vController.load();
    await vController.refresh();

    expect(vController.state, isNull);
    expect(await vController.setPower(pOn: true), PelletResult.refused);
  });

  test('la marche et la consigne sont envoyées puis relues', () async {
    await vController.load();

    expect(await vController.setPower(pOn: true), PelletResult.done);
    expect(vController.state?.isOn, isTrue);
    expect(await vController.setTarget(22.3), PelletResult.done);
    expect(vLink.powers, [true]);
    expect(vLink.targets, [22.5]);
    expect(vController.state?.targetC, 22.5);
  });

  test('un poêle muet fait échouer l\'ordre', () async {
    await vController.load();
    vLink.fail = true;

    expect(await vController.setPower(pOn: true), PelletResult.failed);
    expect(await vController.setTarget(21), PelletResult.failed);
  });

  test('retirer le poêle vide le fichier', () async {
    await vController.load();
    await vController.refresh();
    await vController.remove();

    expect(vController.stove, isNull);
    expect(vController.state, isNull);
    expect(vStore.saved, isNull);
  });
}
