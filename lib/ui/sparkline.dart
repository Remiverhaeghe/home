import 'package:flutter/material.dart';

/// Petite courbe sans axes : la forme de la journée, avec un point sur la dernière valeur. Il faut
/// au moins deux valeurs ; sinon rien n'est dessiné.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color, this.height = 40});

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext pContext) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: SparklinePainter(values: values, color: color)),
    ),
  );
}

class SparklinePainter extends CustomPainter {
  SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas pCanvas, Size pSize) {
    if (values.length < 2) {
      return;
    }
    var vMin = values.first;
    var vMax = values.first;
    for (final vValue in values) {
      vMin = vValue < vMin ? vValue : vMin;
      vMax = vValue > vMax ? vValue : vMax;
    }
    // Une courbe plate se dessine au milieu plutôt que collée en bas
    final vRange = vMax - vMin < 0.1 ? 1.0 : vMax - vMin;
    const vPad = 4.0;
    Offset point(int pIndex) => Offset(
      pIndex * pSize.width / (values.length - 1),
      vPad + (pSize.height - 2 * vPad) * (1 - (values[pIndex] - vMin) / vRange),
    );

    final vLine = Path()..moveTo(point(0).dx, point(0).dy);
    for (var vIndex = 1; vIndex < values.length; vIndex++) {
      vLine.lineTo(point(vIndex).dx, point(vIndex).dy);
    }
    final vFill = Path.from(vLine)
      ..lineTo(pSize.width, pSize.height)
      ..lineTo(0, pSize.height)
      ..close();
    pCanvas.drawPath(
      vFill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & pSize),
    );
    pCanvas.drawPath(
      vLine,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    pCanvas.drawCircle(point(values.length - 1), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(SparklinePainter pOld) => pOld.values != values || pOld.color != color;
}
