/// Tuiles de l'affichage mural : une par pièce, avec la mesure du capteur et l'état de la clim.
library;

import 'ac_units.dart';
import 'daikin.dart';
import 'reading.dart';

/// Au-delà, le relevé d'un capteur est signalé comme ancien.
const staleReading = Duration(minutes: 30);

/// Où en est la climatisation d'une tuile.
enum WallAc {
  /// Aucune climatisation dans cette pièce.
  none,

  /// Pas encore lue.
  loading,

  /// Elle n'a pas répondu à la dernière lecture.
  unreachable,

  /// État lu : les commandes sont possibles.
  ready,
}

class WallTile {
  const WallTile({
    required this.name,
    this.host,
    this.reading,
    this.stale = false,
    this.ac = WallAc.none,
    this.control,
  });

  /// Nom de la pièce : celui de la climatisation, ou du capteur sans climatisation.
  final String name;

  /// Adresse de la climatisation, null s'il n'y en a pas.
  final String? host;

  /// Dernier relevé du capteur lié, null sans capteur ou sans relevé.
  final Reading? reading;
  final bool stale;
  final WallAc ac;

  /// Réglages lus, seulement quand [ac] vaut [WallAc.ready].
  final DaikinControl? control;
}

/// Une tuile par climatisation (avec le capteur qui lui est lié), puis une par capteur resté seul.
///
/// [pControls] donne l'état lu de chaque climatisation : absente de la table, elle n'a pas encore
/// été lue ; présente avec null, elle n'a pas répondu.
List<WallTile> buildWallTiles({
  required List<Sensor> pSensors,
  required List<AcUnit> pUnits,
  required Map<String, DaikinControl?> pControls,
  required DateTime pNow,
}) {
  bool isStale(Reading? pReading) =>
      pReading != null && pNow.difference(pReading.at) > staleReading;
  final vLinked = <String>{};
  final rTiles = <WallTile>[];
  for (final vUnit in pUnits) {
    final vSensor = pSensors.where((pSensor) => pSensor.name == vUnit.sensorName).firstOrNull;
    if (vSensor != null) {
      vLinked.add(vSensor.name);
    }
    final vReading = vSensor?.last;
    final vControl = pControls[vUnit.host];
    rTiles.add(
      WallTile(
        name: vUnit.name,
        host: vUnit.host,
        reading: vReading,
        stale: isStale(vReading),
        ac: !pControls.containsKey(vUnit.host)
            ? WallAc.loading
            : vControl == null
            ? WallAc.unreachable
            : WallAc.ready,
        control: vControl,
      ),
    );
  }
  for (final vSensor in pSensors) {
    if (!vLinked.contains(vSensor.name)) {
      rTiles.add(WallTile(name: vSensor.name, reading: vSensor.last, stale: isStale(vSensor.last)));
    }
  }

  return rTiles;
}
