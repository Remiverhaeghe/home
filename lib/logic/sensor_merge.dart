import 'reading.dart';

/// Nom comparable : sans espaces superflus ni majuscules.
String _key(String pName) => pName.trim().toLowerCase();

/// Ajoute les capteurs importés aux capteurs connus. Un capteur de même nom reçoit les nouveaux
/// relevés ; un relevé à la même date est remplacé, jamais doublé.
List<Sensor> mergeSensors(List<Sensor> pKnown, List<Sensor> pIncoming) {
  final vByKey = {for (final vSensor in pKnown) _key(vSensor.name): vSensor};
  for (final vSensor in pIncoming) {
    final vOld = vByKey[_key(vSensor.name)];
    if (vOld == null) {
      vByKey[_key(vSensor.name)] = vSensor;
      continue;
    }
    final vByDate = {for (final vReading in vOld.readings) vReading.at: vReading};
    for (final vReading in vSensor.readings) {
      vByDate[vReading.at] = vReading;
    }
    final vReadings = vByDate.values.toList()..sort((pA, pB) => pA.at.compareTo(pB.at));
    vByKey[_key(vSensor.name)] = Sensor(name: vOld.name, readings: vReadings);
  }

  return vByKey.values.toList();
}
