/// Heures de marche du poêle à pellets, relevées à chaque lecture de son état, et consommation
/// estimée à partir du débit que l'utilisateur donne.
library;

import 'dart:convert';

/// Au-delà de cet écart entre deux lectures, la marche entre les deux n'est pas comptée : on ne sait
/// pas ce que le poêle a fait.
const maxRunGap = Duration(minutes: 15);

/// Nombre de jours gardés.
const keptRunDays = 90;

/// Au-dessous de ce nombre de jours d'autonomie, le stock est dit bas.
const lowStockDays = 3;

/// Durée pendant laquelle l'arrêt programmé s'applique, après son heure.
const stopWindowMinutes = 30;

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
    this.stockBags,
    this.stockAt,
    this.stopAtMinute,
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

  /// Sacs en stock à la date [stockAt], donnés par l'utilisateur ; Home en retire ce que le poêle a
  /// consommé depuis.
  final double? stockBags;
  final DateTime? stockAt;

  /// Heure d'arrêt programmé, en minutes depuis minuit ; null sans arrêt programmé.
  final int? stopAtMinute;

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
      stockBags: stockBags,
      stockAt: stockAt,
      stopAtMinute: stopAtMinute,
    );
  }

  PelletRuns withFlow({required double? pKgPerHour, required double pBagKg, double? pBagPrice}) =>
      PelletRuns(
        minutesByDay: minutesByDay,
        lastAt: lastAt,
        lastOn: lastOn,
        kgPerHour: pKgPerHour,
        bagKg: pBagKg,
        bagPrice: pBagPrice,
        stockBags: stockBags,
        stockAt: stockAt,
        stopAtMinute: stopAtMinute,
      );

  /// Range le stock de sacs compté à l'instant [pAt] ; null efface le stock.
  PelletRuns withStock(double? pBags, DateTime pAt) => PelletRuns(
    minutesByDay: minutesByDay,
    lastAt: lastAt,
    lastOn: lastOn,
    kgPerHour: kgPerHour,
    bagKg: bagKg,
    bagPrice: bagPrice,
    stockBags: pBags,
    stockAt: pBags == null ? null : pAt,
    stopAtMinute: stopAtMinute,
  );

  /// Règle l'arrêt programmé, en minutes depuis minuit ; null le retire.
  PelletRuns withStopAt(int? pMinute) => PelletRuns(
    minutesByDay: minutesByDay,
    lastAt: lastAt,
    lastOn: lastOn,
    kgPerHour: kgPerHour,
    bagKg: bagKg,
    bagPrice: bagPrice,
    stockBags: stockBags,
    stockAt: stockAt,
    stopAtMinute: pMinute,
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

  /// Heures de marche depuis le début du jour [pFrom], aujourd'hui compris.
  double hoursSince(DateTime pFrom, DateTime pNow) {
    final vFrom = _dayKey(pFrom);
    var vTotal = 0;
    for (final vEntry in minutesByDay.entries) {
      if (vEntry.key.compareTo(vFrom) >= 0) {
        vTotal += vEntry.value;
      }
    }

    return vTotal / 60;
  }

  /// Pellets restant en stock, null sans stock ou sans débit : sans débit, Home ne peut pas dire ce
  /// qui a été consommé.
  double? remainingKg(DateTime pNow) {
    final vBags = stockBags;
    final vFrom = stockAt;
    if (vBags == null || vFrom == null || kgPerHour == null) {
      return null;
    }
    final vLeft = vBags * bagKg - kgPerHour! * hoursSince(vFrom, pNow);

    return vLeft < 0 ? 0 : vLeft;
  }

  /// Jours d'autonomie au rythme des 7 derniers jours, null sans stock ou sans marche récente.
  double? autonomyDays(DateTime pNow) {
    final vLeft = remainingKg(pNow);
    final vWeekHours = hoursOver(7, pNow);
    if (vLeft == null || vWeekHours <= 0) {
      return null;
    }

    return vLeft / (kgPerHour! * vWeekHours / 7);
  }

  /// Vrai quand il reste moins de [lowStockDays] jours de pellets.
  bool isStockLow(DateTime pNow) {
    final vDays = autonomyDays(pNow);

    return vDays != null && vDays < lowStockDays;
  }

  /// Vrai dans la demi-heure qui suit l'heure d'arrêt programmé. Hors de cette fenêtre, un poêle
  /// allumé à la main plus tard n'est pas éteint.
  bool shouldStopNow(DateTime pNow) {
    final vStop = stopAtMinute;
    if (vStop == null) {
      return false;
    }
    final vSince = (pNow.hour * 60 + pNow.minute - vStop) % 1440;

    return vSince < stopWindowMinutes;
  }

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
  'stockSacs': pRuns.stockBags,
  'stockLe': pRuns.stockAt?.toIso8601String(),
  'arretMinute': pRuns.stopAtMinute,
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
    final vStock = vRoot['stockSacs'];
    final vStop = vRoot['arretMinute'];
    final vStockAt = DateTime.tryParse('${vRoot['stockLe']}');

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
      stockBags: vStock is num && vStock >= 0 && vStockAt != null ? vStock.toDouble() : null,
      stockAt: vStock is num && vStock >= 0 ? vStockAt : null,
      stopAtMinute: vStop is int && vStop >= 0 && vStop < 1440 ? vStop : null,
    );
  } on FormatException {
    return const PelletRuns();
  }
}
