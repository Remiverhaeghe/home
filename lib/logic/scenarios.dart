/// Scénarios en un geste : départ, retour, télétravail du jour. Ils ne font que régler des choses
/// que Home sait déjà faire (mode vacances, calendrier) ; les règles restent dans leurs fichiers.
library;

import 'house_calendar.dart';
import 'vacation.dart';

DateTime _dayOf(DateTime pAt) => DateTime(pAt.year, pAt.month, pAt.day);

/// Absence qui commence aujourd'hui et dure jusqu'au matin du jour de retour [pReturnDay]. Null
/// quand ce jour n'est pas après [pNow] : il n'y a rien à programmer.
VacationMode? departure(DateTime pNow, DateTime pReturnDay) {
  final vUntil = _dayOf(pReturnDay);
  if (!vUntil.isAfter(pNow)) {
    return null;
  }

  return VacationMode(from: _dayOf(pNow), until: vUntil);
}

/// Aujourd'hui est-il un jour de télétravail, par le calendrier ou par décision du jour ?
bool isRemoteToday(HouseCalendar pCalendar, DateTime pNow) =>
    pCalendar.kindOf(pNow) == DayKind.remote;

/// Bascule le télétravail d'aujourd'hui : un jour de télétravail devient un jour normal, un autre
/// devient un jour de télétravail. Seule la date du jour est touchée.
HouseCalendar toggleRemoteToday(HouseCalendar pCalendar, DateTime pNow) => pCalendar.copyWith(
  overrides: {
    ...pCalendar.overrides,
    _dayOf(pNow): isRemoteToday(pCalendar, pNow) ? DayOverride.normal : DayOverride.remote,
  },
);
