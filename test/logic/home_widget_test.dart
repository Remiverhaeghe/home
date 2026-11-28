import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/home_widget.dart';
import 'package:home/logic/rooms.dart';

void main() {
  RoomStatus room(String pName, double pTemp) => RoomStatus(
    room: pName,
    floor: 0,
    sensors: const ['a'],
    temp: pTemp,
    humidity: 49.5,
    range: const HumidityRange(40, 60),
  );

  test('température arrondie au dixième, humidité à l\'unité', () {
    final vJson = jsonDecode(widgetJson([room('Salon', 20.46)], DateTime(2026, 12, 7))) as Map;
    final vSalon = (vJson['pieces'] as List).single as Map;

    expect(vSalon['temp'], 20.5);
    expect(vSalon['hum'], 50);
  });

  test('la casse ne change pas l\'ordre et le widget n\'en garde que quatre', () {
    final vJson =
        jsonDecode(
              widgetJson([
                room('cave', 12),
                room('Bureau', 19),
                room('Atelier', 15),
                room('Salon', 20),
                room('Chambre', 17),
              ], DateTime(2026, 12, 7)),
            )
            as Map;

    expect((vJson['pieces'] as List).map((pRoom) => (pRoom as Map)['nom']), [
      'Atelier',
      'Bureau',
      'cave',
      'Chambre',
    ]);
  });
}
