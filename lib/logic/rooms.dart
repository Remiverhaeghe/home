/// Les pièces de la maison : mesure du moment, humidité visée et pièces à surveiller.
library;

import 'house.dart';
import 'reading.dart';

/// Plage d'humidité relative visée dans une pièce, en %.
class HumidityRange {
  const HumidityRange(this.min, this.max);

  final double min;
  final double max;
}

/// Mots du nom d'une pièce qui la rangent parmi les caves et sous-sols, plus humides par nature.
const _cellarWords = ['cave', 'sous-sol', 'sous sol', 'cellier', 'garage'];

/// Plage visée selon le nom de la pièce : 40 à 60 % partout, 45 à 70 % dans une cave ou un garage.
HumidityRange humidityRangeFor(String pRoom) {
  final vName = pRoom.toLowerCase();
  final vCellar = _cellarWords.any(vName.contains);

  return vCellar ? const HumidityRange(45, 70) : const HumidityRange(40, 60);
}

/// Position de l'humidité d'une pièce par rapport à sa plage.
enum HumidityState { dry, fine, humid }

/// Mesure du moment dans une pièce : moyenne des derniers relevés de ses capteurs.
class RoomStatus {
  const RoomStatus({
    required this.room,
    required this.floor,
    required this.sensors,
    required this.temp,
    required this.humidity,
    required this.range,
  });

  final String room;
  final int? floor;

  /// Identifiants des capteurs qui ont un relevé.
  final List<String> sensors;
  final double temp;
  final double humidity;
  final HumidityRange range;

  HumidityState get state => humidity < range.min
      ? HumidityState.dry
      : humidity > range.max
      ? HumidityState.humid
      : HumidityState.fine;
}

/// Pièces nommées, de la plus froide à la plus chaude. Les capteurs du dehors, sans pièce ou sans
/// relevé sont ignorés ; la casse du nom ne compte pas.
List<RoomStatus> roomStatuses(List<Sensor> pSensors, House pHouse) {
  final vByRoom = <String, List<(Sensor, SensorPlace)>>{};
  for (final vSensor in pSensors) {
    final vPlace = pHouse.placeOf(vSensor.name);
    final vRoom = vPlace.room.trim();
    if (vPlace.outdoor || vRoom.isEmpty || vSensor.last == null) {
      continue;
    }
    vByRoom.putIfAbsent(vRoom.toLowerCase(), () => []).add((vSensor, vPlace));
  }
  final rResult = <RoomStatus>[];
  for (final vGroup in vByRoom.values) {
    var vTemp = 0.0;
    var vHumidity = 0.0;
    for (final (vSensor, _) in vGroup) {
      vTemp += vSensor.last!.temp;
      vHumidity += vSensor.last!.humidity;
    }
    final vName = vGroup.first.$2.room.trim();
    final vFloors = {for (final (_, vPlace) in vGroup) ?vPlace.floor};
    rResult.add(
      RoomStatus(
        room: vName,
        floor: vFloors.length == 1 ? vFloors.first : null,
        sensors: [for (final (vSensor, _) in vGroup) vSensor.name],
        temp: vTemp / vGroup.length,
        humidity: vHumidity / vGroup.length,
        range: humidityRangeFor(vName),
      ),
    );
  }
  rResult.sort((pA, pB) => pA.temp.compareTo(pB.temp));

  return rResult;
}
