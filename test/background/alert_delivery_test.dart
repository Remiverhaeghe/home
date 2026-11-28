import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/background/alert_delivery.dart';
import 'package:home/logic/alerts.dart';
import 'package:home/logic/heating_costs.dart';
import 'package:home/logic/reminders.dart';
import 'package:home/storage/background_files.dart';

import '../support/fake_background.dart';

void main() {
  late Directory vFolder;
  late BackgroundFiles vFiles;
  final vNotifier = FakeAlertNotifier();
  const vFrost = SensorAlert(sensorName: 'Cave', kind: AlertKind.frost, value: 2);
  const vHumid = SensorAlert(sensorName: 'Salle de bain', kind: AlertKind.humidity, value: 80);

  setUp(() {
    vFolder = Directory.systemTemp.createTempSync('home_delivery');
    vFiles = BackgroundFiles(vFolder);
    vNotifier.shown.clear();
  });
  tearDown(() => vFolder.deleteSync(recursive: true));

  test('sans heures silencieuses, tout est notifié et noté', () async {
    final vShown = await deliverAlerts(
      pFiles: vFiles,
      pNotifier: vNotifier,
      pAlerts: [vHumid, vFrost],
      pNow: DateTime(2026, 11, 28, 23),
    );

    expect(vShown, [vHumid, vFrost]);
    expect(vNotifier.shown.single, [vHumid, vFrost]);
    expect(await vFiles.loadAlertHistory(), hasLength(2));
  });

  test('pendant les heures silencieuses, le gel sonne et le reste est seulement noté', () async {
    await vFiles.setQuietHours(const OffPeak(startHour: 22, endHour: 7));

    final vShown = await deliverAlerts(
      pFiles: vFiles,
      pNotifier: vNotifier,
      pAlerts: [vHumid, vFrost],
      pNow: DateTime(2026, 11, 28, 23),
    );

    expect(vShown, [vFrost]);
    expect(vNotifier.shown.single, [vFrost]);
    expect(await vFiles.loadAlertHistory(), hasLength(2));
  });

  test('sans alerte, rien n\'est écrit ni notifié', () async {
    await deliverAlerts(
      pFiles: vFiles,
      pNotifier: vNotifier,
      pAlerts: const [],
      pNow: DateTime(2026, 11, 28, 23),
    );

    expect(vNotifier.shown, isEmpty);
    expect(await vFiles.loadAlertHistory(), isEmpty);
  });

  test('les heures silencieuses se relisent, et se retirent', () async {
    expect(await vFiles.quietHours(), isNull);

    await vFiles.setQuietHours(const OffPeak(startHour: 22, endHour: 7));
    final vQuiet = await vFiles.quietHours();
    expect(vQuiet?.startHour, 22);
    expect(vQuiet?.endHour, 7);

    await vFiles.setQuietHours(null);
    expect(await vFiles.quietHours(), isNull);
  });

  test('un entretien échu est notifié même sans alerte de capteur', () async {
    await vFiles.saveReminders([
      Reminder(name: 'Filtres', everyDays: 30, lastDone: DateTime(2026, 10, 1)),
    ]);

    final vShown = await deliverAlerts(
      pFiles: vFiles,
      pNotifier: vNotifier,
      pAlerts: const [],
      pNow: DateTime(2026, 11, 28, 12),
    );

    expect(vShown.single.kind, AlertKind.maintenance);
    expect(vNotifier.shown.single.single.sensorName, 'Filtres');
    expect((await vFiles.loadAlertHistory()).single.kind, AlertKind.maintenance);
  });

  test('la fin d\'aération est notifiée, et reste silencieuse la nuit', () async {
    await vFiles.setAiringUntil(DateTime(2026, 11, 28, 23, 15));
    await vFiles.setQuietHours(const OffPeak(startHour: 22, endHour: 7));

    final vNight = await deliverAlerts(
      pFiles: vFiles,
      pNotifier: vNotifier,
      pAlerts: const [],
      pNow: DateTime(2026, 11, 28, 23, 20),
    );
    expect(vNight, isEmpty);
    expect((await vFiles.loadAlertHistory()).single.kind, AlertKind.airing);

    await vFiles.setQuietHours(null);
    final vDay = await deliverAlerts(
      pFiles: vFiles,
      pNotifier: vNotifier,
      pAlerts: const [],
      pNow: DateTime(2026, 11, 28, 23, 20),
    );
    expect(vDay.single.kind, AlertKind.airing);
  });
}
