/// Heures de marche des climatisations, consommation estimée avec la puissance donnée par
/// l'utilisateur, coût avec son prix du kWh et suivi d'un budget mensuel. Home n'invente aucun
/// chiffre : sans puissance ni prix, il ne montre que les heures.
library;

import 'dart:convert';

import 'pellet_runs.dart' show keptRunDays, maxRunGap;

String _dayKey(DateTime pAt) =>
    '${pAt.year.toString().padLeft(4, '0')}-${pAt.month.toString().padLeft(2, '0')}-'
    '${pAt.day.toString().padLeft(2, '0')}';

/// Part de la dépense de chauffage qu'un degré de consigne en moins fait économiser : repère
/// courant de l'ADEME, une estimation et non une mesure.
const degreeSavingShare = 0.07;

/// Au-delà de cette part du budget dépensée, on le dit.
const budgetWarnShare = 0.8;

/// Heures de marche d'un appareil : minutes par jour, relevées à chaque lecture de son état.
class RunLog {
  const RunLog({this.minutesByDay = const {}, this.lastAt, this.lastOn = false});

  /// Minutes de marche par jour, clé `aaaa-mm-jj`.
  final Map<String, int> minutesByDay;
  final DateTime? lastAt;
  final bool lastOn;

  /// Ajoute une lecture à l'instant [pAt]. La marche entre la lecture précédente et celle-ci compte
  /// si l'appareil marchait à la précédente et si l'écart reste sous [maxRunGap].
  RunLog record(DateTime pAt, {required bool pOn}) {
    final vLast = lastAt;
    final vMinutes = {...minutesByDay};
    if (vLast != null && lastOn && pAt.isAfter(vLast) && pAt.difference(vLast) <= maxRunGap) {
      final vKey = _dayKey(vLast);
      vMinutes[vKey] = (vMinutes[vKey] ?? 0) + pAt.difference(vLast).inMinutes;
    }
    final vOldest = _dayKey(pAt.subtract(const Duration(days: keptRunDays)));
    vMinutes.removeWhere((pKey, _) => pKey.compareTo(vOldest) < 0);

    return RunLog(minutesByDay: vMinutes, lastAt: pAt, lastOn: pOn);
  }

  /// Heures de marche sur les [pDays] derniers jours, aujourd'hui compris.
  double hoursOver(int pDays, DateTime pNow) {
    final vFrom = _dayKey(DateTime(pNow.year, pNow.month, pNow.day - (pDays - 1)));
    var vTotal = 0;
    for (final vEntry in minutesByDay.entries) {
      if (vEntry.key.compareTo(vFrom) >= 0) {
        vTotal += vEntry.value;
      }
    }

    return vTotal / 60;
  }

  /// Heures de la semaine d'avant : les 7 jours qui précèdent les 7 derniers.
  double hoursPreviousWeek(DateTime pNow) => hoursOver(14, pNow) - hoursOver(7, pNow);

  Map<String, dynamic> toJson() => {
    'jours': minutesByDay,
    'dernier': lastAt?.toIso8601String(),
    'marche': lastOn,
  };

  static RunLog fromJson(Object? pJson) {
    if (pJson is! Map<String, dynamic>) {
      return const RunLog();
    }
    final vDays = pJson['jours'];

    return RunLog(
      minutesByDay: {
        if (vDays is Map<String, dynamic>)
          for (final vEntry in vDays.entries)
            if (vEntry.value is int) vEntry.key: vEntry.value as int,
      },
      lastAt: DateTime.tryParse('${pJson['dernier']}'),
      lastOn: pJson['marche'] == true,
    );
  }
}

/// Heures de marche de chaque climatisation (par adresse) et réglages de coût.
class AcRuns {
  const AcRuns({
    this.logs = const {},
    this.kwByHost = const {},
    this.pricePerKwh,
    this.monthlyBudget,
  });

  final Map<String, RunLog> logs;

  /// Puissance électrique moyenne en marche, en kW, donnée par l'utilisateur pour chaque clim.
  final Map<String, double> kwByHost;

  /// Prix du kWh en euros, null tant que l'utilisateur ne l'a pas donné.
  final double? pricePerKwh;

  /// Budget mensuel de chauffage en euros, null sans budget.
  final double? monthlyBudget;

  RunLog logOf(String pHost) => logs[pHost] ?? const RunLog();

  /// Range une lecture de l'état de la clim [pHost].
  AcRuns record(String pHost, DateTime pAt, {required bool pOn}) => AcRuns(
    logs: {...logs, pHost: logOf(pHost).record(pAt, pOn: pOn)},
    kwByHost: kwByHost,
    pricePerKwh: pricePerKwh,
    monthlyBudget: monthlyBudget,
  );

  AcRuns withSettings({
    required Map<String, double> pKwByHost,
    required double? pPricePerKwh,
    required double? pMonthlyBudget,
  }) => AcRuns(
    logs: logs,
    kwByHost: pKwByHost,
    pricePerKwh: pPricePerKwh,
    monthlyBudget: pMonthlyBudget,
  );

  /// Énergie estimée de la clim [pHost] sur [pDays] jours, null sans puissance donnée.
  double? kwhOver(String pHost, int pDays, DateTime pNow) {
    final vKw = kwByHost[pHost];

    return vKw == null ? null : logOf(pHost).hoursOver(pDays, pNow) * vKw;
  }

  /// Coût d'une énergie en euros, null sans prix du kWh.
  double? costOf(double? pKwh) => pKwh == null || pricePerKwh == null ? null : pKwh * pricePerKwh!;

  /// Coût de toutes les clims sur [pDays] jours, null s'il manque une puissance ou le prix.
  double? totalCost(Iterable<String> pHosts, int pDays, DateTime pNow) {
    var vTotal = 0.0;
    for (final vHost in pHosts) {
      final vCost = costOf(kwhOver(vHost, pDays, pNow));
      if (vCost == null) {
        return null;
      }
      vTotal += vCost;
    }

    return vTotal;
  }
}

/// Où en est le budget : dans les clous, bientôt atteint ou dépassé.
enum BudgetState { ok, near, over }

BudgetState budgetState(double pSpent, double pBudget) => pSpent > pBudget
    ? BudgetState.over
    : pSpent >= pBudget * budgetWarnShare
    ? BudgetState.near
    : BudgetState.ok;

/// Économie estimée d'un degré de consigne en moins sur une dépense.
double degreeSaving(double pSpent) => pSpent * degreeSavingShare;

String acRunsJson(AcRuns pRuns) => jsonEncode({
  'version': 1,
  'clims': {for (final vEntry in pRuns.logs.entries) vEntry.key: vEntry.value.toJson()},
  'kw': pRuns.kwByHost,
  'prixKwh': pRuns.pricePerKwh,
  'budgetMensuel': pRuns.monthlyBudget,
});

/// Lit le fichier ; absent ou abîmé, il redonne un journal vide.
AcRuns parseAcRuns(String pJson) {
  try {
    final vRoot = jsonDecode(pJson);
    if (vRoot is! Map<String, dynamic>) {
      return const AcRuns();
    }
    final vLogs = vRoot['clims'];
    final vKw = vRoot['kw'];
    final vPrice = vRoot['prixKwh'];
    final vBudget = vRoot['budgetMensuel'];

    return AcRuns(
      logs: {
        if (vLogs is Map<String, dynamic>)
          for (final vEntry in vLogs.entries) vEntry.key: RunLog.fromJson(vEntry.value),
      },
      kwByHost: {
        if (vKw is Map<String, dynamic>)
          for (final vEntry in vKw.entries)
            if (vEntry.value is num && (vEntry.value as num) > 0)
              vEntry.key: (vEntry.value as num).toDouble(),
      },
      pricePerKwh: vPrice is num && vPrice > 0 ? vPrice.toDouble() : null,
      monthlyBudget: vBudget is num && vBudget > 0 ? vBudget.toDouble() : null,
    );
  } on FormatException {
    return const AcRuns();
  }
}
