/// Export CSV de l'appli ThermoPro (TempPro) : un capteur, un relevé par minute.
library;

import 'reading.dart';

/// Relevés lus dans un export, avec le nom tiré du fichier.
class ThermoproCsv {
  const ThermoproCsv({required this.sensorName, required this.readings, required this.skipped});

  /// Nom donné au capteur dans l'appli ThermoPro, repris du nom du fichier.
  final String sensorName;
  final List<Reading> readings;

  /// Lignes sans mesure (« - ») ou illisibles, ignorées.
  final int skipped;
}

/// Nom du capteur d'après le nom du fichier : `TempProSensor_Export_chambre_parent_28112026.csv`
/// donne « Chambre parent ».
String thermoproSensorName(String pFileName) {
  final vFile = pFileName.split(RegExp(r'[\\/]')).last;
  final vStem = vFile.replaceFirst(RegExp(r'\.csv$', caseSensitive: false), '');
  final vMatch = RegExp(r'^TempProSensor_Export_(.+?)(?:_\d{8})?$').firstMatch(vStem);
  final vName = (vMatch?.group(1) ?? vStem).replaceAll('_', ' ').trim();
  if (vName.isEmpty) {
    return 'ThermoPro';
  }

  return vName[0].toUpperCase() + vName.substring(1);
}

final _line = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4}),(\d{1,2}):(\d{2}),([^,]*),([^,]*)$');

/// Lit un export. Garde un relevé par tranche de [pStepMinutes] minutes (le premier), pour ne pas
/// alourdir le téléphone avec huit mois à la minute. Renvoie null si le texte n'est pas un export
/// ThermoPro.
ThermoproCsv? parseThermoproCsv(String pText, String pFileName, {int pStepMinutes = 10}) {
  final vLines = pText.replaceAll('﻿', '').split(RegExp(r'\r?\n'));
  final vHeader = vLines.indexWhere((pLine) => pLine.trim().startsWith('Date,Heure,'));
  if (vHeader < 0) {
    return null;
  }
  final vByStep = <int, Reading>{};
  var vSkipped = 0;
  final vStepMs = pStepMinutes * Duration.millisecondsPerMinute;
  for (final vRaw in vLines.skip(vHeader + 1)) {
    final vText = vRaw.trim();
    if (vText.isEmpty) {
      continue;
    }
    final vMatch = _line.firstMatch(vText);
    final vTemp = double.tryParse(vMatch?.group(6) ?? '');
    final vHumidity = double.tryParse(vMatch?.group(7) ?? '');
    if (vMatch == null || vTemp == null || vHumidity == null) {
      vSkipped++;
      continue;
    }
    final vAt = DateTime(
      int.parse(vMatch.group(3)!),
      int.parse(vMatch.group(2)!),
      int.parse(vMatch.group(1)!),
      int.parse(vMatch.group(4)!),
      int.parse(vMatch.group(5)!),
    );
    vByStep.putIfAbsent(
      vAt.millisecondsSinceEpoch ~/ vStepMs,
      () => Reading(at: vAt, temp: vTemp, humidity: vHumidity),
    );
  }
  final vReadings = vByStep.values.toList()..sort((pA, pB) => pA.at.compareTo(pB.at));

  return ThermoproCsv(
    sensorName: thermoproSensorName(pFileName),
    readings: vReadings,
    skipped: vSkipped,
  );
}
