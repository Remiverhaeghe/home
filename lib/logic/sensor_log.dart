import 'reading.dart';

/// Écart minimal entre deux relevés gardés pour un même capteur : le capteur parle plus souvent
/// que nécessaire, et le fichier ne doit pas grossir pour rien.
const minReadingGap = Duration(minutes: 1);

/// Capteurs avec un relevé de plus. Le relevé est ignoré s'il suit de trop près le précédent du
/// même capteur (nom comparé sans majuscules). Un capteur inconnu est créé.
List<Sensor> withLiveReading(List<Sensor> pSensors, String pName, Reading pReading) {
  final vKey = pName.trim().toLowerCase();
  final vIndex = pSensors.indexWhere((pS) => pS.name.trim().toLowerCase() == vKey);
  if (vIndex < 0) {
    return [...pSensors, Sensor(name: pName.trim(), readings: [pReading])];
  }
  final vOld = pSensors[vIndex];
  final vLast = vOld.last;
  if (vLast != null && pReading.at.difference(vLast.at) < minReadingGap) {
    return pSensors;
  }

  return [
    for (var vAt = 0; vAt < pSensors.length; vAt++)
      vAt == vIndex
          ? Sensor(name: vOld.name, readings: [...vOld.readings, pReading])
          : pSensors[vAt],
  ];
}
