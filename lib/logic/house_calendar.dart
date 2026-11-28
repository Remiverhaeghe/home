/// Calendrier de la maison : quels jours se comportent comme un jour de repos (jours fériés,
/// ponts, congés) et quels jours se passent à la maison (télétravail). Le planning de chaque pièce
/// s'en sert pour choisir ses plages du jour.
library;

import 'dart:convert';

import 'holidays.dart';

/// Numéro de jour du planning réservé au télétravail ; 1 à 7 sont lundi à dimanche.
const remoteDayKey = 8;

/// Comment on traite les jours fériés : comme un samedi, comme un dimanche, ou comme un jour normal.
enum HolidayRule { none, saturday, sunday }

/// Ce que l'on décide pour une date précise, quel que soit le jour de la semaine.
enum DayOverride { normal, remote, rest }

/// Nature d'un jour une fois tout pris en compte.
enum DayKind { normal, remote, rest }

class HouseCalendar {
  const HouseCalendar({
    this.remoteWeekdays = const {},
    this.holidays = HolidayRule.sunday,
    this.overrides = const {},
  });

  /// Jours de la semaine (1 lundi à 7 dimanche) passés à la maison.
  final Set<int> remoteWeekdays;

  final HolidayRule holidays;

  /// Décisions pour des dates précises (à minuit) : elles passent avant tout le reste.
  final Map<DateTime, DayOverride> overrides;

  bool get isDefault =>
      remoteWeekdays.isEmpty && holidays == HolidayRule.sunday && overrides.isEmpty;

  HouseCalendar copyWith({
    Set<int>? remoteWeekdays,
    HolidayRule? holidays,
    Map<DateTime, DayOverride>? overrides,
  }) => HouseCalendar(
    remoteWeekdays: remoteWeekdays ?? this.remoteWeekdays,
    holidays: holidays ?? this.holidays,
    overrides: overrides ?? this.overrides,
  );

  /// Un jour de repos décidé à la main passe avant le férié, qui passe avant le télétravail.
  DayKind kindOf(DateTime pDay) {
    final vDay = DateTime(pDay.year, pDay.month, pDay.day);
    final vOverride = overrides[vDay];
    if (vOverride != null) {
      return switch (vOverride) {
        DayOverride.normal => DayKind.normal,
        DayOverride.remote => DayKind.remote,
        DayOverride.rest => DayKind.rest,
      };
    }
    if (holidays != HolidayRule.none && holidayOn(vDay) != null) {
      return DayKind.rest;
    }

    return remoteWeekdays.contains(vDay.weekday) ? DayKind.remote : DayKind.normal;
  }

  /// Numéro du planning à lire pour [pDay] : le samedi ou le dimanche pour un jour de repos, le
  /// numéro de télétravail s'il y a des plages pour lui ([pHasRemoteSlots]), sinon le jour même.
  int keyOf(DateTime pDay, {required bool pHasRemoteSlots}) => switch (kindOf(pDay)) {
    DayKind.rest => holidays == HolidayRule.saturday ? DateTime.saturday : DateTime.sunday,
    DayKind.remote => pHasRemoteSlots ? remoteDayKey : pDay.weekday,
    DayKind.normal => pDay.weekday,
  };
}

const _version = 1;

String _dayKey(DateTime pDay) =>
    '${pDay.year.toString().padLeft(4, '0')}-${pDay.month.toString().padLeft(2, '0')}-'
    '${pDay.day.toString().padLeft(2, '0')}';

/// Fichier `calendrier.json`.
String calendarJson(HouseCalendar pCalendar) => const JsonEncoder.withIndent('  ').convert({
  'version': _version,
  'remoteWeekdays': ([...pCalendar.remoteWeekdays]..sort()),
  'holidays': pCalendar.holidays.name,
  'overrides': {
    for (final vEntry in pCalendar.overrides.entries) _dayKey(vEntry.key): vEntry.value.name,
  },
});

/// Relit le fichier ; un fichier abîmé ou une valeur inconnue redonnent le calendrier de départ.
HouseCalendar parseCalendar(String pText) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pText);
  } on FormatException {
    return const HouseCalendar();
  }
  if (vRoot is! Map<String, dynamic> || vRoot['version'] != _version) {
    return const HouseCalendar();
  }
  final vWeekdays = vRoot['remoteWeekdays'];
  final vRule = HolidayRule.values.where((pRule) => pRule.name == vRoot['holidays']);
  final vRaw = vRoot['overrides'];
  final vOverrides = <DateTime, DayOverride>{};
  if (vRaw is Map) {
    for (final vEntry in vRaw.entries) {
      final vDate = DateTime.tryParse('${vEntry.key}');
      final vKind = DayOverride.values.where((pKind) => pKind.name == vEntry.value);
      if (vDate != null && vKind.isNotEmpty) {
        vOverrides[DateTime(vDate.year, vDate.month, vDate.day)] = vKind.first;
      }
    }
  }

  return HouseCalendar(
    remoteWeekdays: vWeekdays is List
        ? vWeekdays.whereType<int>().where((pDay) => pDay >= 1 && pDay <= 7).toSet()
        : const {},
    holidays: vRule.isEmpty ? HolidayRule.sunday : vRule.first,
    overrides: vOverrides,
  );
}
