import 'package:flutter/foundation.dart';

import '../logic/climate_exchange.dart';
import '../logic/reading.dart';
import '../logic/sensor_merge.dart';
import '../storage/sensor_store.dart';

/// Capteurs affichés par l'appli, et import d'un fichier d'échange.
class SensorsController extends ChangeNotifier {
  SensorsController(this._store);

  final SensorStore _store;
  List<Sensor> _sensors = [];
  ExchangeProblem? _problem;

  List<Sensor> get sensors => List.unmodifiable(_sensors);

  /// Dernier problème d'import, null si le dernier import s'est bien passé.
  ExchangeProblem? get problem => _problem;

  Future<void> load() async {
    _sensors = await _store.load();
    notifyListeners();
  }

  /// Ajoute les capteurs d'un fichier d'échange. Renvoie le nombre de capteurs lus, ou null si le
  /// fichier est refusé (le motif est alors dans [problem]).
  Future<int?> importText(String pJson) async {
    final int? rCount;
    try {
      final vIncoming = parseExchange(pJson);
      _sensors = mergeSensors(_sensors, vIncoming);
      await _store.save(_sensors);
      _problem = null;
      rCount = vIncoming.length;
    } on ExchangeException catch (vError) {
      _problem = vError.problem;
      notifyListeners();

      return null;
    }
    notifyListeners();

    return rCount;
  }
}
