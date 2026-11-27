import 'package:flutter/foundation.dart';

import '../logic/climate_exchange.dart';
import '../logic/pending_readings.dart';
import '../logic/reading.dart';
import '../logic/sensor_log.dart';
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

  /// Garde une mesure lue en direct sur un capteur, sauf si elle suit de trop près la précédente.
  Future<void> addLiveReading(String pName, Reading pReading) async {
    final vBefore = _sensors;
    _sensors = withLiveReading(_sensors, pName, pReading);
    if (identical(_sensors, vBefore)) {
      return;
    }
    await _store.save(_sensors);
    notifyListeners();
  }

  /// Range les relevés pris en arrière-plan. [pTake] les rend et les retire de leur fichier.
  Future<void> syncPending(Future<List<PendingReading>> Function() pTake) async {
    final vPending = await pTake();
    if (vPending.isEmpty) {
      return;
    }
    final vBefore = _sensors;
    _sensors = applyPending(_sensors, vPending);
    if (identical(_sensors, vBefore)) {
      return;
    }
    await _store.save(_sensors);
    notifyListeners();
  }
}
