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

/// Plage d'heures creuses : de [startHour] (comprise) à [endHour] (exclue), qui peut passer minuit.
class OffPeak {
  const OffPeak({required this.startHour, required this.endHour});

  final int startHour;
  final int endHour;

  /// Deux heures de la journée et une plage qui n'est pas vide.
  bool get isValid =>
      startHour >= 0 && startHour <= 23 && endHour >= 0 && endHour <= 23 && startHour != endHour;

  bool contains(DateTime pAt) => startHour < endHour
      ? pAt.hour >= startHour && pAt.hour < endHour
      : pAt.hour >= startHour || pAt.hour < endHour;
}

/// Heures de marche d'un appareil : minutes par jour, relevées à chaque lecture de son état.
class RunLog {
  const RunLog({
    this.minutesByDay = const {},
    this.offPeakByDay = const {},
    this.lastAt,
    this.lastOn = false,
  });

  /// Minutes de marche par jour, clé `aaaa-mm-jj`.
  final Map<String, int> minutesByDay;

  /// Parmi elles, les minutes tombées en heures creuses (seulement quand la plage était donnée).
  final Map<String, int> offPeakByDay;
  final DateTime? lastAt;
  final bool lastOn;

  /// Ajoute une lecture à l'instant [pAt]. La marche entre la lecture précédente et celle-ci compte
  /// si l'appareil marchait à la précédente et si l'écart reste sous [maxRunGap].
  RunLog record(DateTime pAt, {required bool pOn, OffPeak? pOffPeak}) {
    final vLast = lastAt;
    final vMinutes = {...minutesByDay};
    final vOffPeak = {...offPeakByDay};
    if (vLast != null && lastOn && pAt.isAfter(vLast) && pAt.difference(vLast) <= maxRunGap) {
      final vKey = _dayKey(vLast);
      final vSpan = pAt.difference(vLast).inMinutes;
      vMinutes[vKey] = (vMinutes[vKey] ?? 0) + vSpan;
      if (pOffPeak != null && pOffPeak.isValid) {
        var vCheap = 0;
        for (var vMinute = 0; vMinute < vSpan; vMinute++) {
          if (pOffPeak.contains(vLast.add(Duration(minutes: vMinute)))) {
            vCheap++;
          }
        }
        vOffPeak[vKey] = (vOffPeak[vKey] ?? 0) + vCheap;
      }
    }
    final vOldest = _dayKey(pAt.subtract(const Duration(days: keptRunDays)));
    vMinutes.removeWhere((pKey, _) => pKey.compareTo(vOldest) < 0);
    vOffPeak.removeWhere((pKey, _) => pKey.compareTo(vOldest) < 0);

    return RunLog(minutesByDay: vMinutes, offPeakByDay: vOffPeak, lastAt: pAt, lastOn: pOn);
  }

  /// Heures de marche sur les [pDays] derniers jours, aujourd'hui compris.
  double hoursOver(int pDays, DateTime pNow) => _sumOver(minutesByDay, pDays, pNow) / 60;

  /// Heures de marche en heures creuses sur les [pDays] derniers jours.
  double offPeakHoursOver(int pDays, DateTime pNow) => _sumOver(offPeakByDay, pDays, pNow) / 60;

  static int _sumOver(Map<String, int> pByDay, int pDays, DateTime pNow) {
    final vFrom = _dayKey(DateTime(pNow.year, pNow.month, pNow.day - (pDays - 1)));
    var vTotal = 0;
    for (final vEntry in pByDay.entries) {
      if (vEntry.key.compareTo(vFrom) >= 0) {
        vTotal += vEntry.value;
      }
    }

    return vTotal;
  }

  /// Heures de la semaine d'avant : les 7 jours qui précèdent les 7 derniers.
  double hoursPreviousWeek(DateTime pNow) => hoursOver(14, pNow) - hoursOver(7, pNow);

  Map<String, dynamic> toJson() => {
    'jours': minutesByDay,
    if (offPeakByDay.isNotEmpty) 'creuses': offPeakByDay,
    'dernier': lastAt?.toIso8601String(),
    'marche': lastOn,
  };

  static RunLog fromJson(Object? pJson) {
    if (pJson is! Map<String, dynamic>) {
      return const RunLog();
    }
    Map<String, int> days(Object? pRaw) => {
      if (pRaw is Map<String, dynamic>)
        for (final vEntry in pRaw.entries)
          if (vEntry.value is int) vEntry.key: vEntry.value as int,
    };

    return RunLog(
      minutesByDay: days(pJson['jours']),
      offPeakByDay: days(pJson['creuses']),
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
    this.offPeak,
    this.offPeakPrice,
  });

  final Map<String, RunLog> logs;

  /// Puissance électrique moyenne en marche, en kW, donnée par l'utilisateur pour chaque clim.
  final Map<String, double> kwByHost;

  /// Prix du kWh en euros, null tant que l'utilisateur ne l'a pas donné.
  final double? pricePerKwh;

  /// Budget mensuel de chauffage en euros, null sans budget.
  final double? monthlyBudget;

  /// Plage d'heures creuses et prix du kWh dans cette plage, null tant que l'utilisateur ne les a
  /// pas donnés : sans eux, tout compte au prix du kWh normal.
  final OffPeak? offPeak;
  final double? offPeakPrice;

  RunLog logOf(String pHost) => logs[pHost] ?? const RunLog();

  /// Range une lecture de l'état de la clim [pHost].
  AcRuns record(String pHost, DateTime pAt, {required bool pOn}) => AcRuns(
    logs: {
      ...logs,
      pHost: logOf(pHost).record(pAt, pOn: pOn, pOffPeak: offPeak),
    },
    kwByHost: kwByHost,
    pricePerKwh: pricePerKwh,
    monthlyBudget: monthlyBudget,
    offPeak: offPeak,
    offPeakPrice: offPeakPrice,
  );

  AcRuns withSettings({
    required Map<String, double> pKwByHost,
    required double? pPricePerKwh,
    required double? pMonthlyBudget,
    OffPeak? pOffPeak,
    double? pOffPeakPrice,
  }) => AcRuns(
    logs: logs,
    kwByHost: pKwByHost,
    pricePerKwh: pPricePerKwh,
    monthlyBudget: pMonthlyBudget,
    offPeak: pOffPeak != null && pOffPeak.isValid ? pOffPeak : null,
    offPeakPrice: pOffPeakPrice,
  );

  /// Énergie estimée de la clim [pHost] sur [pDays] jours, null sans puissance donnée.
  double? kwhOver(String pHost, int pDays, DateTime pNow) {
    final vKw = kwByHost[pHost];

    return vKw == null ? null : logOf(pHost).hoursOver(pDays, pNow) * vKw;
  }

  /// Coût de la clim [pHost] sur [pDays] jours : les heures creuses au prix donné pour elles quand
  /// la plage et ce prix existent, tout le reste au prix normal. Null sans puissance ni prix.
  double? costOver(String pHost, int pDays, DateTime pNow) {
    final vKw = kwByHost[pHost];
    final vPrice = pricePerKwh;
    if (vKw == null || vPrice == null) {
      return null;
    }
    final vLog = logOf(pHost);
    final vTotal = vLog.hoursOver(pDays, pNow);
    final vCheapPrice = offPeakPrice;
    if (offPeak == null || vCheapPrice == null) {
      return vTotal * vKw * vPrice;
    }
    final vCheap = vLog.offPeakHoursOver(pDays, pNow);

    return vKw * ((vTotal - vCheap) * vPrice + vCheap * vCheapPrice);
  }

  /// Coût d'une énergie en euros, null sans prix du kWh.
  double? costOf(double? pKwh) => pKwh == null || pricePerKwh == null ? null : pKwh * pricePerKwh!;

  /// Coût de toutes les clims sur [pDays] jours, null s'il manque une puissance ou le prix.
  double? totalCost(Iterable<String> pHosts, int pDays, DateTime pNow) {
    var vTotal = 0.0;
    for (final vHost in pHosts) {
      final vCost = costOver(vHost, pDays, pNow);
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
  if (pRuns.offPeak != null)
    'creuses': {'debut': pRuns.offPeak!.startHour, 'fin': pRuns.offPeak!.endHour},
  if (pRuns.offPeakPrice != null) 'prixCreuxKwh': pRuns.offPeakPrice,
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
    final vCheap = vRoot['creuses'];
    final vCheapPrice = vRoot['prixCreuxKwh'];
    final vWindow = vCheap is Map<String, dynamic> && vCheap['debut'] is int && vCheap['fin'] is int
        ? OffPeak(startHour: vCheap['debut'] as int, endHour: vCheap['fin'] as int)
        : null;

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
      offPeak: vWindow != null && vWindow.isValid ? vWindow : null,
      offPeakPrice: vCheapPrice is num && vCheapPrice > 0 ? vCheapPrice.toDouble() : null,
    );
  } on FormatException {
    return const AcRuns();
  }
}
