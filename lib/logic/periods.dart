/// Périodes de mesure d'un capteur : un long trou entre deux relevés laisse penser qu'il a changé
/// de place.
library;

import 'reading.dart';

/// Trou au-delà duquel les relevés forment deux périodes.
const periodGap = Duration(hours: 48);

class ReadingPeriod {
  const ReadingPeriod({
    required this.from,
    required this.to,
    required this.count,
    required this.avgTemp,
    required this.avgHumidity,
  });

  final DateTime from;
  final DateTime to;
  final int count;
  final double avgTemp;
  final double avgHumidity;
}

/// Périodes d'un capteur, de la plus ancienne à la plus récente. Les relevés sont supposés triés.
List<ReadingPeriod> findPeriods(List<Reading> pReadings, {Duration pGap = periodGap}) {
  final rPeriods = <ReadingPeriod>[];
  var vStart = 0;
  for (var vIndex = 1; vIndex <= pReadings.length; vIndex++) {
    final vEnds =
        vIndex == pReadings.length ||
        pReadings[vIndex].at.difference(pReadings[vIndex - 1].at) >= pGap;
    if (!vEnds) {
      continue;
    }
    final vPart = pReadings.sublist(vStart, vIndex);
    rPeriods.add(
      ReadingPeriod(
        from: vPart.first.at,
        to: vPart.last.at,
        count: vPart.length,
        avgTemp: vPart.fold(0.0, (pSum, pReading) => pSum + pReading.temp) / vPart.length,
        avgHumidity: vPart.fold(0.0, (pSum, pReading) => pSum + pReading.humidity) / vPart.length,
      ),
    );
    vStart = vIndex;
  }

  return rPeriods;
}

/// Sépare les relevés de la période [pFrom] à [pTo] (bornes comprises) de tous les autres.
({List<Reading> kept, List<Reading> moved}) separatePeriod(
  List<Reading> pReadings,
  DateTime pFrom,
  DateTime pTo,
) {
  bool inside(Reading pReading) => !pReading.at.isBefore(pFrom) && !pReading.at.isAfter(pTo);

  return (
    kept: [
      for (final vReading in pReadings)
        if (!inside(vReading)) vReading,
    ],
    moved: [
      for (final vReading in pReadings)
        if (inside(vReading)) vReading,
    ],
  );
}
