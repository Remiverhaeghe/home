import 'dart:convert';

import 'ac_units.dart';
import 'daikin.dart';
import 'reading.dart';

/// Mesure du capteur surveillée par une règle.
enum AutoMetric { humidity, temperature }

/// Sens du dépassement : au-dessus ou au-dessous du seuil.
enum AutoSide { above, below }

/// Ce que fait la règle sur la climatisation. Le mode sec n'est pas commandé par Home.
enum AutoActionKind { powerOff, cool, heat, auto }

/// Délai minimal entre deux déclenchements d'une même règle, pour ne pas lutter contre quelqu'un
/// qui règle la clim à la main.
const defaultMinGap = Duration(minutes: 30);

/// Au-delà, le dernier relevé du capteur est jugé trop vieux pour décider.
const maxReadingAge = Duration(minutes: 20);

/// Une règle : quand la mesure du capteur de la pièce passe le seuil, la clim reçoit l'action.
class AutoRule {
  const AutoRule({
    required this.name,
    required this.acHost,
    required this.metric,
    required this.side,
    required this.threshold,
    required this.action,
    this.setpoint,
    this.minGap = defaultMinGap,
  });

  final String name;

  /// Adresse de la climatisation, la même que dans [AcUnit.host].
  final String acHost;
  final AutoMetric metric;
  final AutoSide side;
  final double threshold;
  final AutoActionKind action;

  /// Consigne en °C pour le froid, le chaud et l'automatique. Sans valeur, celle de l'appareil.
  final double? setpoint;
  final Duration minGap;

  /// Clé qui range le dernier déclenchement de la règle.
  String get key => '$acHost|$name';

  /// Vrai quand la mesure [pReading] est du mauvais côté du seuil.
  bool isMet(Reading pReading) {
    final vValue = metric == AutoMetric.humidity ? pReading.humidity : pReading.temp;

    return side == AutoSide.above ? vValue > threshold : vValue < threshold;
  }

  /// Réglages à envoyer pour appliquer l'action, null quand l'appareil est déjà dans cet état.
  DaikinControl? targetFor(DaikinControl pCurrent) {
    DaikinControl? vTarget;
    if (action == AutoActionKind.powerOff) {
      vTarget = pCurrent.power ? pCurrent.copyWith(power: false) : null;
    } else {
      final vMode = switch (action) {
        AutoActionKind.cool => DaikinMode.cool,
        AutoActionKind.heat => DaikinMode.heat,
        _ => DaikinMode.auto,
      };
      final vWithMode = pCurrent.withMode(vMode)?.copyWith(power: true);
      final vDegrees = setpoint;
      vTarget = vDegrees == null ? vWithMode : (vWithMode?.withSetpoint(vDegrees) ?? vWithMode);
    }
    if (vTarget == null || vTarget.toQuery() == pCurrent.toQuery()) {
      return null;
    }

    return vTarget;
  }
}

/// Une commande décidée : la règle qui la déclenche et les réglages à envoyer.
class AutoDecision {
  const AutoDecision({required this.rule, required this.control});

  final AutoRule rule;
  final DaikinControl control;
}

/// Règles à déclencher à l'instant [pNow]. Une règle est ignorée quand sa clim n'est pas reliée à un
/// capteur, quand le capteur n'a pas de relevé récent, quand l'état de la clim est inconnu, quand
/// elle a déjà tourné depuis moins de [AutoRule.minGap] ou quand la clim est déjà réglée ainsi.
List<AutoDecision> evaluateRules({
  required List<AutoRule> pRules,
  required List<AcUnit> pUnits,
  required List<Sensor> pSensors,
  required Map<String, DaikinControl> pControls,
  required DateTime pNow,
  Map<String, DateTime> pLastRuns = const {},
}) {
  final rDecisions = <AutoDecision>[];
  for (final vRule in pRules) {
    final vUnit = pUnits.where((pUnit) => pUnit.host == vRule.acHost).firstOrNull;
    final vSensorName = vUnit?.sensorName;
    final vControl = pControls[vRule.acHost];
    if (vSensorName == null || vControl == null) {
      continue;
    }
    final vReading = pSensors.where((pSensor) => pSensor.name == vSensorName).firstOrNull?.last;
    if (vReading == null) {
      continue;
    }
    final vAge = pNow.difference(vReading.at);
    if (vAge > maxReadingAge || vAge.isNegative) {
      continue;
    }
    final vLast = pLastRuns[vRule.key];
    if (vLast != null && pNow.difference(vLast) < vRule.minGap) {
      continue;
    }
    if (!vRule.isMet(vReading)) {
      continue;
    }
    final vTarget = vRule.targetFor(vControl);
    if (vTarget != null) {
      rDecisions.add(AutoDecision(rule: vRule, control: vTarget));
    }
  }

  return rDecisions;
}

/// Version du fichier `automatismes.json`.
const autoRulesVersion = 1;

/// Fichier des règles. Une règle incomplète ou au seuil absurde est ignorée.
List<AutoRule> parseAutoRules(String pJson) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pJson);
  } on FormatException {
    return [];
  }
  if (vRoot is! Map<String, dynamic> || vRoot['version'] != autoRulesVersion) {
    return [];
  }
  final vList = vRoot['rules'];
  final rRules = <AutoRule>[];
  if (vList is List) {
    for (final vEntry in vList) {
      final vRule = vEntry is Map<String, dynamic> ? _parseRule(vEntry) : null;
      if (vRule != null) {
        rRules.add(vRule);
      }
    }
  }

  return rRules;
}

AutoRule? _parseRule(Map<String, dynamic> pEntry) {
  final vName = pEntry['name'];
  final vHost = pEntry['ac'];
  final vThreshold = pEntry['threshold'];
  final vMetric = AutoMetric.values.asNameMap()[pEntry['metric']];
  final vSide = AutoSide.values.asNameMap()[pEntry['side']];
  final vAction = AutoActionKind.values.asNameMap()[pEntry['action']];
  if (vName is! String ||
      vName.trim().isEmpty ||
      vHost is! String ||
      vHost.isEmpty ||
      vThreshold is! num ||
      vMetric == null ||
      vSide == null ||
      vAction == null) {
    return null;
  }
  final vSetpoint = pEntry['setpoint'];
  final vGap = pEntry['minGapMinutes'];

  return AutoRule(
    name: vName,
    acHost: vHost,
    metric: vMetric,
    side: vSide,
    threshold: vThreshold.toDouble(),
    action: vAction,
    setpoint: vSetpoint is num ? vSetpoint.toDouble() : null,
    minGap: vGap is int && vGap >= 0 ? Duration(minutes: vGap) : defaultMinGap,
  );
}

String autoRulesJson(List<AutoRule> pRules) => const JsonEncoder.withIndent('  ').convert({
  'version': autoRulesVersion,
  'rules': [
    for (final vRule in pRules)
      {
        'name': vRule.name,
        'ac': vRule.acHost,
        'metric': vRule.metric.name,
        'side': vRule.side.name,
        'threshold': vRule.threshold,
        'action': vRule.action.name,
        if (vRule.setpoint != null) 'setpoint': vRule.setpoint,
        'minGapMinutes': vRule.minGap.inMinutes,
      },
  ],
});
