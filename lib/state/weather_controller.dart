import 'package:flutter/foundation.dart';

import '../logic/house.dart';
import '../logic/reading.dart';
import '../logic/weather.dart';
import '../net/weather_link.dart';
import '../storage/weather_store.dart';

/// Issue d'une récupération.
enum WeatherResult { done, disabled, noLocation, failed }

/// Délai minimal entre deux récupérations automatiques.
const weatherRefreshEvery = Duration(hours: 1);

/// Météo extérieure : l'autorisation d'aller sur Internet (refusée au départ), l'archive des
/// relevés et leur récupération.
class WeatherController extends ChangeNotifier {
  WeatherController(this._store, this._link, {DateTime Function() clock = DateTime.now})
    : _clock = clock;

  final WeatherStore _store;
  final WeatherLink _link;
  final DateTime Function() _clock;
  var _enabled = false;
  var _readings = <Reading>[];
  DateTime? _lastFetch;

  /// Home n'interroge le service météo que si l'utilisateur l'a autorisé.
  bool get enabled => _enabled;
  List<Reading> get readings => List.unmodifiable(_readings);
  DateTime? get lastFetch => _lastFetch;

  Future<void> load() async {
    final vSaved = await _store.load();
    _enabled = vSaved.enabled;
    _readings = vSaved.readings;
    notifyListeners();
  }

  Future<void> setEnabled({required bool pEnabled}) async {
    _enabled = pEnabled;
    await _store.save(pEnabled: _enabled, pReadings: _readings);
    notifyListeners();
  }

  /// Récupère les relevés. Sans [pForce], rien ne part si la dernière récupération date de moins
  /// d'une heure.
  Future<WeatherResult> refresh(HouseLocation? pLocation, {bool pForce = false}) async {
    if (!_enabled) {
      return WeatherResult.disabled;
    }
    if (pLocation == null) {
      return WeatherResult.noLocation;
    }
    final vLast = _lastFetch;
    if (!pForce && vLast != null && _clock().difference(vLast) < weatherRefreshEvery) {
      return WeatherResult.done;
    }
    // Premier appel : un mois ; ensuite, le temps manquant depuis le dernier relevé gardé
    final vDays = _readings.isEmpty
        ? 30
        : (_clock().difference(_readings.last.at).inDays + 2).clamp(2, 92);
    try {
      final vNew = await _link.fetch(pLocation, pPastDays: vDays);
      _readings = mergeWeather(_readings, vNew);
      _lastFetch = _clock();
      await _store.save(pEnabled: _enabled, pReadings: _readings);
    } on WeatherException {
      return WeatherResult.failed;
    } finally {
      notifyListeners();
    }

    return WeatherResult.done;
  }

  String get csv => weatherCsv(_readings);
}
