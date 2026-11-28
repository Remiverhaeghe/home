import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/relay.dart';
import 'package:home/state/relay_controller.dart';
import 'package:home/storage/background_files.dart';
import 'package:home/storage/relay_store.dart';
import 'package:home/ui/plan_airing_chip.dart';

import '../support/fake_relay.dart';
import '../support/localized.dart';

void main() {
  final vNow = DateTime(2026, 12, 7, 9);
  late Directory vFolder;
  late BackgroundFiles vFiles;
  late FakeRelayLink vLink;

  setUp(() {
    vFolder = Directory.systemTemp.createTempSync('home_airing');
    vFiles = BackgroundFiles(vFolder);
    vLink = FakeRelayLink();
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<void> settle(WidgetTester pTester) async {
    for (var vTry = 0; vTry < 10; vTry++) {
      await pTester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await pTester.pump();
    }
  }

  Future<RelayController> open(WidgetTester pTester, List<RelayButton> pButtons) async {
    final vRelays = RelayController(MemoryRelayStore(pButtons), vLink, clock: () => vNow);
    await vRelays.load();
    await pTester.pumpWidget(
      localized(
        Scaffold(
          body: AiringChip(relays: vRelays, files: vFiles, clock: () => vNow),
        ),
      ),
    );
    await settle(pTester);

    return vRelays;
  }

  testWidgets('sans Velux, le scénario n\'apparaît pas', (pTester) async {
    await open(pTester, [
      const RelayButton(name: 'Garage', host: '192.168.1.40', kind: RelayKind.garage),
    ]);

    expect(find.byKey(const Key('scenario-airing')), findsNothing);
  });

  testWidgets('Aération presse les Velux, jamais le garage, et note la fin du rappel', (
    pTester,
  ) async {
    await open(pTester, [
      const RelayButton(name: 'Garage', host: '192.168.1.40', kind: RelayKind.garage),
      const RelayButton(name: 'Velux salon', host: '192.168.1.41', kind: RelayKind.velux),
    ]);

    await pTester.tap(find.byKey(const Key('scenario-airing')));
    await settle(pTester);

    expect(vLink.pulses.map((pButton) => pButton.name), ['Velux salon']);
    expect(await pTester.runAsync(vFiles.airingUntil), DateTime(2026, 12, 7, 9, 15));
    expect(pTester.widget<FilterChip>(find.byKey(const Key('scenario-airing'))).selected, isTrue);

    await pTester.tap(find.byKey(const Key('scenario-airing')));
    await settle(pTester);

    expect(await pTester.runAsync(vFiles.airingUntil), isNull);
    expect(vLink.pulses, hasLength(1));
  });
}
