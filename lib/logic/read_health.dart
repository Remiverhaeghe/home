/// Santé du relevé en arrière-plan : pour chaque capteur suivi, les tours réussis et manqués par
/// jour, la série de tours manqués d'affilée et l'heure du dernier relevé. Le service l'écrit, l'écran
/// la lit : de quoi voir si un capteur « muet » l'est depuis longtemps ou par accès.
library;

import 'dart:convert';

/// Jours gardés dans le fichier.
const keptHealthDays = 14;

String _dayKey(DateTime pAt) =>
    '${pAt.year.toString().padLeft(4, '0')}-${pAt.month.toString().padLeft(2, '0')}-'
    '${pAt.day.toString().padLeft(2, '0')}';

/// Tours d'une journée : réussis et manqués.
class DayCount {
  const DayCount({this.ok = 0, this.missed = 0});

  final int ok;
  final int missed;

  int get total => ok + missed;
}

class SensorHealth {
  const SensorHealth({this.lastOk, this.lastTry, this.streak = 0, this.days = const {}});

  /// Dernier tour réussi et dernier tour tenté.
  final DateTime? lastOk;
  final DateTime? lastTry;

  /// Tours manqués d'affilée, zéro après un tour réussi.
  final int streak;

  /// Tours par jour, clé `aaaa-mm-jj`.
  final Map<String, DayCount> days;

  SensorHealth record(DateTime pAt, {required bool pOk}) {
    final vKey = _dayKey(pAt);
    final vBefore = days[vKey] ?? const DayCount();
    final vDays = {
      ...days,
      vKey: DayCount(ok: vBefore.ok + (pOk ? 1 : 0), missed: vBefore.missed + (pOk ? 0 : 1)),
    };
    final vOldest = _dayKey(pAt.subtract(const Duration(days: keptHealthDays)));
    vDays.removeWhere((pDay, _) => pDay.compareTo(vOldest) < 0);

    return SensorHealth(
      lastOk: pOk ? pAt : lastOk,
      lastTry: pAt,
      streak: pOk ? 0 : streak + 1,
      days: vDays,
    );
  }

  /// Tours d'aujourd'hui.
  DayCount today(DateTime pNow) => days[_dayKey(pNow)] ?? const DayCount();

  /// Part des tours réussis sur les [pDays] derniers jours, aujourd'hui compris ; null sans tour.
  double? rateOver(int pDays, DateTime pNow) {
    final vFrom = _dayKey(DateTime(pNow.year, pNow.month, pNow.day - (pDays - 1)));
    var vOk = 0;
    var vTotal = 0;
    for (final vEntry in days.entries) {
      if (vEntry.key.compareTo(vFrom) >= 0) {
        vOk += vEntry.value.ok;
        vTotal += vEntry.value.total;
      }
    }

    return vTotal == 0 ? null : vOk / vTotal;
  }
}

class ReadHealth {
  const ReadHealth([this.sensors = const {}]);

  /// Santé de chaque capteur suivi, par nom.
  final Map<String, SensorHealth> sensors;

  SensorHealth of(String pName) => sensors[pName] ?? const SensorHealth();

  ReadHealth record(String pName, DateTime pAt, {required bool pOk}) =>
      ReadHealth({...sensors, pName: of(pName).record(pAt, pOk: pOk)});
}

String readHealthJson(ReadHealth pHealth) => jsonEncode({
  'version': 1,
  'capteurs': {
    for (final vEntry in pHealth.sensors.entries)
      vEntry.key: {
        'dernierOk': vEntry.value.lastOk?.toIso8601String(),
        'dernierEssai': vEntry.value.lastTry?.toIso8601String(),
        'serie': vEntry.value.streak,
        'jours': {
          for (final vDay in vEntry.value.days.entries)
            vDay.key: [vDay.value.ok, vDay.value.missed],
        },
      },
  },
});

/// Relit le fichier ; absent, abîmé ou d'une autre version, il redonne une santé vide.
ReadHealth parseReadHealth(String pJson) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pJson);
  } on FormatException {
    return const ReadHealth();
  }
  if (vRoot is! Map<String, dynamic> || vRoot['version'] != 1) {
    return const ReadHealth();
  }
  final vRaw = vRoot['capteurs'];
  if (vRaw is! Map<String, dynamic>) {
    return const ReadHealth();
  }
  final vSensors = <String, SensorHealth>{};
  for (final vEntry in vRaw.entries) {
    final vValue = vEntry.value;
    if (vValue is! Map<String, dynamic>) {
      continue;
    }
    final vDays = <String, DayCount>{};
    final vRawDays = vValue['jours'];
    if (vRawDays is Map<String, dynamic>) {
      for (final vDay in vRawDays.entries) {
        final vCounts = vDay.value;
        if (vCounts is List && vCounts.length == 2 && vCounts[0] is int && vCounts[1] is int) {
          vDays[vDay.key] = DayCount(ok: vCounts[0] as int, missed: vCounts[1] as int);
        }
      }
    }
    final vStreak = vValue['serie'];
    vSensors[vEntry.key] = SensorHealth(
      lastOk: DateTime.tryParse('${vValue['dernierOk']}'),
      lastTry: DateTime.tryParse('${vValue['dernierEssai']}'),
      streak: vStreak is int && vStreak >= 0 ? vStreak : 0,
      days: vDays,
    );
  }

  return ReadHealth(vSensors);
}

/// Intervalles proposés entre deux relevés en arrière-plan, en minutes. Le service se réveille
/// toutes les 5 minutes : il saute les tours qui tombent avant l'intervalle choisi. Au-delà de
/// 30 minutes, un seul tour manqué ferait annoncer un capteur muet (une heure sans relevé).
const readIntervalChoices = [5, 10, 15, 30];
const defaultReadInterval = 5;

/// Le tour de relevé doit-il avoir lieu ? Une marge de 30 secondes absorbe le retard du réveil.
bool readRoundDue(DateTime pNow, DateTime? pLastRound, int pMinutes) =>
    pLastRound == null ||
    pNow.difference(pLastRound) >= Duration(minutes: pMinutes) - const Duration(seconds: 30);
