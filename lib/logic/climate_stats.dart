import 'dart:math' as math;

import 'reading.dart';

/// Sous ce taux, l'air est sec ; au-dessus de [humidityHumidAbove], il est humide.
const humidityDryBelow = 40.0;
const humidityHumidAbove = 60.0;

enum HumidityLevel { dry, good, humid }

/// Niveau d'humidité : sec sous 40 %, confortable de 40 à 60 %, humide au-delà.
HumidityLevel humidityLevel(double pHumidity) {
  final HumidityLevel rLevel;
  if (pHumidity < humidityDryBelow) {
    rLevel = HumidityLevel.dry;
  } else if (pHumidity > humidityHumidAbove) {
    rLevel = HumidityLevel.humid;
  } else {
    rLevel = HumidityLevel.good;
  }

  return rLevel;
}

/// Point de rosée en °C (formule de Magnus) : en dessous, l'eau se condense sur les parois.
double dewPoint(double pTemp, double pHumidity) {
  const vA = 17.62;
  const vB = 243.12;
  final vGamma = math.log(math.max(pHumidity, 0.01) / 100) + vA * pTemp / (vB + pTemp);

  return vB * vGamma / (vA - vGamma);
}

/// Écart (°C) entre l'air et son point de rosée en dessous duquel les vitres, plus froides que
/// l'air, risquent d'embuer : repère de prudence, pas une mesure de la température des parois.
const condensationMargin = 3.0;

/// Vrai quand l'air est assez près de son point de rosée pour que de la condensation se forme.
bool condensationRisk(double pTemp, double pHumidity) =>
    pTemp - dewPoint(pTemp, pHumidity) < condensationMargin;

/// Moyenne d'une journée de relevés.
class DayAverage {
  const DayAverage({required this.day, required this.temp, required this.humidity});

  /// Jour à minuit.
  final DateTime day;
  final double temp;
  final double humidity;
}

/// Moyennes par jour, du plus ancien au plus récent.
List<DayAverage> dailyAverages(List<Reading> pReadings) {
  final vByDay = <DateTime, List<Reading>>{};
  for (final vReading in pReadings) {
    final vDay = DateTime(vReading.at.year, vReading.at.month, vReading.at.day);
    vByDay.putIfAbsent(vDay, () => []).add(vReading);
  }
  final rDays = [
    for (final vEntry in vByDay.entries)
      DayAverage(
        day: vEntry.key,
        temp: vEntry.value.map((pR) => pR.temp).reduce((pA, pB) => pA + pB) / vEntry.value.length,
        humidity:
            vEntry.value.map((pR) => pR.humidity).reduce((pA, pB) => pA + pB) / vEntry.value.length,
      ),
  ]..sort((pA, pB) => pA.day.compareTo(pB.day));

  return rDays;
}
