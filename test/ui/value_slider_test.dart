import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/ui/value_slider.dart';

void main() {
  Widget host(double pValue, ValueChanged<double> pOnChanged) => MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueSlider(
          title: 'Seuil',
          valueText: '${pValue.round()} %',
          value: pValue,
          min: 50,
          max: 90,
          minText: '50 %',
          maxText: '90 %',
          divisions: 40,
          onChanged: pOnChanged,
        ),
      ),
    ),
  );

  testWidgets('la valeur et les bornes restent affichées', (pTester) async {
    await pTester.pumpWidget(host(70, (_) {}));

    expect(find.text('Seuil'), findsOneWidget);
    expect(find.text('70 %'), findsOneWidget);
    expect(find.text('50 %'), findsOneWidget);
    expect(find.text('90 %'), findsOneWidget);
  });

  testWidgets('déplacer le curseur renvoie la nouvelle valeur', (pTester) async {
    double? vSeen;
    await pTester.pumpWidget(host(70, (pValue) => vSeen = pValue));

    await pTester.drag(find.byType(Slider), const Offset(60, 0));
    await pTester.pump();

    expect(vSeen, isNotNull);
    expect(vSeen, greaterThan(70));
  });

  testWidgets('une valeur hors bornes ne casse pas le curseur', (pTester) async {
    await pTester.pumpWidget(host(120, (_) {}));

    expect(tester(pTester).value, 90);
  });
}

Slider tester(WidgetTester pTester) => pTester.widget<Slider>(find.byType(Slider));
