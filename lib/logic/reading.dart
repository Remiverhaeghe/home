/// Un relevé d'un thermo-hygromètre : date, température en °C et humidité en %.
class Reading {
  const Reading({required this.at, required this.temp, required this.humidity});

  final DateTime at;
  final double temp;
  final double humidity;
}

/// Un capteur et ses relevés, du plus ancien au plus récent.
class Sensor {
  const Sensor({required this.name, this.readings = const [], this.label});

  /// Identifiant du capteur (celui de l'appareil ou du fichier d'échange) ; ne change jamais, les
  /// pièces, climatisations et règles s'y rattachent.
  final String name;

  /// Nom donné par l'utilisateur pour savoir où il se trouve (« Chambre des enfants »). Rangé à
  /// part, jamais dans le fichier d'échange.
  final String? label;

  /// Ce que l'écran affiche : le nom donné, sinon l'identifiant.
  String get title => label ?? name;

  Sensor withLabel(String? pLabel) => Sensor(name: name, readings: readings, label: pLabel);

  final List<Reading> readings;

  /// Dernier relevé, null tant que le capteur n'en a envoyé aucun.
  Reading? get last => readings.isEmpty ? null : readings.last;
}
