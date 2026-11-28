import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/climate_stats.dart';
import '../logic/reading.dart';
import '../logic/trend.dart';
import 'sparkline.dart';
import 'theme.dart';
import 'units_scope.dart';

/// Carte d'un capteur : température en grand, humidité avec sa jauge, niveau de l'air, courbe du
/// dernier jour et point de rosée.
class SensorCard extends StatelessWidget {
  const SensorCard({super.key, required this.sensor, this.onTap, this.place});

  final Sensor sensor;

  /// Où se trouve le capteur, sous son nom ; rien quand il n'est pas rangé.
  final String? place;

  /// Ouvre le détail du capteur.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vColors = HomeColors.of(pContext);
    final vTheme = Theme.of(pContext).textTheme;
    final vLast = sensor.last;
    final vLocale = Localizations.localeOf(pContext).toString();
    final vNumber = NumberFormat('0.0', vLocale);
    final vUnits = UnitsScope.of(pContext);
    final vLevel = vLast == null ? null : humidityLevel(vLast.humidity);
    final vLevelColor = vLevel == HumidityLevel.good ? vColors.good : vColors.warning;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sensor.title, style: vTheme.titleMedium),
                        if (place != null) Text(place!, style: vTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (vLevel != null)
                    _LevelChip(label: _levelLabel(vTexts, vLevel), color: vLevelColor),
                ],
              ),
              if (vLast == null) ...[
                const SizedBox(height: 4),
                Text(vTexts.noReading),
              ] else ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vTexts.temperatureValue(vUnits.temp(vLast.temp)),
                            style: vTheme.displaySmall?.copyWith(
                              color: vColors.temperature,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            vTexts.dewPointValue(vUnits.temp(dewPoint(vLast.temp, vLast.humidity))),
                            style: vTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          vTexts.humidityValue(vNumber.format(vLast.humidity)),
                          style: vTheme.headlineSmall?.copyWith(
                            color: vColors.humidity,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        HumidityBar(humidity: vLast.humidity, width: 120),
                      ],
                    ),
                  ],
                ),
                if (condensationRisk(vLast.temp, vLast.humidity)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.water_drop_outlined, size: 16, color: vColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vTexts.condensationAdvice,
                          style: vTheme.bodySmall?.copyWith(color: vColors.warning),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Sparkline(values: recentTemps(sensor.readings), color: vColors.temperature),
                const SizedBox(height: 4),
                Text(
                  vTexts.lastReading(DateFormat.yMMMd(vLocale).add_Hm().format(vLast.at)),
                  style: vTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _levelLabel(AppLocalizations pTexts, HumidityLevel pLevel) => switch (pLevel) {
    HumidityLevel.dry => pTexts.humidityDry,
    HumidityLevel.good => pTexts.humidityGood,
    HumidityLevel.humid => pTexts.humidityHumid,
  };
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext pContext) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(label, style: Theme.of(pContext).textTheme.labelMedium?.copyWith(color: color)),
    ),
  );
}

/// Jauge d'humidité de 0 à 100 % : la zone de confort (40 à 60 %) en teinte douce, un repère sur
/// la valeur.
class HumidityBar extends StatelessWidget {
  const HumidityBar({super.key, required this.humidity, this.width = 120});

  final double humidity;
  final double width;

  @override
  Widget build(BuildContext pContext) {
    final vColors = HomeColors.of(pContext);

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: 10,
        child: CustomPaint(
          painter: HumidityBarPainter(
            humidity: humidity,
            track: Theme.of(pContext).colorScheme.outlineVariant,
            band: vColors.good,
            marker: vColors.humidity,
          ),
        ),
      ),
    );
  }
}

class HumidityBarPainter extends CustomPainter {
  HumidityBarPainter({
    required this.humidity,
    required this.track,
    required this.band,
    required this.marker,
  });

  final double humidity;
  final Color track;
  final Color band;
  final Color marker;

  @override
  void paint(Canvas pCanvas, Size pSize) {
    final vMiddle = pSize.height / 2;
    final vRadius = Radius.circular(vMiddle);
    pCanvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, vMiddle - 2, pSize.width, 4), vRadius),
      Paint()..color = track,
    );
    pCanvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(pSize.width * 0.4, vMiddle - 2, pSize.width * 0.6, vMiddle + 2),
        vRadius,
      ),
      Paint()..color = band.withValues(alpha: 0.7),
    );
    final vX = pSize.width * (humidity.clamp(0, 100) / 100);
    pCanvas.drawCircle(Offset(vX, vMiddle), 5, Paint()..color = marker);
  }

  @override
  bool shouldRepaint(HumidityBarPainter pOld) =>
      pOld.humidity != humidity ||
      pOld.track != track ||
      pOld.band != band ||
      pOld.marker != marker;
}
