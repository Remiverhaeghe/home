/// Scénarios en un geste : départ, retour, télétravail du jour. Ils ne font que régler des choses
/// que Home sait déjà faire (mode vacances, calendrier) ; les règles restent dans leurs fichiers.
library;

import 'alerts.dart';
import 'boost.dart';
import 'house_calendar.dart';
import 'plan.dart';
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

/// Heure du matin où la nuit se termine : celle du planning de départ (7 h).
const nightEndMinute = 420;

/// Prochain réveil strictement après [pNow].
DateTime nightEnd(DateTime pNow) {
  final vToday = DateTime(pNow.year, pNow.month, pNow.day, 0, nightEndMinute);

  return vToday.isAfter(pNow)
      ? vToday
      : DateTime(pNow.year, pNow.month, pNow.day + 1, 0, nightEndMinute);
}

/// Une consigne de nuit par pièce, jusqu'au prochain réveil : la température « nuit » de chaque
/// pièce remplace son planning pour cette nuit seulement.
List<Boost> nightBoosts(List<Room> pRooms, DateTime pNow) => [
  for (final vRoom in pRooms)
    Boost(
      host: vRoom.acHost,
      kind: BoostKind.night,
      temp: vRoom.targets.night,
      until: nightEnd(pNow),
    ),
];

/// La nuit est-elle lancée, d'après les coups de chaud encore en cours ?
bool isNightOn(List<Boost> pBoosts, DateTime pNow) =>
    activeBoosts(pBoosts, pNow).values.any((pBoost) => pBoost.kind == BoostKind.night);

/// Durée d'une aération avant le rappel de refermer ou de renvoyer l'impulsion du Velux. Les
/// boîtiers de la maison sont des boutons sans retour d'état : Home ne sait pas si la fenêtre est
/// ouverte, il rappelle seulement le temps écoulé.
const airingMinutes = 15;

/// L'alerte de fin d'aération, une fois [pUntil] passé ; rien tant qu'aucune aération n'est lancée.
List<SensorAlert> airingAlerts(DateTime? pUntil, DateTime pNow) => [
  if (pUntil != null && !pNow.isBefore(pUntil))
    const SensorAlert(sensorName: 'Aération', kind: AlertKind.airing),
];
