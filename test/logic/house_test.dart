import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/house.dart';
import 'package:home/logic/reading.dart';

void main() {
  test('les coordonnées doivent exister sur Terre', () {
    expect(isValidCoordinates(48.85, 2.35), isTrue);
    expect(isValidCoordinates(-90, 180), isTrue);
    expect(isValidCoordinates(90.1, 0), isFalse);
    expect(isValidCoordinates(0, -180.5), isFalse);
  });

  test('un emplacement vide retire celui du capteur', () {
    final vHouse = const House().withPlace('A', const SensorPlace(room: 'Salon', floor: 0));

    expect(vHouse.placeOf('A').room, 'Salon');
    expect(vHouse.withPlace('A', const SensorPlace(room: ' ')).places, isEmpty);
    expect(const House().placeOf('Z').isEmpty, isTrue);
  });

  test('dehors, le niveau est oublié', () {
    final vHouse = const House().withPlace('A', const SensorPlace(floor: 2, outdoor: true));

    expect(vHouse.placeOf('A').floor, isNull);
    expect(vHouse.placeOf('A').outdoor, isTrue);
  });

  test('les capteurs sont groupés par niveau, puis dehors, puis sans emplacement', () {
    const vSensors = [
      Sensor(name: 'cave'),
      Sensor(name: 'toit'),
      Sensor(name: 'dehors'),
      Sensor(name: 'perdu'),
      Sensor(name: 'salon'),
    ];
    final vHouse = const House()
        .withPlace('cave', const SensorPlace(floor: -1))
        .withPlace('toit', const SensorPlace(floor: 3))
        .withPlace('dehors', const SensorPlace(outdoor: true))
        .withPlace('salon', const SensorPlace(room: 'Salon', floor: 0));

    final vGroups = groupSensors(vSensors, vHouse);

    expect(vGroups.map((pGroup) => pGroup.floor), [-1, 0, 3, null, null]);
    expect(vGroups[3].outdoor, isTrue);
    expect(vGroups[4].sensors.single.name, 'perdu');
  });

  test('le fichier garde le lieu et les emplacements', () {
    final vHouse = const House(
      location: HouseLocation(label: 'Lyon', latitude: 45.76, longitude: 4.83),
    ).withPlace('A', const SensorPlace(room: 'Chambre', floor: 1));

    final vBack = parseHouse(houseJson(vHouse));

    expect(vBack.location?.label, 'Lyon');
    expect(vBack.location?.latitude, 45.76);
    expect(vBack.placeOf('A').room, 'Chambre');
    expect(vBack.placeOf('A').floor, 1);
  });

  test('un fichier abîmé, d\'une autre version ou à moitié faux se relit sans planter', () {
    expect(parseHouse('pas du json').places, isEmpty);
    expect(parseHouse('{"version":2}').location, isNull);
    final vBack = parseHouse(
      '{"version":1,"location":{"label":"X","latitude":200,"longitude":0},'
      '"places":{"A":{"room":"Salon","floor":9},"B":3,"C":{"room":"","floor":null}}}',
    );

    expect(vBack.location, isNull);
    expect(vBack.places.keys, ['A']);
    expect(vBack.placeOf('A').floor, isNull);
  });

  test('la hauteur sous plafond se lit avec une virgule ou un point, dans les bornes', () {
    expect(parseCeiling('5,5'), 5.5);
    expect(parseCeiling(' 6 '), 6);
    expect(parseCeiling('1,4'), isNull);
    expect(parseCeiling('13'), isNull);
    expect(parseCeiling('haut'), isNull);
    expect(parseCeiling(''), isNull);
  });

  test('la hauteur sous plafond est rangée et relue avec l\'emplacement', () {
    final vHouse = const House().withPlace(
      'A',
      const SensorPlace(room: 'Salon', floor: 0, ceiling: 5.5),
    );

    expect(parseHouse(houseJson(vHouse)).placeOf('A').ceiling, 5.5);
  });

  test('une hauteur seule suffit à garder l\'emplacement, une hauteur absurde est ignorée', () {
    final vOnly = const House().withPlace('A', const SensorPlace(ceiling: 6));
    expect(vOnly.places.keys, ['A']);

    final vBad = parseHouse(
      '{"version":1,"places":{"A":{"room":"Salon","floor":0,"outdoor":false,"ceiling":99}}}',
    );
    expect(vBad.placeOf('A').room, 'Salon');
    expect(vBad.placeOf('A').ceiling, isNull);
  });

  group('surface et volume', () {
    test('la surface se lit avec une virgule ou un point, dans les bornes', () {
      expect(parseArea('24,5'), 24.5);
      expect(parseArea('30'), 30);
      expect(parseArea('0,5'), isNull);
      expect(parseArea('501'), isNull);
      expect(parseArea('grand'), isNull);
    });

    test('le volume est la surface fois la hauteur, et manque si l\'une manque', () {
      expect(const SensorPlace(area: 20, ceiling: 5.5).volume, 110);
      expect(const SensorPlace(area: 20).volume, isNull);
      expect(const SensorPlace(ceiling: 5.5).volume, isNull);
    });

    test('monter l\'air de 1 °C demande 0,335 Wh par m³', () {
      expect(airEnergyKwh(100, 1), closeTo(0.0335, 1e-9));
      expect(airEnergyKwh(100, 3), closeTo(0.1005, 1e-9));
    });

    test('la surface est rangée et relue, hors bornes elle est ignorée', () {
      final vHouse = const House().withPlace('A', const SensorPlace(room: 'Salon', area: 32.5));

      expect(parseHouse(houseJson(vHouse)).placeOf('A').area, 32.5);
      expect(const House().withPlace('B', const SensorPlace(area: 40)).places.keys, ['B']);
      expect(
        parseHouse(
          '{"version":1,"places":{"A":{"room":"Salon","floor":0,"outdoor":false,"area":9999}}}',
        ).placeOf('A').area,
        isNull,
      );
    });
  });
}
