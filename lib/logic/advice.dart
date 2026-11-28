/// Conseils du moment pour une pièce : aérer, garder fermé, ou humidifier l'air.
library;

import 'analysis.dart';
import 'reading.dart';
import 'rooms.dart';

enum AdviceKind { ventilate, keepClosed, dryAir }

class Advice {
  const Advice({required this.kind, required this.room});

  final AdviceKind kind;
  final String room;
}

/// Écart minimal d'eau dans l'air, en g/m³, pour que l'aération assèche vraiment une pièce.
const minVentilationGain = 1.0;

/// Un conseil par pièce hors de sa plage d'humidité. Sans relevé extérieur, on ne conseille pas
/// d'aérer ni de rester fermé, faute de savoir si l'air du dehors est plus sec.
List<Advice> adviceFor(List<RoomStatus> pRooms, Reading? pOutdoor) {
  final rAdvice = <Advice>[];
  for (final vRoom in pRooms) {
    switch (vRoom.state) {
      case HumidityState.fine:
        break;
      case HumidityState.dry:
        rAdvice.add(Advice(kind: AdviceKind.dryAir, room: vRoom.room));
      case HumidityState.humid:
        if (pOutdoor == null) {
          break;
        }
        final vInside = absoluteHumidity(vRoom.temp, vRoom.humidity);
        final vOutside = absoluteHumidity(pOutdoor.temp, pOutdoor.humidity);
        final vKind = vInside - vOutside >= minVentilationGain
            ? AdviceKind.ventilate
            : AdviceKind.keepClosed;
        rAdvice.add(Advice(kind: vKind, room: vRoom.room));
    }
  }

  return rAdvice;
}
