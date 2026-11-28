@Tags(['captures'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/app.dart';
import 'package:home/state/house_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/house_store.dart';
import 'package:home/storage/sensor_store.dart';

import '../support/menu.dart';
import 'demo.dart';

/// Polices de Flutter : sans elles, les tests dessinent des carrés à la place du texte.
Future<void> _loadFonts() async {
  final vRoot = Platform.environment['FLUTTER_ROOT'];
  if (vRoot == null) {
    fail('FLUTTER_ROOT doit pointer vers le SDK Flutter pour charger les polices');
  }
  final vFiles = Directory(
    '$vRoot/bin/cache/artifacts/material_fonts',
  ).listSync().whereType<File>().toList();
  ByteData vRead(File pFile) => ByteData.sublistView(pFile.readAsBytesSync());
  bool vNamed(File pFile, String pStart) =>
      pFile.uri.pathSegments.last.toLowerCase().startsWith(pStart);

  final vRoboto = FontLoader('Roboto');
  for (final vFile in vFiles.where((pFile) => vNamed(pFile, 'roboto-'))) {
    vRoboto.addFont(Future.value(vRead(vFile)));
  }
  await vRoboto.load();
  final vIcons = FontLoader('MaterialIcons')
    ..addFont(Future.value(vRead(vFiles.firstWhere((pFile) => vNamed(pFile, 'materialicons')))));
  await vIcons.load();
}

Future<void> _capture(String pName) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('png/$pName.png'));

void _done() => debugDisableShadows = true;

Future<void> _openApp(WidgetTester pTester) async {
  // Écran de téléphone : 1080 × 2340 pixels
  pTester.view.physicalSize = const Size(1080, 2340);
  pTester.view.devicePixelRatio = 3;
  addTearDown(pTester.view.reset);
  // Les tests remplacent les ombres par un trait ; les captures veulent les vraies. Remises en
  // fin de test par _done, avant le contrôle des variables de dessin.
  debugDisableShadows = false;

  final vSensors = SensorsController(MemorySensorStore(demoSensors()));
  await vSensors.load();
  final vHouse = HouseController(MemoryHouseStore(demoHouse()));
  await vHouse.load();
  await pTester.pumpWidget(HomeApp(controller: vSensors, houseController: vHouse));
  await pTester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('capteurs de la maison', (pTester) async {
    await _openApp(pTester);

    await _capture('01-capteurs');
    _done();
  });

  testWidgets('courbes d\'un capteur', (pTester) async {
    await _openApp(pTester);

    await pTester.tap(find.text('Salon'));
    await pTester.pumpAndSettle();

    await _capture('02-capteur');
    _done();
  });

  testWidgets('les pièces', (pTester) async {
    await _openApp(pTester);

    await openMenuEntry(pTester, 'Les pièces');
    await pTester.pumpAndSettle();

    await _capture('03-pieces');
    _done();
  });
}
