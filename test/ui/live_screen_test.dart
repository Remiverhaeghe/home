import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/tp357.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/live_screen.dart';

import '../support/fake_link.dart';
import '../support/localized.dart';

void main() {
  late FakeTp357Link vLink;
  late SensorsController vController;

  setUp(() {
    vLink = FakeTp357Link();
    vController = SensorsController(MemorySensorStore());
  });

  Future<void> open(WidgetTester pTester) async {
    await pTester.pumpWidget(localized(LiveScreen(link: vLink, controller: vController)));
  }

  testWidgets('la recherche est annoncée, puis les capteurs trouvés sont listés', (pTester) async {
    await open(pTester);
    expect(find.text('Recherche des capteurs TP357…'), findsOneWidget);

    vLink.devices.add((id: 'AA', name: 'TP357 (1A2B)'));
    await pTester.pump();

    expect(find.text('TP357 (1A2B)'), findsOneWidget);
    expect(find.text('Suivre'), findsOneWidget);
    expect(find.text('Recherche des capteurs TP357…'), findsNothing);
  });

  testWidgets('suivre un capteur affiche et garde ses mesures', (pTester) async {
    await open(pTester);
    vLink.devices.add((id: 'AA', name: 'TP357 (1A2B)'));
    await pTester.pump();

    await pTester.tap(find.text('Suivre'));
    await pTester.pump();
    expect(find.text('Mesure en direct de TP357 (1A2B)'), findsOneWidget);
    expect(find.text('En attente de la première mesure…'), findsOneWidget);

    vLink.liveValues.add((temp: 21.5, humidity: 48));
    await pTester.pump();

    expect(find.text('21,5 °C'), findsOneWidget);
    expect(find.text('48,0 %'), findsOneWidget);
    expect(vController.sensors.single.name, 'TP357 (1A2B)');
    expect(vController.sensors.single.last!.temp, 21.5);
  });

  testWidgets('une panne Bluetooth est dite', (pTester) async {
    await open(pTester);

    vLink.devices.addError(StateError('Bluetooth coupé'));
    await pTester.pump();

    expect(find.textContaining('Le Bluetooth ne répond pas'), findsOneWidget);
    expect(find.textContaining('Aucun TP357 trouvé'), findsOneWidget);
  });

  testWidgets('le diagnostic n\'est pas proposé au TP357S', (pTester) async {
    await open(pTester);
    vLink.devices.add((id: 'BB', name: 'TP357S (3C4D)'));
    await pTester.pump();

    await pTester.tap(find.text('Suivre'));
    await pTester.pump();

    expect(find.text('Diagnostic de l\'historique'), findsNothing);
  });

  testWidgets('le diagnostic affiche les trames reçues et les copie', (pTester) async {
    final vCopied = <String>[];
    pTester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      pCall,
    ) async {
      if (pCall.method == 'Clipboard.setData') {
        vCopied.add((pCall.arguments as Map)['text'] as String);
      }

      return null;
    });
    addTearDown(
      () => pTester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(pTester);
    vLink.devices.add((id: 'AA', name: 'TP357 (1A2B)'));
    await pTester.pump();
    await pTester.tap(find.text('Suivre'));
    await pTester.pump();

    await pTester.tap(find.text('Diagnostic de l\'historique'));
    await pTester.pumpAndSettle();
    expect(find.text('Aucune trame reçue'), findsOneWidget);

    await pTester.tap(find.text('7 jours'));
    await pTester.pump();
    await pTester.tap(find.text('Demander l\'historique'));
    await pTester.pump();
    vLink.historyFrames.add([0xA6, 0x10, 0x00, 0x00, 0xEB, 0x00, 0x3D]);
    await pTester.pump();

    expect(vLink.requested.single, ('AA', HistoryPeriod.week));
    expect(find.text('1 trame reçue'), findsOneWidget);
    expect(find.text('a6 10 00 00 eb 00 3d'), findsOneWidget);

    await pTester.tap(find.text('Copier les trames'));
    await pTester.pump();

    expect(vCopied.single, 'a6 10 00 00 eb 00 3d');
    expect(find.text('Trames copiées'), findsOneWidget);
  });

  testWidgets('une erreur pendant l\'historique est dite', (pTester) async {
    await open(pTester);
    vLink.devices.add((id: 'AA', name: 'TP357 (1A2B)'));
    await pTester.pump();
    await pTester.tap(find.text('Suivre'));
    await pTester.pump();
    await pTester.tap(find.text('Diagnostic de l\'historique'));
    await pTester.pumpAndSettle();

    await pTester.tap(find.text('Demander l\'historique'));
    await pTester.pump();
    vLink.historyFrames.addError(StateError('coupé'));
    await pTester.pump();

    expect(find.textContaining('Le Bluetooth ne répond pas'), findsOneWidget);
  });
}
