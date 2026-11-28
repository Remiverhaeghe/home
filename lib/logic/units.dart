/// Unités d'affichage des températures. Le code garde toujours des °C ; la conversion se fait
/// seulement au moment d'écrire le texte.
library;

import 'package:intl/intl.dart';

enum TemperatureUnit { celsius, fahrenheit }

class Units {
  Units({this.temperature = TemperatureUnit.celsius, String pLocale = 'fr'})
    : _number = NumberFormat('0.0', pLocale);

  final TemperatureUnit temperature;
  final NumberFormat _number;

  bool get isFahrenheit => temperature == TemperatureUnit.fahrenheit;

  String get symbol => isFahrenheit ? '°F' : '°C';

  /// Une température en °C exprimée dans l'unité choisie.
  double fromCelsius(double pCelsius) => isFahrenheit ? pCelsius * 9 / 5 + 32 : pCelsius;

  /// Un écart de température en °C : seul le facteur change, pas le décalage de 32.
  double deltaFromCelsius(double pCelsius) => isFahrenheit ? pCelsius * 9 / 5 : pCelsius;

  /// « 21,5 °C » ou « 70,7 °F ».
  String temp(double pCelsius) => '${_number.format(fromCelsius(pCelsius))} $symbol';

  /// Le nombre seul, pour un curseur.
  String tempNumber(double pCelsius) => _number.format(fromCelsius(pCelsius));

  /// « +1,5 °C » ou « -0,8 °C » : un écart avec son signe.
  String delta(double pCelsius) {
    final vValue = deltaFromCelsius(pCelsius);

    return '${vValue >= 0 ? '+' : ''}${_number.format(vValue)} $symbol';
  }
}
