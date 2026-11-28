/// Résumé du matin : ce qui mérite un coup d'œil dans la maison, en deux ou trois phrases.
library;

import 'rooms.dart';

/// Heure à partir de laquelle le résumé du jour peut partir.
const summaryHour = 8;

class DaySummary {
  const DaySummary({required this.title, required this.body});

  final String title;
  final String body;
}

String _number(double pValue) => pValue.toStringAsFixed(1).replaceAll('.', ',');

/// Résumé des pièces rangées, null quand aucune pièce n'a de relevé. Dit la pièce la plus fraîche,
/// la plus humide et combien de pièces sont hors de leur plage d'humidité.
DaySummary? buildDaySummary(List<RoomStatus> pRooms) {
  if (pRooms.isEmpty) {
    return null;
  }
  final vColdest = pRooms.reduce((pA, pB) => pA.temp <= pB.temp ? pA : pB);
  final vWettest = pRooms.reduce((pA, pB) => pA.humidity >= pB.humidity ? pA : pB);
  final vOut = pRooms.where((pRoom) => pRoom.state != HumidityState.fine).length;
  final vLines = [
    'Pièce la plus fraîche : ${vColdest.room} (${_number(vColdest.temp)} °C).',
    'Pièce la plus humide : ${vWettest.room} (${vWettest.humidity.round()} %).',
    if (vOut == 0)
      'Humidité correcte partout.'
    else
      '$vOut ${vOut == 1 ? 'pièce' : 'pièces'} hors de la plage d\'humidité.',
  ];

  return DaySummary(title: 'Résumé de la maison', body: vLines.join(' '));
}

/// Vrai quand le résumé doit partir : l'heure est passée et il n'est pas encore parti aujourd'hui.
bool summaryDue(DateTime pNow, {required DateTime? pLastSent, int pHour = summaryHour}) {
  if (pNow.hour < pHour) {
    return false;
  }

  return pLastSent == null ||
      DateTime(pLastSent.year, pLastSent.month, pLastSent.day).isBefore(
        DateTime(pNow.year, pNow.month, pNow.day),
      );
}
