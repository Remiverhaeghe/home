/// Heures de marche du poêle à pellets, relevées à chaque lecture de son état, et consommation
/// estimée à partir du débit que l'utilisateur donne.
library;

import 'dart:convert';

/// Au-delà de cet écart entre deux lectures, la marche entre les deux n'est pas comptée : on ne sait
/// pas ce que le poêle a fait.
const maxRunGap = Duration(minutes: 15);

/// Nombre de jours gardés.
const keptRunDays = 90;

/// Sac de pellets courant, en kg.
const defaultBagKg = 15.0;

String _dayKey(DateTime pAt) =>
    '${pAt.year.toString().padLeft(4, '0')}-${pAt.month.toString().padLeft(2, '0')}-'
    '${pAt.day.toString().padLeft(2, '0')}';

class PelletRuns {
  const PelletRuns({
    this.minutesByDay = const {},
    this.lastAt,
    this.lastOn = false,
    this.kgPerHour,
    this.bagKg = defaultBagKg,
    this.bagPrice,
  });

  /// Minutes de marche par jour, clé `aaaa-mm-jj`.
  final Map<String, int> minutesByDay;

  /// Dernière lecture de l'état, et si le poêle marchait alors.
  final DateTime? lastAt;
  final bool lastOn;

  /// Débit de pellets à pleine marche, en kg par heure ; null tant que l'utilisateur ne l'a pas
  /// donné : Home n'invente aucun chiffre.
  final double? kgPerHour;
  final double bagKg;

  /// Prix d'un sac en euros ; null tant que l'utilisateur ne l'a pas donné.
  final double? bagPrice;

  /// Ajoute une lecture de l'état à l'instant [pAt]. La marche entre la lecture précédente et
  /// celle-ci compte si le poêle marchait à la précédente et si l'écart reste sous [maxRunGap].
  PelletRuns record(DateTime pAt, {required bool pOn}) {
    final vLast = lastAt;
    final vMinutes = {...minutesByDay};
    if (vLast != null && lastOn && pAt.isAfter(vLast) && pAt.difference(vLast) <= maxRunGap) {
      final vKey = _dayKey(vLast);
      vMinutes[vKey] = (vMinutes[vKey] ?? 0) + pAt.difference(vLast).inMinutes;
    }
    final vOldest = _dayKey(pAt.subtract(const Duration(days: keptRunDays)));
    vMinutes.removeWhere((pKey, _) => pKey.compareTo(vOldest) < 0);

    return PelletRuns(
      minutesByDay: vMinutes,
      lastAt: pAt,
      lastOn: pOn,
      kgPerHour: kgPerHour,
      bagKg: bagKg,
      bagPrice: bagPrice,
    );
  }

  PelletRuns withFlow({
    required double? pKgPerHour,
    required double pBagKg,
    double? pBagPrice,
  }) => PelletRuns(
    minutesByDay: minutesByDay,
    lastAt: lastAt,
    lastOn: lastOn,
    kgPerHour: pKgPerHour,
    bagKg: pBagKg,
    bagPrice: pBagPrice,
  );

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

  /// Heures de marche de la semaine d'avant : les 7 jours qui précèdent les 7 derniers.
  double hoursPreviousWeek(DateTime pNow) => hoursOver(14, pNow) - hoursOver(7, pNow);

  /// Coût estimé de [pKg] de pellets, null sans prix du sac.
  double? costFor(double? pKg) => pKg == null || bagPrice == null ? null : pKg / bagKg * bagPrice!;

  /// Pellets estimés sur [pHours] heures de marche, null sans débit.
  double? kgFor(double pHours) => kgPerHour == null ? null : pHours * kgPerHour!;
}

String pelletRunsJson(PelletRuns pRuns) => jsonEncode({
  'jours': pRuns.minutesByDay,
  'dernier': pRuns.lastAt?.toIso8601String(),
  'marche': pRuns.lastOn,
  'debitKgH': pRuns.kgPerHour,
  'sacKg': pRuns.bagKg,
  'prixSac': pRuns.bagPrice,
});

/// Lit le fichier ; abîmé ou absent, il redonne un journal vide.
PelletRuns parsePelletRuns(String pJson) {
  try {
    final vRoot = jsonDecode(pJson);
    if (vRoot is! Map<String, dynamic>) {
      return const PelletRuns();
    }
    final vDays = vRoot['jours'];
    final vFlow = vRoot['debitKgH'];
    final vBag = vRoot['sacKg'];
    final vPrice = vRoot['prixSac'];

    return PelletRuns(
      minutesByDay: {
        if (vDays is Map<String, dynamic>)
          for (final vEntry in vDays.entries)
            if (vEntry.value is int) vEntry.key: vEntry.value as int,
      },
      lastAt: DateTime.tryParse('${vRoot['dernier']}'),
      lastOn: vRoot['marche'] == true,
      kgPerHour: vFlow is num && vFlow > 0 ? vFlow.toDouble() : null,
      bagKg: vBag is num && vBag > 0 ? vBag.toDouble() : defaultBagKg,
      bagPrice: vPrice is num && vPrice > 0 ? vPrice.toDouble() : null,
    );
  } on FormatException {
    return const PelletRuns();
  }
}
