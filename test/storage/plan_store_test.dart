import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/automations.dart';
import 'package:home/logic/house_calendar.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/vacation.dart';
import 'package:home/storage/plan_store.dart';

void main() {
  late Directory vFolder;

  setUp(() => vFolder = Directory.systemTemp.createTempSync('home_plan_test'));
  tearDown(() => vFolder.deleteSync(recursive: true));

  final vSettings = PlanSettings(
    rooms: const [Room(acHost: '192.168.1.20')],
    rules: const [
      AutoRule(
        name: 'Humidité salle de bain',
        acHost: '192.168.1.20',
        metric: AutoMetric.humidity,
        side: AutoSide.above,
        threshold: 70,
        action: AutoActionKind.powerOff,
      ),
    ],
    vacation: VacationMode(from: DateTime(2026, 12, 18), until: DateTime(2026, 12, 28)),
  );

  test('en mémoire, ce qui est enregistré se relit', () async {
    final vStore = MemoryPlanStore();
    expect((await vStore.load()).rooms, isEmpty);

    await vStore.save(vSettings);

    expect((await vStore.load()).rules.single.name, 'Humidité salle de bain');
  });

  test('sans fichier, rien n\'est réglé', () async {
    final vLoaded = await FilePlanStore(vFolder).load();

    expect(vLoaded.rooms, isEmpty);
    expect(vLoaded.rules, isEmpty);
    expect(vLoaded.vacation, isNull);
  });

  test('les trois fichiers se relisent, sans fichier temporaire laissé', () async {
    final vStore = FilePlanStore(vFolder);

    await vStore.save(vSettings);
    final vLoaded = await vStore.load();

    expect(vLoaded.rooms.single.acHost, '192.168.1.20');
    expect(vLoaded.rules.single.threshold, 70);
    expect(vLoaded.vacation?.until, DateTime(2026, 12, 28));
    expect(vFolder.listSync().where((pFile) => pFile.path.endsWith('.tmp')), isEmpty);
  });

  test('retirer les vacances supprime leur fichier, et sans fichier le retrait passe', () async {
    final vStore = FilePlanStore(vFolder);
    await vStore.save(const PlanSettings());
    expect(File('${vFolder.path}/vacances.json').existsSync(), isFalse);

    await vStore.save(vSettings);
    expect(File('${vFolder.path}/vacances.json').existsSync(), isTrue);

    await vStore.save(PlanSettings(rooms: vSettings.rooms, rules: vSettings.rules));
    expect(File('${vFolder.path}/vacances.json').existsSync(), isFalse);
    expect((await vStore.load()).vacation, isNull);
  });

  test('le calendrier a son fichier, supprimé quand il revient à son état de départ', () async {
    final vStore = FilePlanStore(vFolder);
    final vFile = File('${vFolder.path}/calendrier.json');
    await vStore.save(const PlanSettings());
    expect(vFile.existsSync(), isFalse);

    await vStore.save(const PlanSettings(calendar: HouseCalendar(remoteWeekdays: {2, 4})));
    expect(vFile.existsSync(), isTrue);
    expect((await vStore.load()).calendar.remoteWeekdays, {2, 4});

    await vStore.save(const PlanSettings());
    expect(vFile.existsSync(), isFalse);
    expect((await vStore.load()).calendar.isDefault, isTrue);
  });
}
