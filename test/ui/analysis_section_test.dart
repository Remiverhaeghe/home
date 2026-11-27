import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/ui/analysis_section.dart';

import '../support/localized.dart';

List<Reading> _series(int pCount, double pTemp, double pHumidity) => [
  for (var vIndex = 0; vIndex < pCount; vIndex++)
    Reading(
      at: DateTime(2026, 11, 1).add(Duration(hours: vIndex)),
      temp: pTemp + (vIndex.isEven ? 0 : 0.1),
      humidity: pHumidity,
    ),
];

void main() {
  testWidgets('un capteur confortable et sec ne signale rien', (pTester) async {
    await pTester.pumpWidget(localized(Scaffold(body: AnalysisSection(readings: _series(10, 21, 50)))));

    expect(find.textContaining('Analyses des 30 derniers jours'), findsOneWidget);
    expect(find.textContaining('Confort : 9 h sur 9 h'), findsOneWidget);
    expect(find.textContaining('pas de période humide longue'), findsOneWidget);
    expect(find.text('Aucune anomalie de mesure'), findsOneWidget);
  });

  testWidgets('une longue période humide est signalée', (pTester) async {
    await pTester.pumpWidget(
      localized(Scaffold(body: SingleChildScrollView(child: AnalysisSection(readings: _series(60, 20, 80))))),
    );

    expect(find.textContaining('Risque de moisissure'), findsOneWidget);
  });

  testWidgets('avec un seul relevé, la section est vide', (pTester) async {
    await pTester.pumpWidget(localized(Scaffold(body: AnalysisSection(readings: _series(1, 20, 50)))));

    expect(find.textContaining('Analyses'), findsNothing);
  });
}
