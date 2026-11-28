import 'dart:convert';

import 'alerts.dart';

/// Bornes de la périodicité d'un rappel, en jours.
const reminderDaysMin = 1;
const reminderDaysMax = 730;

/// Un entretien qui revient : nettoyer les filtres d'une clim, changer une pile, purger un
/// radiateur. C'est Rémi qui donne le nom et la périodicité ; rien n'est supposé ici.
class Reminder {
  const Reminder({required this.name, required this.everyDays, required this.lastDone});

  final String name;
  final int everyDays;

  /// Dernier entretien fait, ou jour de création du rappel.
  final DateTime lastDone;

  DateTime get dueOn => DateTime(lastDone.year, lastDone.month, lastDone.day + everyDays);

  bool isDue(DateTime pNow) => !pNow.isBefore(dueOn);

  /// Jours restants avant l'échéance, négatif quand elle est dépassée.
  int daysLeft(DateTime pNow) => dueOn.difference(DateTime(pNow.year, pNow.month, pNow.day)).inDays;

  Reminder done(DateTime pNow) => Reminder(name: name, everyDays: everyDays, lastDone: pNow);

  Map<String, Object> toJson() => {
    'nom': name,
    'jours': everyDays,
    'fait': lastDone.toIso8601String(),
  };
}

/// Relit la liste ; un rappel abîmé est ignoré, les autres sont gardés.
List<Reminder> parseReminders(String pText) {
  final rReminders = <Reminder>[];
  try {
    for (final vItem in jsonDecode(pText) as List<dynamic>) {
      final vJson = vItem as Map<String, dynamic>;
      final vName = vJson['nom'];
      final vDays = vJson['jours'];
      final vDone = DateTime.tryParse('${vJson['fait']}');
      if (vName is String &&
          vName.trim().isNotEmpty &&
          vDays is int &&
          vDays >= reminderDaysMin &&
          vDays <= reminderDaysMax &&
          vDone != null) {
        rReminders.add(Reminder(name: vName, everyDays: vDays, lastDone: vDone));
      }
    }
  } on Object {
    return rReminders;
  }

  return rReminders;
}

String remindersJson(List<Reminder> pReminders) =>
    jsonEncode([for (final vReminder in pReminders) vReminder.toJson()]);

/// Les rappels échus, sous forme d'alertes : le nom du rappel tient lieu de capteur.
List<SensorAlert> dueReminderAlerts(List<Reminder> pReminders, DateTime pNow) => [
  for (final vReminder in pReminders)
    if (vReminder.isDue(pNow)) SensorAlert(sensorName: vReminder.name, kind: AlertKind.maintenance),
];
