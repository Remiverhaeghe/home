/// Lecture et écriture du fichier d'échange JSON, le même que lit Atelier (voir
/// `docs/echange-climat.md`). Home range ses capteurs dans ce format.
library;

import 'dart:convert';

import 'reading.dart';

/// Version du fichier d'échange.
const exchangeVersion = 1;

/// Ce qui empêche de lire un fichier d'échange.
enum ExchangeProblem { notJson, wrongVersion, noSensors }

class ExchangeException implements Exception {
  const ExchangeException(this.problem);

  final ExchangeProblem problem;

  @override
  String toString() => 'ExchangeException(${problem.name})';
}

/// Capteurs d'un fichier d'échange. Un relevé invalide est ignoré, un capteur sans nom aussi.
List<Sensor> parseExchange(String pJson) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pJson);
  } on FormatException {
    throw const ExchangeException(ExchangeProblem.notJson);
  }
  if (vRoot is! Map<String, dynamic>) {
    throw const ExchangeException(ExchangeProblem.notJson);
  }
  if (vRoot['version'] != exchangeVersion) {
    throw const ExchangeException(ExchangeProblem.wrongVersion);
  }
  final vSensors = vRoot['sensors'];
  if (vSensors is! List) {
    throw const ExchangeException(ExchangeProblem.noSensors);
  }
  final rSensors = <Sensor>[];
  for (final vEntry in vSensors) {
    final vSensor = _parseSensor(vEntry);
    if (vSensor != null) {
      rSensors.add(vSensor);
    }
  }

  return rSensors;
}

Sensor? _parseSensor(Object? pEntry) {
  if (pEntry is! Map<String, dynamic>) {
    return null;
  }
  final vName = pEntry['name'];
  if (vName is! String || vName.trim().isEmpty) {
    return null;
  }
  final vReadings = <Reading>[];
  final vRaw = pEntry['readings'];
  if (vRaw is List) {
    for (final vItem in vRaw) {
      final vReading = _parseReading(vItem);
      if (vReading != null) {
        vReadings.add(vReading);
      }
    }
  }
  vReadings.sort((pA, pB) => pA.at.compareTo(pB.at));

  return Sensor(name: vName.trim(), readings: vReadings);
}

Reading? _parseReading(Object? pItem) {
  if (pItem is! Map<String, dynamic>) {
    return null;
  }
  final vAt = pItem['at'];
  final vTemp = pItem['temp'];
  final vHumidity = pItem['humidity'];
  final vDate = vAt is String ? DateTime.tryParse(vAt) : null;
  if (vDate == null || vTemp is! num || vHumidity is! num) {
    return null;
  }
  if (vHumidity < 0 || vHumidity > 100) {
    return null;
  }

  return Reading(at: vDate, temp: vTemp.toDouble(), humidity: vHumidity.toDouble());
}

/// Fichier d'échange des capteurs donnés.
String exchangeJson(List<Sensor> pSensors) {
  final vData = {
    'version': exchangeVersion,
    'sensors': [
      for (final vSensor in pSensors)
        {
          'name': vSensor.name,
          'readings': [
            for (final vReading in vSensor.readings)
              {
                'at': vReading.at.toIso8601String(),
                'temp': vReading.temp,
                'humidity': vReading.humidity,
              },
          ],
        },
    ],
  };

  return const JsonEncoder.withIndent('  ').convert(vData);
}
