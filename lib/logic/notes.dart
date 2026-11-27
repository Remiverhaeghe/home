/// Notes datées sur la vie de la maison (isolation posée, fenêtre changée) et leur effet mesuré.
library;

import 'dart:convert';

import 'reading.dart';

class HouseNote {
  const HouseNote({required this.at, required this.text, this.sensor});

  /// Jour de la note, à minuit.
  final DateTime at;
  final String text;

  /// Capteur concerné par l'identifiant ; null pour toute la maison.
  final String? sensor;
}

/// Fichier `notes.json`, version 1.
String notesJson(List<HouseNote> pNotes) => jsonEncode({
  'version': 1,
  'notes': [
    for (final vNote in pNotes)
      {'at': vNote.at.toIso8601String(), 'text': vNote.text, 'sensor': vNote.sensor},
  ],
});

/// Relit le fichier, triées de la plus récente à la plus ancienne ; une note illisible est
/// ignorée, un fichier abîmé ou d'une autre version donne une liste vide.
List<HouseNote> parseNotes(String pText) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pText);
  } on FormatException {
    return [];
  }
  final vList = vRoot is Map<String, dynamic> && vRoot['version'] == 1 ? vRoot['notes'] : null;
  if (vList is! List) {
    return [];
  }
  final rNotes = <HouseNote>[];
  for (final vEntry in vList) {
    if (vEntry is! Map<String, dynamic>) {
      continue;
    }
    final vAt = vEntry['at'] is String ? DateTime.tryParse(vEntry['at'] as String) : null;
    final vTextValue = vEntry['text'];
    final vSensor = vEntry['sensor'];
    if (vAt == null || vTextValue is! String || vTextValue.trim().isEmpty) {
      continue;
    }
    rNotes.add(
      HouseNote(
        at: DateTime(vAt.year, vAt.month, vAt.day),
        text: vTextValue.trim(),
        sensor: vSensor is String ? vSensor : null,
      ),
    );
  }
  rNotes.sort((pA, pB) => pB.at.compareTo(pA.at));

  return rNotes;
}

/// Moyennes avant et après une date.
class BeforeAfter {
  const BeforeAfter({
    required this.tempBefore,
    required this.tempAfter,
    required this.humidityBefore,
    required this.humidityAfter,
    required this.days,
  });

  final double tempBefore;
  final double tempAfter;
  final double humidityBefore;
  final double humidityAfter;

  /// Durée comparée de chaque côté, en jours.
  final int days;

  double get tempChange => tempAfter - tempBefore;
  double get humidityChange => humidityAfter - humidityBefore;
}

/// Compare les [pDays] jours avant la date aux [pDays] jours après. Null s'il manque des relevés
/// d'un côté (moins de 24 relevés), ou si la période d'après n'est pas finie.
BeforeAfter? beforeAfter(
  List<Reading> pReadings,
  DateTime pDate, {
  required DateTime pNow,
  int pDays = 14,
  int pMinReadings = 24,
}) {
  final vDay = DateTime(pDate.year, pDate.month, pDate.day);
  final vFrom = vDay.subtract(Duration(days: pDays));
  final vTo = vDay.add(Duration(days: pDays));
  if (vTo.isAfter(pNow)) {
    return null;
  }
  final vBefore = pReadings.where((pR) => !pR.at.isBefore(vFrom) && pR.at.isBefore(vDay)).toList();
  final vAfter = pReadings.where((pR) => !pR.at.isBefore(vDay) && pR.at.isBefore(vTo)).toList();
  if (vBefore.length < pMinReadings || vAfter.length < pMinReadings) {
    return null;
  }
  double mean(List<Reading> pList, double Function(Reading) pValue) =>
      pList.map(pValue).reduce((pA, pB) => pA + pB) / pList.length;

  return BeforeAfter(
    tempBefore: mean(vBefore, (pR) => pR.temp),
    tempAfter: mean(vAfter, (pR) => pR.temp),
    humidityBefore: mean(vBefore, (pR) => pR.humidity),
    humidityAfter: mean(vAfter, (pR) => pR.humidity),
    days: pDays,
  );
}
