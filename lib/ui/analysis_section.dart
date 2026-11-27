import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/analysis.dart';
import '../logic/reading.dart';

/// Jours de relevés pris en compte dans les analyses.
const analysisDays = 30;

/// Analyses d'un capteur sur les trente derniers jours : confort, humidité absolue, risque de
/// moisissure et anomalies.
class AnalysisSection extends StatelessWidget {
  const AnalysisSection({super.key, required this.readings});

  final List<Reading> readings;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vTheme = Theme.of(pContext).textTheme;
    final vLocale = Localizations.localeOf(pContext).toString();
    final vNumber = NumberFormat('0.#', vLocale);
    final vDate = DateFormat.MMMd(vLocale).add_Hm();
    if (readings.length < 2) {
      return const SizedBox.shrink();
    }
    final vFrom = readings.last.at.subtract(const Duration(days: analysisDays));
    final vRecent = readings.where((pReading) => !pReading.at.isBefore(vFrom)).toList();
    final vComfort = comfortHours(vRecent);
    final vMold = moldRisk(vRecent);
    final vAnomalies = findAnomalies(vRecent);
    final vLast = readings.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(vTexts.analysisTitle(analysisDays), style: vTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          vTexts.analysisComfort(
            vNumber.format(vComfort.comfortHours.round()),
            vNumber.format(vComfort.totalHours.round()),
            (vComfort.share * 100).round(),
          ),
        ),
        Text(
          vTexts.analysisAbsolute(vNumber.format(absoluteHumidity(vLast.temp, vLast.humidity))),
        ),
        Text(switch (vMold.level) {
          MoldLevel.low => vTexts.analysisMoldLow,
          MoldLevel.watch => vTexts.analysisMoldWatch(vNumber.format(vMold.longestHours.round())),
          MoldLevel.high => vTexts.analysisMoldHigh(vNumber.format(vMold.longestHours.round())),
        }),
        if (vAnomalies.isEmpty)
          Text(vTexts.analysisNoAnomaly)
        else
          for (final vAnomaly in vAnomalies.take(3))
            Text(switch (vAnomaly.kind) {
              AnomalyKind.stuck => vTexts.analysisStuck(vDate.format(vAnomaly.at)),
              AnomalyKind.jump => vTexts.analysisJump(vDate.format(vAnomaly.at)),
            }),
      ],
    );
  }
}
