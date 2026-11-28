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

/// Hauteur sous plafond acceptée, en mètres : de quoi couvrir un rampant bas comme un double volume.
const ceilingMin = 1.5;
const ceilingMax = 12.0;

/// Hauteur lue dans un champ de saisie (« 5,5 » ou « 5.5 »), null si vide ou hors des bornes.
double? parseCeiling(String pText) {
  final vValue = double.tryParse(pText.trim().replaceAll(',', '.'));

  return vValue != null && vValue >= ceilingMin && vValue <= ceilingMax ? vValue : null;
}

/// Surface acceptée pour une pièce, en m².
const areaMin = 1.0;
const areaMax = 500.0;

/// Surface lue dans un champ de saisie, null si vide ou hors des bornes.
double? parseArea(String pText) {
  final vValue = double.tryParse(pText.trim().replaceAll(',', '.'));

  return vValue != null && vValue >= areaMin && vValue <= areaMax ? vValue : null;
}

/// Énergie pour chauffer 1 m³ d'air de 1 °C : masse volumique (1,2 kg/m³) fois chaleur massique
/// (1005 J/kg/K), en Wh. Une constante physique ; elle ne compte ni les murs ni le mobilier.
const airHeatWhPerM3K = 0.335;

/// Énergie en kWh pour monter l'air d'une pièce de [pVolume] m³ de [pDegrees] °C.
double airEnergyKwh(double pVolume, double pDegrees) => pVolume * pDegrees * airHeatWhPerM3K / 1000;

/// Où se trouve un capteur : la pièce, le niveau, ou dehors.
class SensorPlace {
  const SensorPlace({
    this.room = '',
    this.floor,
    this.outdoor = false,
    this.ceiling,
    this.area,
  });

  final String room;

  /// Un des [floorLevels], null quand le niveau n'est pas dit.
  final int? floor;
  final bool outdoor;

  /// Hauteur sous plafond de la pièce en mètres (l'air chaud monte : un capteur à hauteur d'homme
  /// lit moins que le haut d'une pièce de 5 ou 6 m), null quand elle n'est pas dite.
  final double? ceiling;

  /// Surface au sol en m², null quand elle n'est pas dite.
  final double? area;

  /// Volume d'air en m³ : surface fois hauteur moyenne ; null s'il manque l'une des deux. Sous un
  /// plafond en pente, la hauteur donnée est la moyenne.
  double? get volume => area == null || ceiling == null ? null : area! * ceiling!;

  bool get isEmpty =>
      room.trim().isEmpty && floor == null && !outdoor && ceiling == null && area == null;
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
        ceiling: pPlace.ceiling,
        area: pPlace.area,
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
        if (vEntry.value.ceiling != null) 'ceiling': vEntry.value.ceiling,
        if (vEntry.value.area != null) 'area': vEntry.value.area,
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
    if (vLabel is String &&
        vLat is num &&
        vLon is num &&
        isValidCoordinates(vLat.toDouble(), vLon.toDouble())) {
      vLocation = HouseLocation(
        label: vLabel,
        latitude: vLat.toDouble(),
        longitude: vLon.toDouble(),
      );
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
      final vCeiling = vValue['ceiling'];
      final vArea = vValue['area'];
      final vPlace = SensorPlace(
        room: vRoom is String ? vRoom : '',
        floor: vFloor is int && floorLevels.contains(vFloor) ? vFloor : null,
        outdoor: vValue['outdoor'] == true,
        ceiling: vCeiling is num ? parseCeiling('${vCeiling.toDouble()}') : null,
        area: vArea is num ? parseArea('${vArea.toDouble()}') : null,
      );
      if (!vPlace.isEmpty) {
        vPlaces[vEntry.key] = vPlace;
      }
    }
  }

  return House(location: vLocation, places: vPlaces);
}
