import '../logic/reading.dart';

/// Où vivent les capteurs : un fichier sur le téléphone, ou la mémoire dans les tests.
abstract class SensorStore {
  Future<List<Sensor>> load();

  Future<void> save(List<Sensor> pSensors);
}

/// Stockage en mémoire, pour les tests.
class MemorySensorStore implements SensorStore {
  MemorySensorStore([List<Sensor>? pSensors]) : saved = pSensors ?? [];

  List<Sensor> saved;

  @override
  Future<List<Sensor>> load() async => saved;

  @override
  Future<void> save(List<Sensor> pSensors) async => saved = pSensors;
}
