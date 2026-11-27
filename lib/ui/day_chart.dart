import 'package:flutter/material.dart';

import '../logic/climate_stats.dart';
import 'theme.dart';

/// Courbes des moyennes par jour : température en ambre, humidité en bleu. Chaque courbe est
/// ramenée à sa propre échelle (de son minimum à son maximum), pour que la forme se lise même
/// quand la température varie de deux degrés et l'humidité de trente points.
class DayChart extends StatelessWidget {
  const DayChart({super.key, required this.days, required this.semanticLabel});

  final List<DayAverage> days;
  final String semanticLabel;

  @override
  Widget build(BuildContext pContext) {
    final vColors = HomeColors.of(pContext);

    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: CustomPaint(
          painter: DayChartPainter(
            days: days,
            temperature: vColors.temperature,
            humidity: vColors.humidity,
            grid: Theme.of(pContext).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class DayChartPainter extends CustomPainter {
  DayChartPainter({
    required this.days,
    required this.temperature,
    required this.humidity,
    required this.grid,
  });

  final List<DayAverage> days;
  final Color temperature;
  final Color humidity;
  final Color grid;

  /// Position d'une valeur entre [pMin] et [pMax], de 0 (bas) à 1 (haut). Au milieu quand toutes
  /// les valeurs sont égales.
  static double scaled(double pValue, double pMin, double pMax) =>
      pMax == pMin ? 0.5 : (pValue - pMin) / (pMax - pMin);

  Path _line(Size pSize, List<double> pValues) {
    final vMin = pValues.reduce((pA, pB) => pA < pB ? pA : pB);
    final vMax = pValues.reduce((pA, pB) => pA > pB ? pA : pB);
    final rPath = Path();
    for (var vAt = 0; vAt < pValues.length; vAt++) {
      final vX = pValues.length == 1 ? pSize.width / 2 : pSize.width * vAt / (pValues.length - 1);
      final vY = pSize.height * (1 - 0.1 - 0.8 * scaled(pValues[vAt], vMin, vMax));
      if (vAt == 0) {
        rPath.moveTo(vX, vY);
      } else {
        rPath.lineTo(vX, vY);
      }
    }

    return rPath;
  }

  @override
  void paint(Canvas pCanvas, Size pSize) {
    if (days.isEmpty) {
      return;
    }
    final vGrid = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var vRow = 0; vRow <= 4; vRow++) {
      final vY = pSize.height * vRow / 4;
      pCanvas.drawLine(Offset(0, vY), Offset(pSize.width, vY), vGrid);
    }
    for (final (vValues, vColor) in [
      (days.map((pDay) => pDay.humidity).toList(), humidity),
      (days.map((pDay) => pDay.temp).toList(), temperature),
    ]) {
      pCanvas.drawPath(
        _line(pSize, vValues),
        Paint()
          ..color = vColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(DayChartPainter pOld) =>
      pOld.days != days ||
      pOld.temperature != temperature ||
      pOld.humidity != humidity ||
      pOld.grid != grid;
}
