import 'dart:io';

import '../logic/climate_exchange.dart';
import '../logic/reading.dart';
import 'sensor_store.dart';

/// Capteurs rangés dans un fichier JSON au format d'échange, sur le téléphone seulement.
class FileSensorStore implements SensorStore {
  FileSensorStore(this.file);

  final File file;

  @override
  Future<List<Sensor>> load() async {
    if (!await file.exists()) {
      return [];
    }
    try {
      return parseExchange(await file.readAsString());
    } on ExchangeException {
      // Fichier abîmé : on repart de zéro plutôt que de bloquer l'appli
      return [];
    }
  }

  @override
  Future<void> save(List<Sensor> pSensors) async {
    // Écriture dans un fichier voisin puis renommage : une coupure ne laisse pas un demi-fichier
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(exchangeJson(pSensors), flush: true);
    await vTemp.rename(file.path);
  }
}
