import 'reading.dart';

/// Ce qui mérite une notification.
enum AlertKind { frost, humidity, silent }

/// Seuils des alertes.
const frostAlertTemp = 5.0;
const humidityAlertLevel = 70.0;
const silentAfter = Duration(minutes: 30);

/// Une alerte sur un capteur. [value] est la mesure en cause, absente pour un capteur muet.
class SensorAlert {
  const SensorAlert({required this.sensorName, required this.kind, this.value});

  final String sensorName;
  final AlertKind kind;
  final double? value;

  /// Clé stable : une alerte déjà signalée n'est pas renvoyée tant qu'elle dure.
  String get key => '$sensorName|${kind.name}';
}

/// Alertes à l'instant [pNow] : gel sous [frostAlertTemp], humidité au-dessus de
/// [humidityAlertLevel], capteur sans relevé depuis [silentAfter]. Un capteur sans aucun relevé
/// n'alerte pas : il n'a encore jamais parlé.
List<SensorAlert> evaluateAlerts(List<Sensor> pSensors, DateTime pNow) {
  final rAlerts = <SensorAlert>[];
  for (final vSensor in pSensors) {
    final vLast = vSensor.last;
    if (vLast == null) {
      continue;
    }
    if (pNow.difference(vLast.at) > silentAfter) {
      rAlerts.add(SensorAlert(sensorName: vSensor.name, kind: AlertKind.silent));
      continue;
    }
    if (vLast.temp < frostAlertTemp) {
      rAlerts.add(SensorAlert(sensorName: vSensor.name, kind: AlertKind.frost, value: vLast.temp));
    }
    if (vLast.humidity > humidityAlertLevel) {
      rAlerts.add(
        SensorAlert(sensorName: vSensor.name, kind: AlertKind.humidity, value: vLast.humidity),
      );
    }
  }

  return rAlerts;
}

/// Alertes de [pCurrent] pas encore signalées, d'après les clés déjà connues [pKnown].
List<SensorAlert> freshAlerts(List<SensorAlert> pCurrent, Set<String> pKnown) =>
    pCurrent.where((pAlert) => !pKnown.contains(pAlert.key)).toList();

/// Une phrase pour la notification du service : « Gel : Salon (3,0 °C) · Humidité : Bain (74 %) ».
/// Vide quand il n'y a aucune alerte.
String alertSummary(List<SensorAlert> pAlerts) => pAlerts
    .map(
      (pAlert) => switch (pAlert.kind) {
        AlertKind.frost => 'Gel : ${pAlert.sensorName} (${_decimal(pAlert.value ?? 0)} °C)',
        AlertKind.humidity => 'Humidité : ${pAlert.sensorName} (${(pAlert.value ?? 0).round()} %)',
        AlertKind.silent => 'Capteur muet : ${pAlert.sensorName}',
      },
    )
    .join(' · ');

String _decimal(double pValue) => pValue.toStringAsFixed(1).replaceAll('.', ',');
