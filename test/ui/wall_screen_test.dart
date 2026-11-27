import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/ac_units.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/ac_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/ac_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/sensors_screen.dart';
import 'package:home/ui/wall_display.dart';
import 'package:home/ui/wall_screen.dart';

import '../support/fake_daikin.dart';
import '../support/localized.dart';

class _FakeDisplay implements WallDisplay {
  final calls = <String>[];

  @override
  Future<void> enter() async => calls.add('enter');

  @override
  Future<void> leave() async => calls.add('leave');
}

void main() {
  const vHost = '192.168.1.20';
  final vNow = DateTime(2026, 12, 1, 8, 30);
  late FakeDaikinLink vLink;
  late AcController vAc;
  late SensorsController vSensors;
  late _FakeDisplay vDisplay;

  setUp(() {
    vLink = FakeDaikinLink()
      ..names[vHost] = 'Salon'
      ..states[vHost] = FakeDaikinLink.coolingAt22();
    vAc = AcController(
      MemoryAcStore([const AcUnit(name: 'Salon', host: vHost, sensorName: 'TP357 (1A2B)')]),
      vLink,
    );
    vSensors = SensorsController(
      MemorySensorStore([
        Sensor(
          name: 'TP357 (1A2B)',
          readings: [
            Reading(at: vNow.subtract(const Duration(minutes: 5)), temp: 21.5, humidity: 48),
          ],
        ),
      ]),
    );
    vDisplay = _FakeDisplay();
  });

  Future<void> open(WidgetTester pTester) async {
    pTester.view.physicalSize = const Size(1600, 900);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    await vSensors.load();
    await vAc.load();
    await pTester.pumpWidget(
      localized(WallScreen(sensors: vSensors, ac: vAc, display: vDisplay, clock: () => vNow)),
    );
    await pTester.pumpAndSettle();
  }

  Future<void> close(WidgetTester pTester) => pTester.pumpWidget(const SizedBox());

  testWidgets('l\'écran passe en plein écran à l\'ouverture et le rend à la fermeture', (
    pTester,
  ) async {
    await open(pTester);

    expect(vDisplay.calls, ['enter']);
    expect(find.text('08:30'), findsOneWidget);

    await close(pTester);

    expect(vDisplay.calls, ['enter', 'leave']);
  });

  testWidgets('une tuile montre la mesure du capteur et la consigne de la clim', (pTester) async {
    await open(pTester);

    expect(find.text('Salon'), findsOneWidget);
    expect(find.text('21,5 °C'), findsOneWidget);
    expect(find.text('48,0 %'), findsOneWidget);
    expect(find.text('22,0 °C'), findsOneWidget);
    expect(find.text('Éteindre'), findsOneWidget);

    await close(pTester);
  });

  testWidgets('les gros boutons éteignent la clim et changent la consigne de 0,5 °C', (
    pTester,
  ) async {
    await open(pTester);

    await pTester.tap(find.text('Éteindre'));
    await pTester.pumpAndSettle();
    expect(vLink.written.last.$2.power, isFalse);
    expect(find.text('Allumer'), findsOneWidget);

    await pTester.tap(find.byTooltip('Monter la consigne'));
    await pTester.pumpAndSettle();
    expect(vLink.written.last.$2.setpoint, '22.5');

    await pTester.tap(find.byTooltip('Baisser la consigne'));
    await pTester.pumpAndSettle();
    expect(vLink.written.last.$2.setpoint, '22.0');

    await close(pTester);
  });

  testWidgets('une commande refusée le dit', (pTester) async {
    await open(pTester);
    vLink.refuseWrites = true;

    await pTester.tap(find.text('Éteindre'));
    await pTester.pumpAndSettle();

    expect(find.text('La climatisation n\'a pas pris la commande.'), findsOneWidget);

    await close(pTester);
  });

  testWidgets('une clim injoignable et un relevé ancien sont signalés', (pTester) async {
    vLink.unreachable.add(vHost);
    vSensors = SensorsController(
      MemorySensorStore([
        Sensor(
          name: 'TP357 (1A2B)',
          readings: [Reading(at: vNow.subtract(const Duration(hours: 2)), temp: 20, humidity: 50)],
        ),
      ]),
    );

    await open(pTester);

    expect(find.text('Injoignable'), findsOneWidget);
    expect(find.text('Relevé de plus de 30 minutes'), findsOneWidget);
    expect(find.text('Éteindre'), findsNothing);

    await close(pTester);
  });

  testWidgets('sans clim ni capteur, l\'écran dit quoi ajouter', (pTester) async {
    vAc = AcController(MemoryAcStore(), vLink);
    vSensors = SensorsController(MemorySensorStore());

    await open(pTester);

    expect(find.textContaining('Rien à afficher'), findsOneWidget);

    await close(pTester);
  });

  testWidgets('la liste des capteurs ouvre l\'affichage mural, la croix en revient', (
    pTester,
  ) async {
    pTester.view.physicalSize = const Size(1600, 900);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    await vSensors.load();
    await vAc.load();
    await pTester.pumpWidget(
      localized(SensorsScreen(controller: vSensors, acController: vAc, wallDisplay: vDisplay)),
    );
    await pTester.pumpAndSettle();

    await pTester.tap(find.byTooltip('Affichage mural'));
    await pTester.pumpAndSettle();
    expect(find.byType(WallScreen), findsOneWidget);
    expect(vDisplay.calls, ['enter']);

    await pTester.tap(find.byTooltip('Quitter l\'affichage mural'));
    await pTester.pumpAndSettle();
    expect(find.byType(WallScreen), findsNothing);
    expect(vDisplay.calls, ['enter', 'leave']);
  });
}
