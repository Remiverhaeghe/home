import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/pending_readings.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/background_files.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/live_screen.dart';

import '../support/fake_background.dart';
import '../support/fake_link.dart';
import '../support/localized.dart';

void main() {
  late FakeTp357Link vLink;
  late FakeBackgroundControl vBackground;
  late Directory vFolder;
  late BackgroundFiles vFiles;

  setUp(() {
    vLink = FakeTp357Link();
    vBackground = FakeBackgroundControl();
    vFolder = Directory.systemTemp.createTempSync('home_switch_test');
    vFiles = BackgroundFiles(vFolder);
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<void> follow(WidgetTester pTester, {bool pWithBackground = true}) async {
    // Dans runAsync : la lecture du fichier des capteurs suivis se fait en vrai temps
    await pTester.runAsync(() async {
      await pTester.pumpWidget(
        localized(
          LiveScreen(
            link: vLink,
            controller: SensorsController(MemorySensorStore()),
            background: pWithBackground ? vBackground : null,
            files: pWithBackground ? vFiles : null,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pTester.pump();
    vLink.devices.add((id: 'AA', name: 'TP357 (1A2B)'));
    await pTester.pump();
    await pTester.tap(find.text('Suivre'));
    await pTester.pump();
  }

  testWidgets('sans service ni fichiers, l\'interrupteur n\'apparaît pas', (pTester) async {
    await follow(pTester, pWithBackground: false);

    expect(find.text('Relever en arrière-plan'), findsNothing);
  });

  testWidgets('activer démarre le service et enregistre le capteur suivi', (pTester) async {
    await follow(pTester);
    expect(find.text('Relever en arrière-plan'), findsOneWidget);

    await pTester.runAsync(() async {
      await pTester.tap(find.byType(Switch));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pTester.pump();

    expect(vBackground.starts, 1);
    expect(vBackground.lastTitle, 'Home relève les capteurs');
    expect(vBackground.lastText, 'Une mesure toutes les 5 minutes');
    expect(pTester.widget<Switch>(find.byType(Switch)).value, isTrue);
    final vSaved = await pTester.runAsync(vFiles.loadFollowed);
    expect(vSaved!.single.id, 'AA');
    expect(vSaved.single.name, 'TP357 (1A2B)');
  });

  testWidgets('sans l\'accord pour les notifications, rien n\'est enregistré', (pTester) async {
    vBackground.allowed = false;
    await follow(pTester);

    await pTester.runAsync(() async {
      await pTester.tap(find.byType(Switch));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pTester.pump();

    expect(find.textContaining('accord pour les notifications'), findsOneWidget);
    expect(pTester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(await pTester.runAsync(vFiles.loadFollowed), isEmpty);
  });

  testWidgets('désactiver retire le capteur et arrête le service quand il n\'en reste aucun', (
    pTester,
  ) async {
    await follow(pTester);
    await pTester.runAsync(() async {
      await pTester.tap(find.byType(Switch));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pTester.pump();

    await pTester.runAsync(() async {
      await pTester.tap(find.byType(Switch));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pTester.pump();

    expect(vBackground.stops, 1);
    expect(pTester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(await pTester.runAsync(vFiles.loadFollowed), isEmpty);
  });

  testWidgets('un autre capteur suivi garde le service en marche', (pTester) async {
    await vFiles.saveFollowed([const FollowedDevice(id: 'BB', name: 'TP357 (3C4D)')]);
    await follow(pTester);
    await pTester.runAsync(() async {
      await pTester.tap(find.byType(Switch));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pTester.pump();

    await pTester.runAsync(() async {
      await pTester.tap(find.byType(Switch));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await pTester.pump();

    expect(vBackground.stops, 0);
    final vSaved = await pTester.runAsync(vFiles.loadFollowed);
    expect(vSaved!.single.id, 'BB');
  });

  testWidgets('un capteur déjà suivi s\'affiche activé', (pTester) async {
    await vFiles.saveFollowed([const FollowedDevice(id: 'AA', name: 'TP357 (1A2B)')]);

    await follow(pTester);

    expect(pTester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
}
