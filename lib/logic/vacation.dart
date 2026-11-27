import 'dart:convert';

import 'daikin.dart';

/// Température du capteur sous laquelle la maison vide est chauffée.
const defaultFrostTemp = 8.0;

/// Consigne de chauffage hors gel, aussi la température où le chauffage s'arrête.
const defaultFrostSetpoint = 12.0;

/// Délai de remontée en température avant le retour.
const defaultPreheat = Duration(hours: 24);

/// Absence de [from] (compris) à [until] (exclu). Pendant ce temps, les règles de confort sont
/// suspendues et la maison est seulement tenue hors gel.
class VacationMode {
  const VacationMode({
    required this.from,
    required this.until,
    this.frostTemp = defaultFrostTemp,
    this.frostSetpoint = defaultFrostSetpoint,
    this.preheat = defaultPreheat,
  });

  final DateTime from;
  final DateTime until;

  /// Le chauffage démarre quand le capteur passe sous cette température.
  final double frostTemp;

  /// Consigne du chauffage hors gel ; il s'arrête quand le capteur l'atteint.
  final double frostSetpoint;

  /// Avant la fin de l'absence, la maison remonte à la température souhaitée pour le retour.
  final Duration preheat;

  bool isActiveAt(DateTime pNow) => !pNow.isBefore(from) && pNow.isBefore(until);

  /// Vrai pendant l'absence, une fois entré dans le délai de remontée avant le retour.
  bool isPreheatingAt(DateTime pNow) => isActiveAt(pNow) && !pNow.isBefore(until.subtract(preheat));
}

/// Version du fichier `vacances.json`.
const vacationVersion = 1;

/// Fichier du mode vacances, null quand il est absent, illisible, d'une autre version, aux dates
/// incohérentes ou aux températures qui ne laissent pas de marge au chauffage.
VacationMode? parseVacation(String pJson) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pJson);
  } on FormatException {
    return null;
  }
  if (vRoot is! Map<String, dynamic> || vRoot['version'] != vacationVersion) {
    return null;
  }
  final vFrom = DateTime.tryParse('${vRoot['from']}');
  final vUntil = DateTime.tryParse('${vRoot['until']}');
  final vFrost = vRoot['frostTemp'];
  final vSetpoint = vRoot['frostSetpoint'];
  final vPreheat = vRoot['preheatHours'];
  final vFrostTemp = vFrost is num ? vFrost.toDouble() : defaultFrostTemp;
  final vFrostSetpoint = vSetpoint is num ? vSetpoint.toDouble() : defaultFrostSetpoint;
  if (vFrom == null || vUntil == null || !vUntil.isAfter(vFrom) || vFrostSetpoint <= vFrostTemp) {
    return null;
  }

  return VacationMode(
    from: vFrom,
    until: vUntil,
    frostTemp: vFrostTemp,
    frostSetpoint: vFrostSetpoint,
    preheat: vPreheat is int && vPreheat >= 0 ? Duration(hours: vPreheat) : defaultPreheat,
  );
}

String vacationJson(VacationMode pVacation) => const JsonEncoder.withIndent('  ').convert({
  'version': vacationVersion,
  'from': pVacation.from.toIso8601String(),
  'until': pVacation.until.toIso8601String(),
  'frostTemp': pVacation.frostTemp,
  'frostSetpoint': pVacation.frostSetpoint,
  'preheatHours': pVacation.preheat.inHours,
});

/// Réglages hors gel pour une pièce à [pTemp] : chauffer sous [VacationMode.frostTemp], couper une
/// fois [VacationMode.frostSetpoint] atteint, ne rien faire entre les deux. Null quand il n'y a
/// rien à envoyer.
DaikinControl? frostControl(VacationMode pVacation, double pTemp, DaikinControl pControl) {
  if (pTemp < pVacation.frostTemp) {
    final vHeat = pControl.withMode(DaikinMode.heat)?.withSetpoint(pVacation.frostSetpoint);
    final vOn = vHeat?.copyWith(power: true);

    return vOn == null || vOn.toQuery() == pControl.toQuery() ? null : vOn;
  }
  if (pTemp >= pVacation.frostSetpoint && pControl.power) {
    return pControl.copyWith(power: false);
  }

  return null;
}
