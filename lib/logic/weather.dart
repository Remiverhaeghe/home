/// Relevés météo extérieurs : adresse de la demande, lecture de la réponse, archive, CSV et
/// comparaison avec l'intérieur.
library;

import 'dart:convert';

import 'house.dart';
import 'reading.dart';

/// Seul serveur Internet que contacte Home, et seulement si l'utilisateur l'a autorisé.
const weatherHost = 'api.open-meteo.com';

/// Durée gardée dans l'archive.
const weatherKeepDays = 400;

/// Demande des relevés horaires (température et humidité à 2 m) des [pPastDays] derniers jours et
/// d'aujourd'hui, à l'heure locale du lieu. Seules les coordonnées de la maison sont envoyées.
Uri weatherUri(HouseLocation pLocation, {int pPastDays = 7}) => Uri(
  scheme: 'https',
  host: weatherHost,
  path: '/v1/forecast',
  queryParameters: {
    'latitude': pLocation.latitude.toStringAsFixed(4),
    'longitude': pLocation.longitude.toStringAsFixed(4),
    'hourly': 'temperature_2m,relative_humidity_2m',
    'past_days': '$pPastDays',
    'forecast_days': '1',
    'timezone': 'auto',
  },
);

/// Lit la réponse. Les heures à venir et les valeurs manquantes sont ignorées ; une réponse
/// inattendue donne une liste vide.
List<Reading> parseWeather(String pJson, {required DateTime pNow}) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pJson);
  } on FormatException {
    return [];
  }
  final vHourly = vRoot is Map<String, dynamic> ? vRoot['hourly'] : null;
  if (vHourly is! Map<String, dynamic>) {
    return [];
  }
  final vTimes = vHourly['time'];
  final vTemps = vHourly['temperature_2m'];
  final vHumidities = vHourly['relative_humidity_2m'];
  if (vTimes is! List || vTemps is! List || vHumidities is! List) {
    return [];
  }
  final rReadings = <Reading>[];
  for (var vIndex = 0; vIndex < vTimes.length; vIndex++) {
    final vText = vTimes[vIndex];
    final vAt = vText is String ? DateTime.tryParse(vText) : null;
    final vTemp = vIndex < vTemps.length ? vTemps[vIndex] : null;
    final vHumidity = vIndex < vHumidities.length ? vHumidities[vIndex] : null;
    if (vAt == null || vTemp is! num || vHumidity is! num || vAt.isAfter(pNow)) {
      continue;
    }
    rReadings.add(Reading(at: vAt, temp: vTemp.toDouble(), humidity: vHumidity.toDouble()));
  }

  return rReadings;
}

/// Ajoute des relevés à l'archive : une même heure est remplacée, jamais doublée, et ce qui a plus
/// de [weatherKeepDays] jours est retiré.
List<Reading> mergeWeather(List<Reading> pKnown, List<Reading> pIncoming) {
  final vByDate = {for (final vReading in pKnown) vReading.at: vReading};
  for (final vReading in pIncoming) {
    vByDate[vReading.at] = vReading;
  }
  final rReadings = vByDate.values.toList()..sort((pA, pB) => pA.at.compareTo(pB.at));
  if (rReadings.isEmpty) {
    return rReadings;
  }
  final vFrom = rReadings.last.at.subtract(const Duration(days: weatherKeepDays));

  return rReadings.where((pReading) => !pReading.at.isBefore(vFrom)).toList();
}

/// Fichier `meteo.json` : l'autorisation et l'archive, version 1.
String weatherJson({required bool pEnabled, required List<Reading> pReadings}) => jsonEncode({
  'version': 1,
  'enabled': pEnabled,
  'readings': [
    for (final vReading in pReadings)
      {
        'at': vReading.at.toIso8601String(),
        'temp': vReading.temp,
        'humidity': vReading.humidity,
      },
  ],
});

/// Relit le fichier ; un fichier abîmé donne une archive vide et l'accès désactivé.
({bool enabled, List<Reading> readings}) parseWeatherFile(String pText) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pText);
  } on FormatException {
    return (enabled: false, readings: <Reading>[]);
  }
  if (vRoot is! Map<String, dynamic> || vRoot['version'] != 1) {
    return (enabled: false, readings: <Reading>[]);
  }
  final vList = vRoot['readings'];
  final rReadings = <Reading>[];
  if (vList is List) {
    for (final vEntry in vList) {
      if (vEntry is! Map<String, dynamic>) {
        continue;
      }
      final vAt = vEntry['at'] is String ? DateTime.tryParse(vEntry['at'] as String) : null;
      final vTemp = vEntry['temp'];
      final vHumidity = vEntry['humidity'];
      if (vAt != null && vTemp is num && vHumidity is num) {
        rReadings.add(Reading(at: vAt, temp: vTemp.toDouble(), humidity: vHumidity.toDouble()));
      }
    }
  }

  return (enabled: vRoot['enabled'] == true, readings: rReadings);
}

/// Tableau CSV pour un tableur français : séparateur point-virgule, virgule décimale.
String weatherCsv(List<Reading> pReadings) {
  String number(double pValue) => pValue.toStringAsFixed(1).replaceAll('.', ',');
  final vLines = ['date;temperature_c;humidite_pct'];
  for (final vReading in pReadings) {
    vLines.add(
      '${vReading.at.toIso8601String()};${number(vReading.temp)};${number(vReading.humidity)}',
    );
  }

  return '${vLines.join('\n')}\n';
}

/// Comparaison d'un capteur intérieur avec l'extérieur sur les mêmes heures.
class OutdoorComparison {
  const OutdoorComparison({
    required this.meanDelta,
    required this.indoorAmplitude,
    required this.outdoorAmplitude,
    required this.hours,
  });

  /// Écart moyen intérieur moins extérieur, en °C.
  final double meanDelta;

  /// Amplitude moyenne de la température sur un jour, dedans et dehors.
  final double indoorAmplitude;
  final double outdoorAmplitude;
  final int hours;

  /// Part de l'amplitude extérieure qui passe à l'intérieur : près de 0, le bâtiment amortit
  /// bien ; près de 1, il suit le dehors. Null quand le dehors ne varie pas.
  double? get damping => outdoorAmplitude > 0 ? indoorAmplitude / outdoorAmplitude : null;
}

/// Compare chaque relevé intérieur au relevé extérieur de la même heure. Null avec moins de
/// [pMinHours] heures en commun.
OutdoorComparison? compareWithOutdoor(
  List<Reading> pIndoor,
  List<Reading> pOutdoor, {
  int pMinHours = 6,
}) {
  DateTime hourOf(DateTime pAt) => DateTime(pAt.year, pAt.month, pAt.day, pAt.hour);
  final vOutdoorByHour = {for (final vReading in pOutdoor) hourOf(vReading.at): vReading};
  final vIndoorByHour = <DateTime, Reading>{};
  for (final vReading in pIndoor) {
    vIndoorByHour.putIfAbsent(hourOf(vReading.at), () => vReading);
  }
  final vHours = vIndoorByHour.keys.where(vOutdoorByHour.containsKey).toList();
  if (vHours.length < pMinHours) {
    return null;
  }
  var vSum = 0.0;
  final vIndoorDays = <DateTime, List<double>>{};
  final vOutdoorDays = <DateTime, List<double>>{};
  for (final vHour in vHours) {
    final vIn = vIndoorByHour[vHour]!.temp;
    final vOut = vOutdoorByHour[vHour]!.temp;
    vSum += vIn - vOut;
    final vDay = DateTime(vHour.year, vHour.month, vHour.day);
    vIndoorDays.putIfAbsent(vDay, () => []).add(vIn);
    vOutdoorDays.putIfAbsent(vDay, () => []).add(vOut);
  }
  double amplitude(Map<DateTime, List<double>> pDays) {
    final vSpreads = [
      for (final vValues in pDays.values)
        vValues.reduce((pA, pB) => pA > pB ? pA : pB) -
            vValues.reduce((pA, pB) => pA < pB ? pA : pB),
    ];

    return vSpreads.reduce((pA, pB) => pA + pB) / vSpreads.length;
  }

  return OutdoorComparison(
    meanDelta: vSum / vHours.length,
    indoorAmplitude: amplitude(vIndoorDays),
    outdoorAmplitude: amplitude(vOutdoorDays),
    hours: vHours.length,
  );
}
