import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/climate_stats.dart';
import '../logic/reading.dart';
import 'day_chart.dart';
import 'theme.dart';

/// Détail d'un capteur : courbes des quatorze derniers jours, minimum et maximum.
class SensorDetailScreen extends StatelessWidget {
  const SensorDetailScreen({super.key, required this.sensor});

  final Sensor sensor;

  /// Nombre de jours montrés sur les courbes.
  static const shownDays = 14;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vTheme = Theme.of(pContext).textTheme;
    final vColors = HomeColors.of(pContext);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());
    final vAll = dailyAverages(sensor.readings);
    final vDays = vAll.length > shownDays ? vAll.sublist(vAll.length - shownDays) : vAll;
    final vTemps = vDays.map((pDay) => pDay.temp);
    final vHumidities = vDays.map((pDay) => pDay.humidity);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.detailTitle(sensor.name))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(vTexts.detailReadings(sensor.readings.length), style: vTheme.bodySmall),
          const SizedBox(height: 16),
          Text(vTexts.detailChartTitle, style: vTheme.titleMedium),
          const SizedBox(height: 12),
          if (vDays.length < 2)
            Text(vTexts.detailNotEnough)
          else ...[
            DayChart(days: vDays, semanticLabel: vTexts.detailChartLabel(vDays.length)),
            const SizedBox(height: 16),
            Text(
              vTexts.detailTemperature,
              style: vTheme.titleSmall?.copyWith(color: vColors.temperature),
            ),
            Text(
              vTexts.detailRange(
                vTexts.temperatureValue(
                  vNumber.format(vTemps.reduce((pA, pB) => pA < pB ? pA : pB)),
                ),
                vTexts.temperatureValue(
                  vNumber.format(vTemps.reduce((pA, pB) => pA > pB ? pA : pB)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vTexts.detailHumidity,
              style: vTheme.titleSmall?.copyWith(color: vColors.humidity),
            ),
            Text(
              vTexts.detailRange(
                vTexts.humidityValue(
                  vNumber.format(vHumidities.reduce((pA, pB) => pA < pB ? pA : pB)),
                ),
                vTexts.humidityValue(
                  vNumber.format(vHumidities.reduce((pA, pB) => pA > pB ? pA : pB)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
