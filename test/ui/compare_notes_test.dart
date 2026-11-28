import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/reading.dart';
import 'package:home/state/notes_controller.dart';
import 'package:home/state/sensors_controller.dart';
import 'package:home/storage/notes_store.dart';
import 'package:home/storage/sensor_store.dart';
import 'package:home/ui/compare_screen.dart';
import 'package:home/ui/notes_section.dart';

import '../support/localized.dart';

List<Reading> _days(double pTemp) => [
  for (var vDay = 1; vDay <= 5; vDay++)
    Reading(at: DateTime(2026, 11, vDay, 12), temp: pTemp, humidity: 50),
];

void main() {
  testWidgets('la comparaison écrit l\'écart moyen des deux capteurs', (pTester) async {
    final vSensors = SensorsController(
      MemorySensorStore([
        Sensor(name: 'Salon', readings: _days(21)),
        Sensor(name: 'Cave', readings: _days(15)),
      ]),
    );
    await vSensors.load();

    pTester.view.physicalSize = const Size(800, 3000);
    pTester.view.devicePixelRatio = 1;
    addTearDown(pTester.view.reset);
    await pTester.pumpWidget(localized(CompareScreen(controller: vSensors)));

    final vShown = pTester.widgetList<Text>(find.byType(Text)).map((pText) => pText.data ?? '');
    expect(
      vShown.any((pText) => RegExp(r'\+6[,.]0 °C').hasMatch(pText)),
      isTrue,
      reason: vShown.join(' | '),
    );
    expect(find.textContaining('sur 5 jours'), findsOneWidget);
  });

  testWidgets('sans jours communs, la comparaison le dit', (pTester) async {
    final vSensors = SensorsController(
      MemorySensorStore([Sensor(name: 'Salon', readings: _days(21)), const Sensor(name: 'Cave')]),
    );
    await vSensors.load();

    await pTester.pumpWidget(localized(CompareScreen(controller: vSensors)));

    expect(find.textContaining('Pas assez de jours en commun'), findsOneWidget);
  });

  testWidgets('une note s\'ajoute et se retire', (pTester) async {
    final vNotes = NotesController(MemoryNotesStore());
    await vNotes.load();
    await pTester.pumpWidget(
      localized(
        Scaffold(
          body: SingleChildScrollView(
            child: NotesSection(
              controller: vNotes,
              sensor: const Sensor(name: 'Salon'),
              clock: () => DateTime(2026, 11, 27),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Aucune note'), findsOneWidget);

    await pTester.tap(find.text('Ajouter une note'));
    await pTester.pumpAndSettle();
    await pTester.enterText(find.byType(TextField), 'Isolation posée');
    await pTester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await pTester.pumpAndSettle();

    expect(find.text('Isolation posée'), findsOneWidget);
    expect(vNotes.notes.single.sensor, 'Salon');

    await pTester.tap(find.byTooltip('Retirer la note'));
    await pTester.pumpAndSettle();

    expect(vNotes.notes, isEmpty);
  });
}
