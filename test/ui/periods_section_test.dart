import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/ui/periods_section.dart';

import '../support/localized.dart';

Reading _at(DateTime pAt) => Reading(at: pAt, temp: 10, humidity: 50);

void main() {
  testWidgets('un seul bloc de relevés : rien à séparer', (pTester) async {
    final vSensor = Sensor(
      name: 'A',
      readings: [_at(DateTime(2025, 1, 1)), _at(DateTime(2025, 1, 2))],
    );

    await pTester.pumpWidget(
      localized(PeriodsSection(sensor: vSensor, onSplit: (_, _, _) async => true)),
    );

    expect(find.text('Périodes de mesure'), findsNothing);
  });

  testWidgets('deux périodes : séparer demande un nom puis le dit', (pTester) async {
    final vSensor = Sensor(
      name: 'A',
      readings: [_at(DateTime(2025, 1, 1)), _at(DateTime(2025, 6, 1))],
    );
    String? vName;
    DateTime? vFrom;

    await pTester.pumpWidget(
      localized(
        Scaffold(
          body: PeriodsSection(
            sensor: vSensor,
            onSplit: (pFrom, _, pName) async {
              vFrom = pFrom;
              vName = pName;

              return true;
            },
          ),
        ),
      ),
    );
    expect(find.text('Périodes de mesure'), findsOneWidget);

    await pTester.tap(find.text('Séparer').first);
    await pTester.pumpAndSettle();
    await pTester.enterText(find.byType(TextField), 'Bureau');
    await pTester.tap(find.widgetWithText(FilledButton, 'Séparer'));
    await pTester.pumpAndSettle();

    expect(vName, 'Bureau');
    expect(vFrom, DateTime(2025, 1, 1));
    expect(find.text('Période déplacée vers « Bureau ».'), findsOneWidget);
  });

  testWidgets('un nom refusé le dit, annuler ne déplace rien', (pTester) async {
    final vSensor = Sensor(
      name: 'A',
      readings: [_at(DateTime(2025, 1, 1)), _at(DateTime(2025, 6, 1))],
    );
    var vCalls = 0;

    await pTester.pumpWidget(
      localized(
        Scaffold(
          body: PeriodsSection(
            sensor: vSensor,
            onSplit: (_, _, _) async {
              vCalls++;

              return false;
            },
          ),
        ),
      ),
    );

    await pTester.tap(find.text('Séparer').first);
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Annuler'));
    await pTester.pumpAndSettle();
    expect(vCalls, 0);

    await pTester.tap(find.text('Séparer').first);
    await pTester.pumpAndSettle();
    await pTester.enterText(find.byType(TextField), 'A');
    await pTester.tap(find.widgetWithText(FilledButton, 'Séparer'));
    await pTester.pumpAndSettle();

    expect(vCalls, 1);
    expect(find.text('Choisis un autre nom que celui du capteur.'), findsOneWidget);
  });
}
