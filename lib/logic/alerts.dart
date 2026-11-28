import 'reading.dart';

/// Ce qui mérite une notification.
enum AlertKind { frost, humidity, silent, stuck, ventilate }

/// Seuils des alertes.
const frostAlertTemp = 5.0;
const humidityAlertLevel = 70.0;

/// Bornes du seuil d'humidité réglable, par pas de 1 %.
const humidityAlertMin = 55.0;
const humidityAlertMax = 85.0;

/// Un tour de relevé dure 5 minutes et le Bluetooth manque parfois quelques tours : une heure
/// sans relevé, pas moins, avant de dire qu'un capteur est muet.
const silentAfter = Duration(minutes: 60);

/// Un capteur qui répète exactement les mêmes valeurs depuis 6 heures, sur 12 relevés au moins,
/// est figé : pile faible ou capteur bloqué.
const stuckAfter = Duration(hours: 6);
const stuckMinReadings = 12;

/// Une douche ou une cuisson fait monter vite l'humidité : au moins [ventilateRise] points en
/// [ventilateWindow], pour une humidité qui dépasse déjà [ventilateFrom]. Ce sont des repères de
/// prudence, pas des mesures : ils servent à conseiller d'aérer, pas à diagnostiquer.
const ventilateWindow = Duration(minutes: 30);
const ventilateRise = 12.0;
const ventilateFrom = 60.0;

/// Au moins deux relevés écartés d'un quart d'heure, pour ne pas conclure sur du bruit.
const ventilateMinSpan = Duration(minutes: 15);

/// L'humidité vient-elle de monter vite, d'après les relevés des dernières [ventilateWindow] ?
bool isRisingFast(List<Reading> pReadings) {
  if (pReadings.length < 2) {
    return false;
  }
  final vLast = pReadings.last;
  if (vLast.humidity < ventilateFrom) {
    return false;
  }
  Reading? vLow;
  for (var vIndex = pReadings.length - 2; vIndex >= 0; vIndex--) {
    final vAge = vLast.at.difference(pReadings[vIndex].at);
    if (vAge > ventilateWindow) {
      break;
    }
    if (vAge >= ventilateMinSpan && (vLow == null || pReadings[vIndex].humidity < vLow.humidity)) {
      vLow = pReadings[vIndex];
    }
  }

  return vLow != null && vLast.humidity - vLow.humidity >= ventilateRise;
}

/// Les derniers relevés sont-ils identiques depuis [stuckAfter] ? Ne lit que la fin de la liste.
bool isStuck(List<Reading> pReadings) {
  if (pReadings.length < stuckMinReadings) {
    return false;
  }
  final vLast = pReadings.last;
  var vFirst = pReadings.length - 1;
  while (vFirst > 0 &&
      pReadings[vFirst - 1].temp == vLast.temp &&
      pReadings[vFirst - 1].humidity == vLast.humidity) {
    vFirst--;
  }

  return pReadings.length - vFirst >= stuckMinReadings &&
      vLast.at.difference(pReadings[vFirst].at) >= stuckAfter;
}

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
/// [pHumidityLevel] (70 % au départ, réglable), capteur sans relevé depuis [silentAfter], humidité qui
/// monte vite (conseil d'aérer, sauf pour les capteurs de [pOutdoor]). Un capteur sans aucun relevé
/// n'alerte pas : il n'a encore jamais parlé. Seuls les capteurs de [pWatched] (ceux que le service
/// d'arrière-plan suit) peuvent être muets : les autres ne donnent un relevé que quand on ouvre
/// l'appli. Sans [pWatched], tous les capteurs sont surveillés.
List<SensorAlert> evaluateAlerts(
  List<Sensor> pSensors,
  DateTime pNow, {
  Set<String>? pWatched,
  double pHumidityLevel = humidityAlertLevel,
  Set<String> pOutdoor = const {},
}) {
  final rAlerts = <SensorAlert>[];
  for (final vSensor in pSensors) {
    final vLast = vSensor.last;
    if (vLast == null) {
      continue;
    }
    final vSilent = pNow.difference(vLast.at) > silentAfter;
    if (vSilent && (pWatched == null || pWatched.contains(vSensor.name))) {
      rAlerts.add(SensorAlert(sensorName: vSensor.name, kind: AlertKind.silent));
    }
    if (vSilent) {
      // Une mesure ancienne ne dit rien du gel ni de l'humidité d'aujourd'hui
      continue;
    }
    if (isStuck(vSensor.readings)) {
      rAlerts.add(SensorAlert(sensorName: vSensor.name, kind: AlertKind.stuck));
    }
    if (!pOutdoor.contains(vSensor.name) && isRisingFast(vSensor.readings)) {
      rAlerts.add(
        SensorAlert(sensorName: vSensor.name, kind: AlertKind.ventilate, value: vLast.humidity),
      );
    }
    if (vLast.temp < frostAlertTemp) {
      rAlerts.add(SensorAlert(sensorName: vSensor.name, kind: AlertKind.frost, value: vLast.temp));
    }
    if (vLast.humidity > pHumidityLevel) {
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
        AlertKind.stuck => 'Capteur figé : ${pAlert.sensorName}',
        AlertKind.ventilate => 'Aérer : ${pAlert.sensorName}',
      },
    )
    .join(' · ');

String _decimal(double pValue) => pValue.toStringAsFixed(1).replaceAll('.', ',');
