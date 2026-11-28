import 'dart:convert';

import 'rooms.dart';

/// Nombre de pièces affichées par le widget d'écran d'accueil : il n'en tient pas plus.
const widgetRoomsMax = 4;

/// Contenu de `widget.json`, lu par le widget Android : les pièces par ordre alphabétique, avec
/// leur température et leur humidité du moment. Le widget ne fait que l'afficher.
String widgetJson(List<RoomStatus> pRooms, DateTime pNow) {
  final vSorted = [...pRooms]
    ..sort((pA, pB) => pA.room.toLowerCase().compareTo(pB.room.toLowerCase()));

  return jsonEncode({
    'at': pNow.toIso8601String(),
    'pieces': [
      for (final vRoom in vSorted.take(widgetRoomsMax))
        {
          'nom': vRoom.room,
          'temp': double.parse(vRoom.temp.toStringAsFixed(1)),
          'hum': vRoom.humidity.round(),
        },
    ],
  });
}
