/// Comparaison de deux capteurs, jour par jour.
library;

import 'climate_stats.dart';
import 'reading.dart';

/// Moyennes d'un même jour pour les deux capteurs.
class DayPair {
  const DayPair({
    required this.day,
    required this.tempA,
    required this.tempB,
    required this.humidityA,
    required this.humidityB,
  });

  final DateTime day;
  final double tempA;
  final double tempB;
  final double humidityA;
  final double humidityB;
}

/// Les jours où les deux capteurs ont des relevés, du plus ancien au plus récent.
List<DayPair> alignedDays(List<Reading> pA, List<Reading> pB) {
  final vB = {for (final vDay in dailyAverages(pB)) vDay.day: vDay};
  final rPairs = <DayPair>[];
  for (final vDayA in dailyAverages(pA)) {
    final vDayB = vB[vDayA.day];
    if (vDayB != null) {
      rPairs.add(
        DayPair(
          day: vDayA.day,
          tempA: vDayA.temp,
          tempB: vDayB.temp,
          humidityA: vDayA.humidity,
          humidityB: vDayB.humidity,
        ),
      );
    }
  }

  return rPairs;
}

/// Écart moyen A moins B sur les jours communs, null sans jour commun.
({double temp, double humidity})? meanGap(List<DayPair> pPairs) {
  if (pPairs.isEmpty) {
    return null;
  }
  var vTemp = 0.0;
  var vHumidity = 0.0;
  for (final vPair in pPairs) {
    vTemp += vPair.tempA - vPair.tempB;
    vHumidity += vPair.humidityA - vPair.humidityB;
  }

  return (temp: vTemp / pPairs.length, humidity: vHumidity / pPairs.length);
}
