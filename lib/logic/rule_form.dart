import 'automations.dart';
import 'daikin.dart';

/// Ce qui empêche d'enregistrer une règle saisie à l'écran.
enum RuleProblem { noThreshold, thresholdOutOfRange, badSetpoint }

/// Règle construite, ou le motif du refus.
class RuleBuild {
  const RuleBuild.ok(AutoRule this.rule) : problem = null;

  const RuleBuild.refused(RuleProblem this.problem) : rule = null;

  final AutoRule? rule;
  final RuleProblem? problem;
}

/// Nombre saisi à la main, avec une virgule ou un point. Null s'il est vide ou illisible.
double? parseNumber(String pText) => double.tryParse(pText.trim().replaceAll(',', '.'));

/// Règle d'après les champs de l'écran. Le seuil doit rester dans ce que le capteur peut mesurer
/// (0 à 100 % d'humidité, -30 à 60 °C). La consigne ne compte que pour froid, chaud et auto ; vide,
/// la clim garde la sienne. Le nom vide devient « Humidité > 70 », et un nom déjà pris par une
/// règle de la même clim reçoit un numéro.
RuleBuild buildRule({
  required String pName,
  required String pAcHost,
  required AutoMetric pMetric,
  required AutoSide pSide,
  required String pThreshold,
  required AutoActionKind pAction,
  required String pSetpoint,
  required List<AutoRule> pExisting,
}) {
  final vThreshold = parseNumber(pThreshold);
  if (vThreshold == null) {
    return const RuleBuild.refused(RuleProblem.noThreshold);
  }
  final vRange = pMetric == AutoMetric.humidity ? (0.0, 100.0) : (-30.0, 60.0);
  if (vThreshold < vRange.$1 || vThreshold > vRange.$2) {
    return const RuleBuild.refused(RuleProblem.thresholdOutOfRange);
  }
  double? vSetpoint;
  if (pAction != AutoActionKind.powerOff && pSetpoint.trim().isNotEmpty) {
    vSetpoint = parseNumber(pSetpoint);
    if (vSetpoint == null || vSetpoint < daikinMinSetpoint || vSetpoint > daikinMaxSetpoint) {
      return const RuleBuild.refused(RuleProblem.badSetpoint);
    }
  }
  final vSign = pSide == AutoSide.above ? '>' : '<';
  final vLabel = pMetric == AutoMetric.humidity ? 'Humidité' : 'Température';
  final vBase = pName.trim().isEmpty ? '$vLabel $vSign ${_short(vThreshold)}' : pName.trim();
  final vTaken = {
    for (final vRule in pExisting)
      if (vRule.acHost == pAcHost) vRule.name,
  };
  var vName = vBase;
  for (var vNumber = 2; vTaken.contains(vName); vNumber++) {
    vName = '$vBase ($vNumber)';
  }

  return RuleBuild.ok(
    AutoRule(
      name: vName,
      acHost: pAcHost,
      metric: pMetric,
      side: pSide,
      threshold: vThreshold,
      action: pAction,
      setpoint: vSetpoint,
    ),
  );
}

String _short(double pValue) =>
    pValue == pValue.roundToDouble() ? pValue.toStringAsFixed(0) : pValue.toString();
