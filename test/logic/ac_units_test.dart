import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';

void main() {
  test('écrire puis relire rend les mêmes climatisations', () {
    final vBack = parseAcUnits(
      acUnitsJson([
        const AcUnit(name: 'Salon', host: '192.168.1.20', sensorName: 'TP357 (1A2B)'),
        const AcUnit(name: 'Chambre', host: '192.168.1.21'),
      ]),
    );

    expect(vBack, hasLength(2));
    expect(vBack[0].name, 'Salon');
    expect(vBack[0].host, '192.168.1.20');
    expect(vBack[0].sensorName, 'TP357 (1A2B)');
    expect(vBack[1].sensorName, isNull);
  });

  test('une climatisation sans capteur n\'écrit pas de capteur', () {
    expect(
      acUnitsJson([const AcUnit(name: 'Salon', host: '192.168.1.20')]).contains('sensor'),
      isFalse,
    );
  });

  test('un texte abîmé, une autre version ou une autre forme donnent une liste vide', () {
    expect(parseAcUnits('pas du json'), isEmpty);
    expect(parseAcUnits('[1]'), isEmpty);
    expect(parseAcUnits('{"version": 9, "units": []}'), isEmpty);
    expect(parseAcUnits('{"version": 1}'), isEmpty);
  });

  test('une entrée sans nom ou sans adresse est ignorée', () {
    final vUnits = parseAcUnits('''
{"version": 1, "units": [
  {"name": " ", "host": "192.168.1.20"},
  {"name": "Salon", "host": ""},
  {"name": "Salon"},
  "intrus",
  {"name": "Cave", "host": "192.168.1.22", "sensor": 3}
]}
''');

    expect(vUnits, hasLength(1));
    expect(vUnits.single.name, 'Cave');
    expect(vUnits.single.sensorName, isNull);
  });

  test('relier ou délier un capteur ne change pas le reste', () {
    const vUnit = AcUnit(name: 'Salon', host: '192.168.1.20');

    final vLinked = vUnit.withSensor('Cave');

    expect(vLinked.sensorName, 'Cave');
    expect(vLinked.host, '192.168.1.20');
    expect(vLinked.withSensor(null).sensorName, isNull);
  });
}
