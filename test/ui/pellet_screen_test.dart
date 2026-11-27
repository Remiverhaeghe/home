import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/pellet.dart';
import 'package:home/state/pellet_controller.dart';
import 'package:home/storage/pellet_store.dart';
import 'package:home/ui/pellet_screen.dart';

import '../support/fake_pellet.dart';
import '../support/localized.dart';

const _stove = PelletStove(
  name: 'Poêle salon',
  host: '192.168.1.60',
  serial: '123456',
  password: 'abcd1234',
);

void main() {
  late FakePelletLink vLink;
  late MemoryPelletStore vStore;
  late PelletController vController;

  setUp(() {
    vLink = FakePelletLink();
    vStore = MemoryPelletStore(_stove);
    vController = PelletController(vStore, vLink);
  });

  Future<void> open(WidgetTester pTester) async {
    await vController.load();
    await pTester.pumpWidget(localized(PelletScreen(controller: vController)));
    await pTester.pumpAndSettle();
  }

  testWidgets('sans poêle, l\'écran propose de l\'ajouter', (pTester) async {
    vStore.saved = null;

    await open(pTester);

    expect(find.textContaining('Aucun poêle enregistré'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ajouter le poêle'), findsOneWidget);
  });

  testWidgets('l\'état du poêle est affiché', (pTester) async {
    await open(pTester);

    expect(find.text('Poêle salon'), findsOneWidget);
    expect(find.text('18,5 °C'), findsOneWidget);
    expect(find.text('20,0 °C'), findsOneWidget);
    expect(find.text('Éteint'), findsOneWidget);
  });

  testWidgets('l\'interrupteur allume le poêle', (pTester) async {
    await open(pTester);

    await pTester.tap(find.byType(Switch));
    await pTester.pumpAndSettle();

    expect(vLink.powers, [true]);
    expect(find.text('Allumé'), findsOneWidget);
  });

  testWidgets('les boutons règlent la consigne par demi-degré', (pTester) async {
    await open(pTester);

    await pTester.tap(find.byTooltip('Monter de 0,5 °C'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.byTooltip('Baisser de 0,5 °C'));
    await pTester.pumpAndSettle();

    expect(vLink.targets, [20.5, 20.0]);
  });

  testWidgets('un poêle muet est signalé', (pTester) async {
    vLink.fail = true;

    await open(pTester);

    expect(find.text('Le poêle ne répond pas.'), findsOneWidget);
  });

  testWidgets('un ordre qui échoue le dit', (pTester) async {
    await open(pTester);
    vLink.fail = true;

    await pTester.tap(find.byType(Switch));
    await pTester.pumpAndSettle();

    expect(find.text('L\'ordre n\'a pas abouti.'), findsOneWidget);
  });

  testWidgets('le poêle se saisit et se retire', (pTester) async {
    vStore.saved = null;
    await open(pTester);

    await pTester.tap(find.widgetWithText(FilledButton, 'Ajouter le poêle'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.widgetWithText(TextField, 'Adresse du poêle'), '192.168.1.70');
    await pTester.enterText(find.widgetWithText(TextField, 'Numéro de série'), '777');
    await pTester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'motdepas');
    await pTester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await pTester.pumpAndSettle();

    expect(vStore.saved?.host, '192.168.1.70');

    await pTester.tap(find.byTooltip('Retirer'));
    await pTester.pumpAndSettle();
    await pTester.tap(find.widgetWithText(FilledButton, 'Retirer'));
    await pTester.pumpAndSettle();

    expect(vStore.saved, isNull);
  });

  testWidgets('une adresse publique est refusée avec un message', (pTester) async {
    vStore.saved = null;
    await open(pTester);

    await pTester.tap(find.widgetWithText(FilledButton, 'Ajouter le poêle'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.widgetWithText(TextField, 'Adresse du poêle'), '8.8.8.8');
    await pTester.enterText(find.widgetWithText(TextField, 'Numéro de série'), '777');
    await pTester.enterText(find.widgetWithText(TextField, 'Mot de passe'), 'motdepas');
    await pTester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await pTester.pumpAndSettle();

    expect(find.textContaining('Adresse refusée'), findsOneWidget);
    expect(vStore.saved, isNull);
  });
}
