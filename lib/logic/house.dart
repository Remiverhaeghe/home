/// La maison : où elle se trouve et où se trouve chaque capteur.
library;

import 'dart:convert';

import 'reading.dart';

/// Lieu de la maison, saisi à la main : un nom et des coordonnées. Aucun GPS n'est lu.
class HouseLocation {
  const HouseLocation({required this.label, required this.latitude, required this.longitude});

  final String label;
  final double latitude;
  final double longitude;
}

/// Coordonnées possibles sur Terre.
bool isValidCoordinates(double pLatitude, double pLongitude) =>
    pLatitude >= -90 && pLatitude <= 90 && pLongitude >= -180 && pLongitude <= 180;

/// Niveaux proposés : -1 sous-sol, 0 rez-de-chaussée, 1 et 2 étages, 3 combles.
const floorLevels = [-1, 0, 1, 2, 3];

/// Où se trouve un capteur : la pièce, le niveau, ou dehors.
class SensorPlace {
  const SensorPlace({this.room = '', this.floor, this.outdoor = false});

  final String room;

  /// Un des [floorLevels], null quand le niveau n'est pas dit.
  final int? floor;
  final bool outdoor;

  bool get isEmpty => room.trim().isEmpty && floor == null && !outdoor;
}

class House {
  const House({this.location, this.places = const {}});

  final HouseLocation? location;

  /// Emplacement de chaque capteur, par identifiant.
  final Map<String, SensorPlace> places;

  SensorPlace placeOf(String pSensorName) => places[pSensorName] ?? const SensorPlace();

  House withLocation(HouseLocation? pLocation) => House(location: pLocation, places: places);

  /// Range l'emplacement d'un capteur ; un emplacement vide le retire.
  House withPlace(String pSensorName, SensorPlace pPlace) {
    final vPlaces = {...places};
    if (pPlace.isEmpty) {
      vPlaces.remove(pSensorName);
    } else {
      vPlaces[pSensorName] = SensorPlace(
        room: pPlace.room.trim(),
        floor: pPlace.outdoor ? null : pPlace.floor,
        outdoor: pPlace.outdoor,
      );
    }

    return House(location: location, places: vPlaces);
  }
}

/// Un groupe de capteurs de la liste : un niveau, l'extérieur, ou les capteurs sans emplacement.
class SensorGroup {
  const SensorGroup({required this.sensors, this.floor, this.outdoor = false});

  final List<Sensor> sensors;
  final int? floor;
  final bool outdoor;
}

/// Capteurs rangés par niveau croissant, puis dehors, puis ceux sans emplacement.
List<SensorGroup> groupSensors(List<Sensor> pSensors, House pHouse) {
  final vByFloor = <int, List<Sensor>>{};
  final vOutdoor = <Sensor>[];
  final vOther = <Sensor>[];
  for (final vSensor in pSensors) {
    final vPlace = pHouse.placeOf(vSensor.name);
    if (vPlace.outdoor) {
      vOutdoor.add(vSensor);
    } else if (vPlace.floor != null) {
      vByFloor.putIfAbsent(vPlace.floor!, () => []).add(vSensor);
    } else {
      vOther.add(vSensor);
    }
  }
  final vFloors = vByFloor.keys.toList()..sort();

  return [
    for (final vFloor in vFloors) SensorGroup(floor: vFloor, sensors: vByFloor[vFloor]!),
    if (vOutdoor.isNotEmpty) SensorGroup(outdoor: true, sensors: vOutdoor),
    if (vOther.isNotEmpty) SensorGroup(sensors: vOther),
  ];
}

/// Fichier `maison.json`, version 1.
String houseJson(House pHouse) => jsonEncode({
  'version': 1,
  'location': pHouse.location == null
      ? null
      : {
          'label': pHouse.location!.label,
          'latitude': pHouse.location!.latitude,
          'longitude': pHouse.location!.longitude,
        },
  'places': {
    for (final vEntry in pHouse.places.entries)
      vEntry.key: {
        'room': vEntry.value.room,
        'floor': vEntry.value.floor,
        'outdoor': vEntry.value.outdoor,
      },
  },
});

/// Relit le fichier ; un fichier abîmé ou d'une autre version donne une maison vide.
House parseHouse(String pText) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pText);
  } on FormatException {
    return const House();
  }
  if (vRoot is! Map<String, dynamic> || vRoot['version'] != 1) {
    return const House();
  }
  HouseLocation? vLocation;
  final vRawLocation = vRoot['location'];
  if (vRawLocation is Map<String, dynamic>) {
    final vLabel = vRawLocation['label'];
    final vLat = vRawLocation['latitude'];
    final vLon = vRawLocation['longitude'];
    if (vLabel is String && vLat is num && vLon is num && isValidCoordinates(vLat.toDouble(), vLon.toDouble())) {
      vLocation = HouseLocation(label: vLabel, latitude: vLat.toDouble(), longitude: vLon.toDouble());
    }
  }
  final vPlaces = <String, SensorPlace>{};
  final vRawPlaces = vRoot['places'];
  if (vRawPlaces is Map<String, dynamic>) {
    for (final vEntry in vRawPlaces.entries) {
      final vValue = vEntry.value;
      if (vValue is! Map<String, dynamic>) {
        continue;
      }
      final vRoom = vValue['room'];
      final vFloor = vValue['floor'];
      final vPlace = SensorPlace(
        room: vRoom is String ? vRoom : '',
        floor: vFloor is int && floorLevels.contains(vFloor) ? vFloor : null,
        outdoor: vValue['outdoor'] == true,
      );
      if (!vPlace.isEmpty) {
        vPlaces[vEntry.key] = vPlace;
      }
    }
  }

  return House(location: vLocation, places: vPlaces);
}
