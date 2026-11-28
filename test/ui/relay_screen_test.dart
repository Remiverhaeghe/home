import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/relay.dart';
import 'package:home/state/relay_controller.dart';
import 'package:home/storage/relay_store.dart';
import 'package:home/ui/relay_screen.dart';

import '../support/fake_relay.dart';
import '../support/localized.dart';

void main() {
  late FakeRelayLink vLink;
  late MemoryRelayStore vStore;
  late RelayController vController;

  setUp(() {
    vLink = FakeRelayLink();
    vStore = MemoryRelayStore([
      const RelayButton(name: 'Porte du garage', host: '192.168.1.40', kind: RelayKind.garage),
      const RelayButton(name: 'Velux salon', host: '192.168.1.41', kind: RelayKind.velux),
    ]);
    vController = RelayController(vStore, vLink);
  });

  Future<void> open(WidgetTester pTester) async {
    await vController.load();
    await pTester.pumpWidget(localized(RelayScreen(controller: vController)));
    await pTester.pumpAndSettle();
  }

  testWidgets('sans bouton, l\'écran dit quoi ajouter', (pTester) async {
    vStore.saved = [];

    await open(pTester);

    expect(find.textContaining('Aucun bouton pour l'), findsOneWidget);
  });

  testWidgets('la porte de garage demande confirmation avant d\'envoyer', (pTester) async {
    await open(pTester);

    await pTester.tap(find.widgetWithText(FilledButton, 'Appuyer').first);
    await pTester.pumpAndSettle();

    expect(find.text('Commander la porte ?'), findsOneWidget);
    expect(vLink.pulses, isEmpty);

    await pTester.tap(find.text('Annuler'));
    await pTester.pumpAndSettle();

    expect(vLink.pulses, isEmpty);

    await pTester.tap(find.widgetWithText(FilledButton, 'Appuyer').first);
    await pTester.pumpAndSettle();
    await pTester.tap(find.text('Envoyer l\'appui'));
    await pTester.pumpAndSettle();

    expect(vLink.pulses.single.name, 'Porte du garage');
    expect(find.text('Appui envoyé.'), findsOneWidget);
  });

  testWidgets('un Velux part sans confirmation', (pTester) async {
    await open(pTester);

    await pTester.tap(find.widgetWithText(FilledButton, 'Appuyer').last);
    await pTester.pumpAndSettle();

    expect(vLink.pulses.single.name, 'Velux salon');
    expect(find.text('Commander la porte ?'), findsNothing);
  });

  testWidgets('un boîtier muet et un double appui sont signalés', (pTester) async {
    await open(pTester);
    vLink.fail = true;

    await pTester.tap(find.widgetWithText(FilledButton, 'Appuyer').last);
    await pTester.pumpAndSettle();
    expect(find.text('Le boîtier n\'a pas répondu.'), findsOneWidget);

    vLink.fail = false;
    await pTester.pumpAndSettle(const Duration(seconds: 5));
    await pTester.tap(find.widgetWithText(FilledButton, 'Appuyer').last);
    await pTester.pumpAndSettle();
    await pTester.tap(find.widgetWithText(FilledButton, 'Appuyer').last);
    await pTester.pumpAndSettle();

    expect(vLink.pulses, hasLength(1));
    expect(find.text('Appui déjà envoyé : attends quelques secondes.'), findsOneWidget);
  });

  testWidgets('ajouter un bouton : saisie, refus hors de la maison, puis enregistrement', (
    pTester,
  ) async {
    vStore.saved = [];
    await open(pTester);

    await pTester.tap(find.text('Ajouter un bouton'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.widgetWithText(TextField, 'Nom du bouton'), 'Garage');
    await pTester.enterText(find.widgetWithText(TextField, 'Adresse du boîtier'), '8.8.8.8');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();

    expect(find.textContaining('Adresse refusée'), findsOneWidget);
    expect(vController.buttons, isEmpty);

    await pTester.tap(find.text('Ajouter un bouton'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.widgetWithText(TextField, 'Nom du bouton'), 'Garage');
    await pTester.enterText(find.widgetWithText(TextField, 'Adresse du boîtier'), '192.168.1.40');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();

    expect(vController.buttons.single.name, 'Garage');
    expect(vController.buttons.single.kind, RelayKind.garage);
  });

  testWidgets('retirer un bouton demande confirmation', (pTester) async {
    await open(pTester);

    await pTester.tap(find.byTooltip('Retirer').first);
    await pTester.pumpAndSettle();
    expect(find.textContaining('Retirer « Porte du garage »'), findsOneWidget);

    await pTester.tap(find.widgetWithText(FilledButton, 'Retirer'));
    await pTester.pumpAndSettle();

    expect(vController.buttons.map((pButton) => pButton.name), ['Velux salon']);
  });

  testWidgets('l\'écran du garage ne montre que la porte', (pTester) async {
    await vController.load();
    await pTester.pumpWidget(localized(RelayScreen.garage(controller: vController)));
    await pTester.pumpAndSettle();

    expect(find.text('Porte de garage'), findsOneWidget);
    expect(find.text('Porte du garage'), findsOneWidget);
    expect(find.text('Velux salon'), findsNothing);
  });

  testWidgets('l\'écran des Velux ne montre pas la porte et ajoute un Velux', (pTester) async {
    await vController.load();
    await pTester.pumpWidget(localized(RelayScreen.velux(controller: vController)));
    await pTester.pumpAndSettle();

    expect(find.text('Velux salon'), findsOneWidget);
    expect(find.text('Porte du garage'), findsNothing);

    await pTester.tap(find.text('Ajouter un bouton'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.widgetWithText(TextField, 'Nom du bouton'), 'Velux chambre');
    await pTester.enterText(find.widgetWithText(TextField, 'Adresse du boîtier'), '192.168.1.42');
    await pTester.tap(find.text('Enregistrer'));
    await pTester.pumpAndSettle();

    expect(vController.buttons.last.name, 'Velux chambre');
    expect(vController.buttons.last.kind, RelayKind.velux);
  });

  testWidgets('l\'écran du garage propose le genre garage sans choix', (pTester) async {
    await vController.load();
    await pTester.pumpWidget(localized(RelayScreen.garage(controller: vController)));
    await pTester.pumpAndSettle();

    await pTester.tap(find.text('Ajouter un bouton'));
    await pTester.pumpAndSettle();

    expect(find.text('Ce qu\'il commande'), findsNothing);
  });
}
