import 'dart:convert';

import 'ac_units.dart';
import 'automations.dart';
import 'daikin.dart';
import 'reading.dart';

/// Température du capteur sous laquelle la maison vide est chauffée.
const defaultFrostTemp = 8.0;

/// Consigne de chauffage hors gel, aussi la température où le chauffage s'arrête.
const defaultFrostSetpoint = 12.0;

/// Absence de [from] (compris) à [until] (exclu). Pendant ce temps, les règles de confort sont
/// suspendues et la maison est seulement tenue hors gel.
class VacationMode {
  const VacationMode({
    required this.from,
    required this.until,
    this.frostTemp = defaultFrostTemp,
    this.frostSetpoint = defaultFrostSetpoint,
  });

  final DateTime from;
  final DateTime until;

  /// Le chauffage démarre quand le capteur passe sous cette température.
  final double frostTemp;

  /// Consigne du chauffage hors gel ; il s'arrête quand le capteur l'atteint.
  final double frostSetpoint;

  bool isActiveAt(DateTime pNow) => !pNow.isBefore(from) && pNow.isBefore(until);
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
  );
}

String vacationJson(VacationMode pVacation) => const JsonEncoder.withIndent('  ').convert({
  'version': vacationVersion,
  'from': pVacation.from.toIso8601String(),
  'until': pVacation.until.toIso8601String(),
  'frostTemp': pVacation.frostTemp,
  'frostSetpoint': pVacation.frostSetpoint,
});

/// Commandes à envoyer en vacances : chauffer sous [VacationMode.frostTemp], couper une fois
/// [VacationMode.frostSetpoint] atteint, ne rien faire entre les deux. Les mêmes garde-fous que
/// pour les règles : capteur relié et récent, état de la clim connu, délai entre deux commandes.
List<AutoDecision> evaluateVacation({
  required VacationMode pVacation,
  required List<AcUnit> pUnits,
  required List<Sensor> pSensors,
  required Map<String, DaikinControl> pControls,
  required DateTime pNow,
  Map<String, DateTime> pLastRuns = const {},
}) {
  final rDecisions = <AutoDecision>[];
  for (final vUnit in pUnits) {
    final vRule = AutoRule(
      name: 'Vacances',
      acHost: vUnit.host,
      metric: AutoMetric.temperature,
      side: AutoSide.below,
      threshold: pVacation.frostTemp,
      action: AutoActionKind.heat,
      setpoint: pVacation.frostSetpoint,
    );
    final vControl = pControls[vUnit.host];
    final vSensorName = vUnit.sensorName;
    if (vSensorName == null || vControl == null) {
      continue;
    }
    final vReading = pSensors.where((pSensor) => pSensor.name == vSensorName).firstOrNull?.last;
    if (vReading == null) {
      continue;
    }
    final vAge = pNow.difference(vReading.at);
    final vLast = pLastRuns[vRule.key];
    if (vAge > maxReadingAge ||
        vAge.isNegative ||
        (vLast != null && pNow.difference(vLast) < vRule.minGap)) {
      continue;
    }
    final DaikinControl? vTarget;
    if (vReading.temp < pVacation.frostTemp) {
      vTarget = vRule.targetFor(vControl);
    } else if (vReading.temp >= pVacation.frostSetpoint && vControl.power) {
      vTarget = vControl.copyWith(power: false);
    } else {
      vTarget = null;
    }
    if (vTarget != null) {
      rDecisions.add(AutoDecision(rule: vRule, control: vTarget));
    }
  }

  return rDecisions;
}

/// Ce qui doit tourner à l'instant [pNow] : le hors gel pendant l'absence, les règles sinon.
List<AutoDecision> evaluateAutomations({
  required List<AutoRule> pRules,
  required VacationMode? pVacation,
  required List<AcUnit> pUnits,
  required List<Sensor> pSensors,
  required Map<String, DaikinControl> pControls,
  required DateTime pNow,
  Map<String, DateTime> pLastRuns = const {},
}) {
  if (pVacation != null && pVacation.isActiveAt(pNow)) {
    return evaluateVacation(
      pVacation: pVacation,
      pUnits: pUnits,
      pSensors: pSensors,
      pControls: pControls,
      pNow: pNow,
      pLastRuns: pLastRuns,
    );
  }

  return evaluateRules(
    pRules: pRules,
    pUnits: pUnits,
    pSensors: pSensors,
    pControls: pControls,
    pNow: pNow,
    pLastRuns: pLastRuns,
  );
}
