import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/climate_stats.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/day_chart.dart';
import 'package:home/ui/sensor_detail_screen.dart';
import 'package:home/ui/sensors_screen.dart';

import '../support/localized.dart';
import '../support/sensors.dart';

Sensor _manyDays(int pDays) => Sensor(
  name: 'Salon',
  readings: [
    for (var vDay = 0; vDay < pDays; vDay++)
      Reading(at: DateTime(2026, 11, 1 + vDay, 12), temp: 18 + vDay * 0.5, humidity: 40 + vDay.toDouble()),
  ],
);

void main() {
  group('échelle de la courbe', () {
    test('de 0 au minimum à 1 au maximum, au milieu si tout est égal', () {
      expect(DayChartPainter.scaled(10, 10, 20), 0);
      expect(DayChartPainter.scaled(20, 10, 20), 1);
      expect(DayChartPainter.scaled(15, 10, 20), 0.5);
      expect(DayChartPainter.scaled(7, 7, 7), 0.5);
    });
  });

  group('peintre', () {
    DayChartPainter painter(List<DayAverage> pDays, {Color pHumidity = Colors.blue}) =>
        DayChartPainter(
          days: pDays,
          temperature: Colors.orange,
          humidity: pHumidity,
          grid: Colors.grey,
        );

    final vDays = dailyAverages(bathroomSensor().readings);

    test('il se repeint quand les jours ou une couleur changent', () {
      expect(painter(vDays).shouldRepaint(painter(vDays)), isFalse);
      expect(painter(vDays).shouldRepaint(painter([])), isTrue);
      expect(painter(vDays).shouldRepaint(painter(vDays, pHumidity: Colors.red)), isTrue);
      expect(
        painter(vDays).shouldRepaint(
          DayChartPainter(
            days: vDays,
            temperature: Colors.green,
            humidity: Colors.blue,
            grid: Colors.grey,
          ),
        ),
        isTrue,
      );
      expect(
        painter(vDays).shouldRepaint(
          DayChartPainter(
            days: vDays,
            temperature: Colors.orange,
            humidity: Colors.blue,
            grid: Colors.black,
          ),
        ),
        isTrue,
      );
    });
  });

  testWidgets('le détail montre les courbes, les extrêmes et le nombre de relevés', (pTester) async {
    await pTester.pumpWidget(localized(SensorDetailScreen(sensor: _manyDays(5))));

    expect(find.text('Salon'), findsOneWidget);
    expect(find.text('5 relevés'), findsOneWidget);
    expect(find.byType(DayChart), findsOneWidget);
    expect(find.bySemanticsLabel('Courbes de température et d\'humidité sur 5 jours'), findsOneWidget);
    expect(find.text('18,0 °C à 20,0 °C'), findsOneWidget);
    expect(find.text('40,0 % à 44,0 %'), findsOneWidget);
  });

  testWidgets('seuls les quatorze derniers jours sont montrés', (pTester) async {
    await pTester.pumpWidget(localized(SensorDetailScreen(sensor: _manyDays(20))));

    expect(find.bySemanticsLabel('Courbes de température et d\'humidité sur 14 jours'), findsOneWidget);
    // Les extrêmes sont ceux des quatorze derniers jours (jours 6 à 19)
    expect(find.text('21,0 °C à 27,5 °C'), findsOneWidget);
  });

  testWidgets('avec un seul jour, le détail dit qu\'il faut plus de relevés', (pTester) async {
    await pTester.pumpWidget(localized(SensorDetailScreen(sensor: _manyDays(1))));

    expect(find.text('Pas encore de relevés sur plusieurs jours.'), findsOneWidget);
    expect(find.byType(DayChart), findsNothing);
  });

  testWidgets('un capteur sans relevé n\'a pas de courbe', (pTester) async {
    await pTester.pumpWidget(localized(const SensorDetailScreen(sensor: Sensor(name: 'Cave'))));

    expect(find.text('1 relevé'), findsNothing);
    expect(find.text('0 relevés'), findsOneWidget);
    expect(find.byType(DayChart), findsNothing);
  });

  testWidgets('toucher la carte d\'un capteur ouvre son détail', (pTester) async {
    final vController = SensorsController(MemorySensorStore([_manyDays(5)]));
    await vController.load();
    await pTester.pumpWidget(localized(SensorsScreen(controller: vController)));

    await pTester.tap(find.text('Salon'));
    await pTester.pumpAndSettle();

    expect(find.byType(SensorDetailScreen), findsOneWidget);
    expect(find.text('Moyennes par jour'), findsOneWidget);
  });
}
