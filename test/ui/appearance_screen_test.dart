import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/app.dart';
import 'package:home/logic/appearance.dart';
import 'package:home/logic/units.dart';
import 'package:home/state/appearance_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/appearance_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/appearance_screen.dart';
import 'package:home/ui/theme.dart';

import '../support/localized.dart';

void main() {
  testWidgets('les choix de thème et de taille sont rangés', (pTester) async {
    final vStore = MemoryAppearanceStore();
    final vController = AppearanceController(vStore);
    await pTester.pumpWidget(localized(AppearanceScreen(controller: vController)));

    await pTester.tap(find.text('Clair'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Très grande'));
    await pTester.pumpAndSettle();

    expect(vStore.saved.theme, ThemeChoice.light);
    expect(vStore.saved.textScale, 1.3);
  });

  testWidgets('le choix de l\'unité est rangé et change l\'exemple', (pTester) async {
    final vStore = MemoryAppearanceStore();
    final vController = AppearanceController(vStore);
    await pTester.pumpWidget(localized(AppearanceScreen(controller: vController)));

    expect(find.textContaining('21,5 °C, 48 %'), findsOneWidget);

    await pTester.tap(find.text('Degrés Fahrenheit (°F)'));
    await pTester.pumpAndSettle();

    expect(vStore.saved.temperatureUnit, TemperatureUnit.fahrenheit);
    expect(find.textContaining('70,7 °F, 48 %'), findsOneWidget);
  });

  test('le thème clair a une palette plus sombre pour rester lisible', () {
    final vLight = buildTheme(pBrightness: Brightness.light);

    expect(vLight.brightness, Brightness.light);
    expect(vLight.extension<HomeColors>(), HomeColors.paper);
    expect(buildTheme().extension<HomeColors>(), HomeColors.slate);
  });

  testWidgets('l\'appli suit le thème choisi et agrandit le texte', (pTester) async {
    final vController = AppearanceController(
      MemoryAppearanceStore(const AppearanceSettings(theme: ThemeChoice.light, textScale: 1.5)),
    );
    await vController.load();
    final vSensors = SensorsController(MemorySensorStore());

    await pTester.pumpWidget(HomeApp(controller: vSensors, appearance: vController));
    await pTester.pumpAndSettle();

    final vContext = pTester.element(find.byType(Scaffold).first);
    expect(Theme.of(vContext).brightness, Brightness.light);
    expect(MediaQuery.textScalerOf(vContext).scale(10), 15);
  });
}
