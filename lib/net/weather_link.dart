import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../logic/house.dart';
import '../logic/reading.dart';
import '../logic/weather.dart';

class WeatherException implements Exception {
  const WeatherException(this.message);

  final String message;

  @override
  String toString() => 'WeatherException: $message';
}

/// Liaison avec le service météo ; remplacée par une fausse dans les tests.
abstract interface class WeatherLink {
  Future<List<Reading>> fetch(HouseLocation pLocation, {int pPastDays = 7});
}

/// HTTPS vers le seul serveur météo : l'adresse est construite par [weatherUri], qui n'accepte
/// que ce serveur, et seules les coordonnées de la maison partent.
class HttpWeatherLink implements WeatherLink {
  static const _timeout = Duration(seconds: 15);

  @override
  Future<List<Reading>> fetch(HouseLocation pLocation, {int pPastDays = 7}) async {
    final vClient = HttpClient()..connectionTimeout = _timeout;
    try {
      final vRequest = await vClient
          .getUrl(weatherUri(pLocation, pPastDays: pPastDays))
          .timeout(_timeout);
      final vResponse = await vRequest.close().timeout(_timeout);
      if (vResponse.statusCode != 200) {
        throw WeatherException('code ${vResponse.statusCode}');
      }
      final vText = await vResponse.transform(utf8.decoder).join().timeout(_timeout);
      final vReadings = parseWeather(vText, pNow: DateTime.now());
      if (vReadings.isEmpty) {
        throw const WeatherException('réponse inattendue');
      }

      return vReadings;
    } on SocketException {
      throw const WeatherException('injoignable');
    } on HandshakeException {
      throw const WeatherException('injoignable');
    } on TimeoutException {
      throw const WeatherException('injoignable');
    } finally {
      vClient.close(force: true);
    }
  }
}
