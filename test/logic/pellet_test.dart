import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/pellet.dart';

const _reply = '''
error_MODO_on_off=0
on_off=1
modo_operacion=1
modo_func=1
estado=7
consigna_potencia=3
consigna_temperatura=21.5
temperatura=19.4
temperatura_ext=---.-
''';

const _stove = PelletStove(
  name: 'Poêle',
  host: '192.168.1.60',
  serial: '123456',
  password: 'abcd1234',
);

void main() {
  test('la réponse d\'état est lue ligne à ligne', () {
    final vState = PelletState.parse(_reply)!;

    expect(vState.isOn, isTrue);
    expect(vState.phase, PelletPhase.running);
    expect(vState.roomC, 19.4);
    expect(vState.targetC, 21.5);
    expect(vState.powerLevel, 3);
  });

  test('l\'arrêt, la marche et une étape inconnue se distinguent', () {
    PelletPhase phase(int pCode) => PelletState.parse(
      'on_off=0\nestado=$pCode\ntemperatura=18.0\nconsigna_temperatura=20.0',
    )!.phase;

    expect(phase(0), PelletPhase.off);
    expect(phase(7), PelletPhase.running);
    expect(phase(4), PelletPhase.other);
  });

  test('une réponse incomplète n\'est pas prise pour un poêle éteint', () {
    expect(PelletState.parse(''), isNull);
    expect(PelletState.parse('on_off=0\nestado=0'), isNull);
    expect(PelletState.parse('on_off=x\nestado=0\ntemperatura=1\nconsigna_temperatura=2'), isNull);
  });

  test('sans niveau de puissance lisible, il reste vide', () {
    final vState = PelletState.parse(
      'on_off=1\nestado=7\ntemperatura=18.0\nconsigna_temperatura=20.0\nconsigna_potencia=--',
    )!;

    expect(vState.powerLevel, isNull);
  });

  test('les corps de requête sont ceux du poêle', () {
    expect(pelletReadBody, 'idOperacion=1002');
    expect(pelletPowerBody(pOn: true), 'idOperacion=1013&on_off=1');
    expect(pelletPowerBody(pOn: false), 'idOperacion=1013&on_off=0');
    expect(pelletTargetBody(20), 'idOperacion=1019&temperatura=20.0');
  });

  test('la consigne est ramenée au demi-degré et aux bornes', () {
    expect(pelletClampTarget(20.3), 20.5);
    expect(pelletClampTarget(3), pelletMinTarget);
    expect(pelletClampTarget(45), pelletMaxTarget);
  });

  test('l\'adresse du poêle est en HTTPS sur le port 8000, réseau privé seulement', () {
    expect(pelletUri(_stove).toString(), 'https://192.168.1.60:8000/recepcion_datos_4.cgi');
    expect(
      () => pelletUri(const PelletStove(name: 'x', host: '8.8.8.8', serial: 's', password: 'p')),
      throwsFormatException,
    );
  });

  test('le fichier garde le poêle, ou rien', () {
    final vBack = parsePellet(pelletJson(_stove))!;

    expect(vBack.name, 'Poêle');
    expect(vBack.host, '192.168.1.60');
    expect(vBack.serial, '123456');
    expect(vBack.password, 'abcd1234');
    expect(parsePellet(pelletJson(null)), isNull);
    expect(parsePellet('pas du json'), isNull);
    expect(parsePellet('{"stove":{"name":1}}'), isNull);
    expect(parsePellet('[]'), isNull);
  });
}
