/// Analyses d'un capteur à partir de ses relevés : confort, risque de moisissure, anomalies.
library;

import 'dart:math' as math;

import 'reading.dart';

/// Plus longue durée comptée pour un relevé : au-delà, le capteur est considéré comme muet.
const maxGap = Duration(hours: 2);

/// Humidité absolue en g/m³ (quantité d'eau dans l'air), à partir de la température et de
/// l'humidité relative.
double absoluteHumidity(double pTemp, double pHumidity) {
  final vSaturation = 6.112 * math.exp(17.62 * pTemp / (243.12 + pTemp));

  return 216.7 * (pHumidity / 100 * vSaturation) / (273.15 + pTemp);
}

/// Durée de chaque relevé : jusqu'au suivant, plafonnée à [maxGap] ; le dernier ne compte pas.
List<Duration> _durations(List<Reading> pReadings) => [
  for (var vIndex = 0; vIndex < pReadings.length; vIndex++)
    vIndex == pReadings.length - 1
        ? Duration.zero
        : _min(pReadings[vIndex + 1].at.difference(pReadings[vIndex].at), maxGap),
];

Duration _min(Duration pA, Duration pB) => pA < pB ? pA : pB;

/// Heures passées dans la plage de confort, sur le total des heures relevées.
class ComfortShare {
  const ComfortShare({required this.comfortHours, required this.totalHours});

  final double comfortHours;
  final double totalHours;

  /// Part du temps en confort, de 0 à 1 ; 0 sans relevé.
  double get share => totalHours == 0 ? 0 : comfortHours / totalHours;
}

/// Plage de confort de départ : 18 à 24 °C et 40 à 60 % d'humidité.
ComfortShare comfortHours(
  List<Reading> pReadings, {
  double pTempMin = 18,
  double pTempMax = 24,
  double pHumidityMin = 40,
  double pHumidityMax = 60,
}) {
  final vDurations = _durations(pReadings);
  var vComfort = 0.0;
  var vTotal = 0.0;
  for (var vIndex = 0; vIndex < pReadings.length; vIndex++) {
    final vHours = vDurations[vIndex].inMinutes / 60;
    final vReading = pReadings[vIndex];
    vTotal += vHours;
    if (vReading.temp >= pTempMin &&
        vReading.temp <= pTempMax &&
        vReading.humidity >= pHumidityMin &&
        vReading.humidity <= pHumidityMax) {
      vComfort += vHours;
    }
  }

  return ComfortShare(comfortHours: vComfort, totalHours: vTotal);
}

enum MoldLevel { low, watch, high }

/// Risque de moisissure, indicatif : plus longue période continue à 70 % d'humidité ou plus.
class MoldRisk {
  const MoldRisk({required this.level, required this.longestHours});

  final MoldLevel level;
  final double longestHours;
}

MoldRisk moldRisk(List<Reading> pReadings, {double pThreshold = 70}) {
  final vDurations = _durations(pReadings);
  var vLongest = 0.0;
  var vRun = 0.0;
  for (var vIndex = 0; vIndex < pReadings.length; vIndex++) {
    if (pReadings[vIndex].humidity >= pThreshold) {
      vRun += vDurations[vIndex].inMinutes / 60;
      vLongest = math.max(vLongest, vRun);
    } else {
      vRun = 0;
    }
  }
  final vLevel = vLongest >= 48
      ? MoldLevel.high
      : vLongest >= 12
      ? MoldLevel.watch
      : MoldLevel.low;

  return MoldRisk(level: vLevel, longestHours: vLongest);
}

enum AnomalyKind { stuck, jump }

class ReadingAnomaly {
  const ReadingAnomaly({required this.kind, required this.at});

  final AnomalyKind kind;
  final DateTime at;
}

/// Capteur figé (mêmes valeurs pendant 6 h ou plus, sur au moins 12 relevés) ou saut de valeur
/// (8 °C ou 30 points d'humidité en 30 minutes ou moins).
List<ReadingAnomaly> findAnomalies(List<Reading> pReadings) {
  final rFound = <ReadingAnomaly>[];
  var vStart = 0;
  for (var vIndex = 1; vIndex <= pReadings.length; vIndex++) {
    final vSame =
        vIndex < pReadings.length &&
        pReadings[vIndex].temp == pReadings[vStart].temp &&
        pReadings[vIndex].humidity == pReadings[vStart].humidity;
    if (vSame) {
      continue;
    }
    final vCount = vIndex - vStart;
    if (vCount >= 12 &&
        pReadings[vIndex - 1].at.difference(pReadings[vStart].at) >= const Duration(hours: 6)) {
      rFound.add(ReadingAnomaly(kind: AnomalyKind.stuck, at: pReadings[vStart].at));
    }
    vStart = vIndex;
  }
  for (var vIndex = 1; vIndex < pReadings.length; vIndex++) {
    final vBefore = pReadings[vIndex - 1];
    final vNow = pReadings[vIndex];
    if (vNow.at.difference(vBefore.at) <= const Duration(minutes: 30) &&
        ((vNow.temp - vBefore.temp).abs() >= 8 || (vNow.humidity - vBefore.humidity).abs() >= 30)) {
      rFound.add(ReadingAnomaly(kind: AnomalyKind.jump, at: vNow.at));
    }
  }
  rFound.sort((pA, pB) => pA.at.compareTo(pB.at));

  return rFound;
}
