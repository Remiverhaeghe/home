import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/ui/sensor_card.dart';
import 'package:home/ui/sparkline.dart';

import '../support/localized.dart';

void main() {
  final vNow = DateTime(2026, 11, 28, 12);
  Sensor sensor(List<Reading> pReadings) => Sensor(name: 'Salon', readings: pReadings);
  Reading at(int pMinutesAgo, double pTemp, double pHumidity) => Reading(
    at: vNow.subtract(Duration(minutes: pMinutesAgo)),
    temp: pTemp,
    humidity: pHumidity,
  );

  testWidgets('la carte montre température, humidité, niveau, rosée et courbe', (pTester) async {
    await pTester.pumpWidget(
      localized(
        SensorCard(
          sensor: sensor([at(120, 19.5, 50), at(60, 20.5, 52), at(0, 21.5, 48)]),
          place: 'Salon',
        ),
      ),
    );

    expect(find.text('21,5 °C'), findsOneWidget);
    expect(find.text('48,0 %'), findsOneWidget);
    expect(find.text('Air confortable'), findsOneWidget);
    expect(find.textContaining('Condensation sous'), findsOneWidget);
    expect(find.byType(Sparkline), findsOneWidget);
    expect(find.byType(HumidityBar), findsOneWidget);
  });

  testWidgets('sans relevé, la carte le dit et ne dessine rien', (pTester) async {
    await pTester.pumpWidget(localized(SensorCard(sensor: sensor(const []))));

    expect(find.text('Aucun relevé'), findsOneWidget);
    expect(find.byType(Sparkline), findsNothing);
  });

  testWidgets('un air humide reçoit son étiquette', (pTester) async {
    await pTester.pumpWidget(localized(SensorCard(sensor: sensor([at(0, 20, 78)]))));

    expect(find.text('Air humide'), findsOneWidget);
  });

  testWidgets('un seul relevé ne casse pas la courbe', (pTester) async {
    await pTester.pumpWidget(localized(SensorCard(sensor: sensor([at(0, 20, 50)]))));
    await pTester.pump();

    expect(pTester.takeException(), isNull);
  });
}
