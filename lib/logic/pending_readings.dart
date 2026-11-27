import 'dart:convert';

import 'reading.dart';
import 'sensor_log.dart';

/// Un relevé pris en arrière-plan, pas encore rangé dans les capteurs de l'appli.
class PendingReading {
  const PendingReading({required this.sensor, required this.reading});

  final String sensor;
  final Reading reading;
}

/// Ligne du fichier des relevés en attente : un objet JSON par ligne.
String pendingLine(String pSensor, Reading pReading) => jsonEncode({
  'sensor': pSensor,
  'at': pReading.at.toIso8601String(),
  'temp': pReading.temp,
  'humidity': pReading.humidity,
});

/// Relevés en attente d'un fichier. Une ligne illisible ou incomplète est ignorée : le service
/// d'arrière-plan peut avoir été coupé en pleine écriture.
List<PendingReading> parsePending(String pText) {
  final rPending = <PendingReading>[];
  for (final vLine in const LineSplitter().convert(pText)) {
    final Object? vData;
    try {
      vData = jsonDecode(vLine);
    } on FormatException {
      continue;
    }
    if (vData is! Map<String, dynamic>) {
      continue;
    }
    final vSensor = vData['sensor'];
    final vAt = vData['at'];
    final vTemp = vData['temp'];
    final vHumidity = vData['humidity'];
    final vDate = vAt is String ? DateTime.tryParse(vAt) : null;
    if (vSensor is String && vSensor.trim().isNotEmpty && vDate != null && vTemp is num && vHumidity is num) {
      rPending.add(
        PendingReading(
          sensor: vSensor,
          reading: Reading(at: vDate, temp: vTemp.toDouble(), humidity: vHumidity.toDouble()),
        ),
      );
    }
  }

  return rPending;
}

/// Capteurs avec les relevés en attente rangés dans l'ordre du temps, en gardant au plus un relevé
/// par minute et par capteur comme pour la mesure en direct.
List<Sensor> applyPending(List<Sensor> pSensors, List<PendingReading> pPending) {
  final vSorted = [...pPending]..sort((pA, pB) => pA.reading.at.compareTo(pB.reading.at));
  var rSensors = pSensors;
  for (final vItem in vSorted) {
    rSensors = withLiveReading(rSensors, vItem.sensor, vItem.reading);
  }

  return rSensors;
}

/// Capteur suivi en arrière-plan : son identifiant Bluetooth et le nom sous lequel ranger ses
/// relevés.
class FollowedDevice {
  const FollowedDevice({required this.id, required this.name});

  final String id;
  final String name;
}

String followedJson(List<FollowedDevice> pDevices) => jsonEncode([
  for (final vDevice in pDevices) {'id': vDevice.id, 'name': vDevice.name},
]);

/// Liste des capteurs suivis. Un texte abîmé donne une liste vide.
List<FollowedDevice> parseFollowed(String pJson) {
  final Object? vData;
  try {
    vData = jsonDecode(pJson);
  } on FormatException {
    return [];
  }
  final rDevices = <FollowedDevice>[];
  if (vData is List) {
    for (final vEntry in vData) {
      if (vEntry is Map<String, dynamic> && vEntry['id'] is String && vEntry['name'] is String) {
        rDevices.add(FollowedDevice(id: vEntry['id'] as String, name: vEntry['name'] as String));
      }
    }
  }

  return rDevices;
}
