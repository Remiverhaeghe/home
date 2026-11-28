import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/compare.dart';
import '../logic/reading.dart';
import '../state/sensors_controller.dart';
import 'units_scope.dart';

/// Deux capteurs sur les mêmes courbes, avec une seule échelle pour les voir s'écarter.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, required this.controller});

  final SensorsController controller;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  String? _a;
  String? _b;

  Sensor? _find(List<Sensor> pSensors, String? pName) =>
      pSensors.where((pSensor) => pSensor.name == pName).firstOrNull;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vSensors = widget.controller.sensors;
    final vA = _find(vSensors, _a) ?? (vSensors.isNotEmpty ? vSensors.first : null);
    final vB = _find(vSensors, _b) ?? (vSensors.length > 1 ? vSensors[1] : null);
    final vPairs = vA == null || vB == null ? <DayPair>[] : alignedDays(vA.readings, vB.readings);
    final vShown = vPairs.length > 30 ? vPairs.sublist(vPairs.length - 30) : vPairs;
    final vGap = meanGap(vShown);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());
    final vScheme = Theme.of(pContext).colorScheme;

    Widget picker(Sensor? pValue, Color pColor, ValueChanged<String?> pChanged) => Row(
      children: [
        Icon(Icons.circle, size: 14, color: pColor),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            value: pValue?.name,
            items: [
              for (final vSensor in vSensors)
                DropdownMenuItem(value: vSensor.name, child: Text(vSensor.title)),
            ],
            onChanged: pChanged,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.compareTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          picker(vA, vScheme.primary, (pName) => setState(() => _a = pName)),
          picker(vB, vScheme.secondary, (pName) => setState(() => _b = pName)),
          const SizedBox(height: 16),
          if (vShown.length < 2)
            Text(vTexts.compareNotEnough)
          else ...[
            Text(vTexts.compareTemperature, style: Theme.of(pContext).textTheme.titleMedium),
            const SizedBox(height: 8),
            Semantics(
              label: vTexts.compareChartLabel(vShown.length),
              child: SizedBox(
                height: 160,
                child: CustomPaint(
                  painter: ComparePainter(
                    a: [for (final vPair in vShown) vPair.tempA],
                    b: [for (final vPair in vShown) vPair.tempB],
                    colorA: vScheme.primary,
                    colorB: vScheme.secondary,
                    grid: vScheme.outlineVariant,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(vTexts.compareHumidity, style: Theme.of(pContext).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: CustomPaint(
                painter: ComparePainter(
                  a: [for (final vPair in vShown) vPair.humidityA],
                  b: [for (final vPair in vShown) vPair.humidityB],
                  colorA: vScheme.primary,
                  colorB: vScheme.secondary,
                  grid: vScheme.outlineVariant,
                ),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 16),
            if (vGap != null)
              Text(
                vTexts.compareGap(
                  UnitsScope.of(pContext).delta(vGap.temp),
                  '${vGap.humidity >= 0 ? '+' : ''}${vNumber.format(vGap.humidity)}',
                  vShown.length,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Deux courbes sur une même échelle, du plus bas au plus haut des deux.
class ComparePainter extends CustomPainter {
  ComparePainter({
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
    required this.grid,
  });

  final List<double> a;
  final List<double> b;
  final Color colorA;
  final Color colorB;
  final Color grid;

  Path _line(Size pSize, List<double> pValues, double pMin, double pMax) {
    final rPath = Path();
    for (var vAt = 0; vAt < pValues.length; vAt++) {
      final vX = pValues.length == 1 ? pSize.width / 2 : pSize.width * vAt / (pValues.length - 1);
      final vShare = pMax == pMin ? 0.5 : (pValues[vAt] - pMin) / (pMax - pMin);
      final vY = pSize.height * (1 - 0.1 - 0.8 * vShare);
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
    if (a.isEmpty || b.isEmpty) {
      return;
    }
    final vAll = [...a, ...b];
    final vMin = vAll.reduce((pX, pY) => pX < pY ? pX : pY);
    final vMax = vAll.reduce((pX, pY) => pX > pY ? pX : pY);
    final vGrid = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var vRow = 0; vRow <= 4; vRow++) {
      final vY = pSize.height * vRow / 4;
      pCanvas.drawLine(Offset(0, vY), Offset(pSize.width, vY), vGrid);
    }
    for (final (vValues, vColor) in [(b, colorB), (a, colorA)]) {
      pCanvas.drawPath(
        _line(pSize, vValues, vMin, vMax),
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
  bool shouldRepaint(ComparePainter pOld) =>
      pOld.a != a || pOld.b != b || pOld.colorA != colorA || pOld.colorB != colorB;
}
