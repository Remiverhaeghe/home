import 'dart:convert';

import 'alerts.dart';
import 'heating_costs.dart';

/// Nombre d'entrées gardées dans l'historique.
const alertHistoryMax = 100;

/// Une alerte qui dure n'est notée qu'une fois par tranche de cette durée.
const alertHistoryRepeat = Duration(hours: 6);

/// Alertes qui sonnent à l'instant [pNow] : pendant les heures silencieuses [pQuiet], seul le gel
/// passe. Les autres restent visibles sur l'écran du plan et dans l'historique.
List<SensorAlert> audibleAlerts(List<SensorAlert> pAlerts, DateTime pNow, OffPeak? pQuiet) {
  if (pQuiet == null || !pQuiet.isValid || !pQuiet.contains(pNow)) {
    return pAlerts;
  }

  return [
    for (final vAlert in pAlerts)
      if (vAlert.kind == AlertKind.frost) vAlert,
  ];
}

/// Une alerte passée : quand, sur quel capteur, de quelle sorte.
class AlertEntry {
  const AlertEntry({required this.at, required this.sensorName, required this.kind});

  final DateTime at;
  final String sensorName;
  final AlertKind kind;

  Map<String, Object> toJson() => {
    'at': at.toIso8601String(),
    'sensor': sensorName,
    'kind': kind.name,
  };
}

/// Relit l'historique ; une ligne illisible est ignorée, le reste est gardé.
List<AlertEntry> parseAlertHistory(String pText) {
  final rEntries = <AlertEntry>[];
  for (final vLine in const LineSplitter().convert(pText)) {
    try {
      final vJson = jsonDecode(vLine) as Map<String, dynamic>;
      final vAt = DateTime.tryParse(vJson['at'] as String);
      final vKind = AlertKind.values.where((pKind) => pKind.name == vJson['kind']);
      if (vAt != null && vKind.isNotEmpty && vJson['sensor'] is String) {
        rEntries.add(AlertEntry(at: vAt, sensorName: vJson['sensor'] as String, kind: vKind.first));
      }
    } on Object {
      continue;
    }
  }

  return rEntries;
}

String alertHistoryText(List<AlertEntry> pEntries) =>
    pEntries.map((pEntry) => jsonEncode(pEntry.toJson())).join('\n');

/// Ajoute les alertes de [pAlerts] à [pHistory], sauf celles déjà notées depuis moins de
/// [alertHistoryRepeat], et ne garde que les [alertHistoryMax] plus récentes.
List<AlertEntry> appendAlerts(List<AlertEntry> pHistory, List<SensorAlert> pAlerts, DateTime pNow) {
  final rHistory = [...pHistory];
  for (final vAlert in pAlerts) {
    final vRecent = rHistory.any(
      (pEntry) =>
          pEntry.sensorName == vAlert.sensorName &&
          pEntry.kind == vAlert.kind &&
          pNow.difference(pEntry.at) < alertHistoryRepeat,
    );
    if (!vRecent) {
      rHistory.add(AlertEntry(at: pNow, sensorName: vAlert.sensorName, kind: vAlert.kind));
    }
  }

  return rHistory.length > alertHistoryMax
      ? rHistory.sublist(rHistory.length - alertHistoryMax)
      : rHistory;
}
