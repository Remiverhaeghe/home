import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/alerts.dart';
import 'package:home/logic/reminders.dart';

void main() {
  final vStart = DateTime(2026, 11, 1, 18);
  final vReminder = Reminder(name: 'Filtres du salon', everyDays: 30, lastDone: vStart);

  test('l\'échéance tombe au début du jour, trente jours après', () {
    expect(vReminder.dueOn, DateTime(2026, 12, 1));
    expect(vReminder.isDue(DateTime(2026, 11, 30, 23)), isFalse);
    expect(vReminder.isDue(DateTime(2026, 12, 1)), isTrue);
  });

  test('les jours restants deviennent négatifs une fois l\'échéance passée', () {
    expect(vReminder.daysLeft(DateTime(2026, 11, 28, 12)), 3);
    expect(vReminder.daysLeft(DateTime(2026, 12, 1, 9)), 0);
    expect(vReminder.daysLeft(DateTime(2026, 12, 4, 9)), -3);
  });

  test('« fait » repart d\'aujourd\'hui', () {
    final vDone = vReminder.done(DateTime(2026, 12, 4, 9));

    expect(vDone.isDue(DateTime(2026, 12, 4, 10)), isFalse);
    expect(vDone.dueOn, DateTime(2027, 1, 3));
  });

  test('seuls les rappels échus donnent une alerte d\'entretien', () {
    final vOther = Reminder(name: 'Piles', everyDays: 365, lastDone: vStart);

    final vAlerts = dueReminderAlerts([vReminder, vOther], DateTime(2026, 12, 2));

    expect(vAlerts, hasLength(1));
    expect(vAlerts.single.sensorName, 'Filtres du salon');
    expect(vAlerts.single.kind, AlertKind.maintenance);
  });

  test('la liste s\'écrit et se relit, un rappel abîmé est ignoré', () {
    final vText = remindersJson([vReminder]).replaceFirst(
      ']',
      ',{"nom":"","jours":5,"fait":"2026-11-01"},{"nom":"X","jours":0,"fait":"2026-11-01"}]',
    );

    final vBack = parseReminders(vText);

    expect(vBack, hasLength(1));
    expect(vBack.single.name, 'Filtres du salon');
    expect(vBack.single.everyDays, 30);
    expect(vBack.single.lastDone, vStart);
    expect(parseReminders('pas du json'), isEmpty);
  });
}
