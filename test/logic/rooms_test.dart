import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/advice.dart';
import 'package:home/logic/house.dart';
import 'package:home/logic/reading.dart';
import 'package:home/logic/rooms.dart';

Sensor _sensor(String pName, double pTemp, double pHumidity) => Sensor(
  name: pName,
  readings: [Reading(at: DateTime(2026, 11, 28, 8), temp: pTemp, humidity: pHumidity)],
);

void main() {
  test('une cave ou un garage visent une plage plus humide', () {
    expect(humidityRangeFor('Chambre').max, 60);
    expect(humidityRangeFor('Cave à vin').min, 45);
    expect(humidityRangeFor('GARAGE').max, 70);
  });

  test('les pièces sont rangées de la plus fraîche à la plus chaude', () {
    final vHouse = const House()
        .withPlace('a', const SensorPlace(room: 'Salon', floor: 0))
        .withPlace('b', const SensorPlace(room: 'Chambre', floor: 1))
        .withPlace('c', const SensorPlace(outdoor: true))
        .withPlace('d', const SensorPlace(floor: 0));
    final vRooms = roomStatuses([
      _sensor('a', 21, 50),
      _sensor('b', 17, 65),
      _sensor('c', 3, 90),
      _sensor('d', 19, 50),
      const Sensor(name: 'e'),
    ], vHouse);

    expect(vRooms.map((pRoom) => pRoom.room), ['Chambre', 'Salon']);
    expect(vRooms.first.floor, 1);
    expect(vRooms.first.state, HumidityState.humid);
    expect(vRooms.last.state, HumidityState.fine);
  });

  test('deux capteurs d\'une même pièce se moyennent, sans tenir compte de la casse', () {
    final vHouse = const House()
        .withPlace('a', const SensorPlace(room: 'Salon', floor: 0))
        .withPlace('b', const SensorPlace(room: 'salon ', floor: 1));
    final vRooms = roomStatuses([_sensor('a', 20, 30), _sensor('b', 22, 40)], vHouse);

    expect(vRooms, hasLength(1));
    expect(vRooms.single.temp, 21);
    expect(vRooms.single.humidity, 35);
    expect(vRooms.single.floor, isNull);
    expect(vRooms.single.state, HumidityState.dry);
    expect(vRooms.single.sensors, ['a', 'b']);
  });

  group('conseils', () {
    RoomStatus room(double pTemp, double pHumidity) => RoomStatus(
      room: 'Chambre',
      floor: 1,
      sensors: const ['a'],
      temp: pTemp,
      humidity: pHumidity,
      range: const HumidityRange(40, 60),
    );
    final vDry = Reading(at: DateTime(2026, 11, 28), temp: 2, humidity: 60);
    final vWet = Reading(at: DateTime(2026, 11, 28), temp: 20, humidity: 95);

    test('humide dedans et dehors plus sec : aérer', () {
      expect(adviceFor([room(20, 70)], vDry).single.kind, AdviceKind.ventilate);
    });

    test('humide dedans et dehors aussi chargé en eau : garder fermé', () {
      expect(adviceFor([room(20, 70)], vWet).single.kind, AdviceKind.keepClosed);
    });

    test('humide sans relevé extérieur : aucun conseil', () {
      expect(adviceFor([room(20, 70)], null), isEmpty);
    });

    test('air sec : le dire, même sans extérieur', () {
      expect(adviceFor([room(20, 30)], null).single.kind, AdviceKind.dryAir);
    });

    test('dans la plage : rien à dire', () {
      expect(adviceFor([room(20, 50)], vDry), isEmpty);
    });
  });
}
