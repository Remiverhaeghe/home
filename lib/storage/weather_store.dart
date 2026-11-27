import 'dart:io';

import '../logic/reading.dart';
import '../logic/weather.dart';

/// Où vit l'archive météo : un fichier sur le téléphone, ou la mémoire dans les tests.
abstract class WeatherStore {
  Future<({bool enabled, List<Reading> readings})> load();

  Future<void> save({required bool pEnabled, required List<Reading> pReadings});
}

class MemoryWeatherStore implements WeatherStore {
  MemoryWeatherStore({this.enabled = false, List<Reading>? readings}) : readings = readings ?? [];

  bool enabled;
  List<Reading> readings;

  @override
  Future<({bool enabled, List<Reading> readings})> load() async =>
      (enabled: enabled, readings: readings);

  @override
  Future<void> save({required bool pEnabled, required List<Reading> pReadings}) async {
    enabled = pEnabled;
    readings = pReadings;
  }
}

/// Fichier `meteo.json`, écrit sans risque de fichier à moitié écrit.
class FileWeatherStore implements WeatherStore {
  FileWeatherStore(this.file);

  final File file;

  @override
  Future<({bool enabled, List<Reading> readings})> load() async => await file.exists()
      ? parseWeatherFile(await file.readAsString())
      : (enabled: false, readings: <Reading>[]);

  @override
  Future<void> save({required bool pEnabled, required List<Reading> pReadings}) async {
    final vTemp = File('${file.path}.tmp');
    await vTemp.writeAsString(weatherJson(pEnabled: pEnabled, pReadings: pReadings), flush: true);
    await vTemp.rename(file.path);
  }
}
