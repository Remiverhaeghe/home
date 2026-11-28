/// Coup de chaud temporaire dans une pièce : douche, bain ou lessive. La température souhaitée
/// monte pendant un temps donné, puis le planning reprend.
library;

import 'dart:convert';

enum BoostKind { shower, bath, laundry, night }

/// Réglage de départ de chaque usage : température en °C et durée en minutes.
({double temp, int minutes}) defaultBoost(BoostKind pKind) => switch (pKind) {
  BoostKind.shower => (temp: 24.0, minutes: 45),
  BoostKind.bath => (temp: 25.0, minutes: 90),
  BoostKind.laundry => (temp: 22.0, minutes: 180),
  // La nuit a sa propre température par pièce et dure jusqu'au matin : voir scenarios.dart
  BoostKind.night => (temp: 17.0, minutes: 480),
};

/// Bornes des réglages, par pas de 0,5 °C et de 15 minutes.
const boostMinTemp = 18.0;
const boostMaxTemp = 28.0;
const boostMinMinutes = 15;
const boostMaxMinutes = 240;

class Boost {
  const Boost({required this.host, required this.kind, required this.temp, required this.until});

  /// Adresse de la clim de la pièce.
  final String host;
  final BoostKind kind;
  final double temp;
  final DateTime until;

  bool isActiveAt(DateTime pNow) => pNow.isBefore(until);
}

/// Coups de chaud encore en cours à l'instant [pNow], un par clim (le plus récent l'emporte).
Map<String, Boost> activeBoosts(List<Boost> pBoosts, DateTime pNow) => {
  for (final vBoost in pBoosts)
    if (vBoost.isActiveAt(pNow)) vBoost.host: vBoost,
};

String boostsToJson(List<Boost> pBoosts) => jsonEncode([
  for (final vBoost in pBoosts)
    {
      'host': vBoost.host,
      'kind': vBoost.kind.name,
      'temp': vBoost.temp,
      'until': vBoost.until.toIso8601String(),
    },
]);

/// Lit les coups de chaud ; une entrée abîmée est ignorée.
List<Boost> parseBoosts(Object? pRoot) {
  if (pRoot is! List) {
    return [];
  }
  final rBoosts = <Boost>[];
  for (final vItem in pRoot) {
    if (vItem is! Map<String, dynamic>) {
      continue;
    }
    final vKind = BoostKind.values.where((pKind) => pKind.name == vItem['kind']).firstOrNull;
    final vTemp = vItem['temp'];
    final vUntil = DateTime.tryParse('${vItem['until']}');
    final vHost = vItem['host'];
    if (vKind != null && vTemp is num && vUntil != null && vHost is String && vHost.isNotEmpty) {
      rBoosts.add(Boost(host: vHost, kind: vKind, temp: vTemp.toDouble(), until: vUntil));
    }
  }

  return rBoosts;
}
