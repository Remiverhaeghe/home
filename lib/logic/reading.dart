/// Un relevé d'un thermo-hygromètre : date, température en °C et humidité en %.
class Reading {
  const Reading({required this.at, required this.temp, required this.humidity});

  final DateTime at;
  final double temp;
  final double humidity;
}

/// Un capteur et ses relevés, du plus ancien au plus récent.
class Sensor {
  const Sensor({required this.name, this.readings = const []});

  final String name;
  final List<Reading> readings;

  /// Dernier relevé, null tant que le capteur n'en a envoyé aucun.
  Reading? get last => readings.isEmpty ? null : readings.last;
}
