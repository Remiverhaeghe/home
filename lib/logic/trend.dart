/// Tendance du dernier jour : de quoi tracer une petite courbe sur la carte d'un capteur.
library;

import 'reading.dart';

/// Températures du dernier jour de relevés (jusqu'à [pSpan] avant le dernier), ramenées à
/// [pMaxPoints] valeurs au plus par moyennes de paquets consécutifs. Vide sans relevé.
List<double> recentTemps(
  List<Reading> pReadings, {
  Duration pSpan = const Duration(hours: 24),
  int pMaxPoints = 48,
}) {
  if (pReadings.isEmpty) {
    return const [];
  }
  final vFrom = pReadings.last.at.subtract(pSpan);
  final vTemps = [
    for (final vReading in pReadings)
      if (!vReading.at.isBefore(vFrom)) vReading.temp,
  ];
  if (vTemps.length <= pMaxPoints) {
    return vTemps;
  }

  return [
    for (var vIndex = 0; vIndex < pMaxPoints; vIndex++)
      _mean(
        vTemps,
        vIndex * vTemps.length ~/ pMaxPoints,
        (vIndex + 1) * vTemps.length ~/ pMaxPoints,
      ),
  ];
}

double _mean(List<double> pValues, int pFrom, int pTo) {
  final vEnd = pTo > pFrom ? pTo : pFrom + 1;
  var vSum = 0.0;
  for (var vIndex = pFrom; vIndex < vEnd; vIndex++) {
    vSum += pValues[vIndex];
  }

  return vSum / (vEnd - pFrom);
}
