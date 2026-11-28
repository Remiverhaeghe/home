import 'package:flutter/foundation.dart';

import '../ble/tp357_link.dart';
import '../logic/climate_exchange.dart';
import '../logic/pending_readings.dart';
import '../logic/periods.dart';
import '../logic/reading.dart';
import '../logic/sensor_log.dart';
import '../logic/sensor_merge.dart';
import '../storage/label_store.dart';
import '../storage/sensor_store.dart';

/// Capteurs affichés par l'appli, et import d'un fichier d'échange.
class SensorsController extends ChangeNotifier {
  SensorsController(this._store, [LabelStore? pLabels])
    : _labelStore = pLabels ?? MemoryLabelStore();

  final SensorStore _store;
  final LabelStore _labelStore;
  Map<String, String> _labels = {};
  List<Sensor> _sensors = [];
  ExchangeProblem? _problem;

  /// Les capteurs avec le nom que l'utilisateur leur a donné.
  List<Sensor> get sensors =>
      List.unmodifiable([for (final vSensor in _sensors) vSensor.withLabel(_labels[vSensor.name])]);

  /// Donne un nom à un capteur, par exemple l'endroit où il se trouve. Un nom vide le retire.
  Future<void> rename(String pSensorName, String pLabel) async {
    final vLabel = pLabel.trim();
    _labels = {..._labels};
    if (vLabel.isEmpty || vLabel == pSensorName) {
      _labels.remove(pSensorName);
    } else {
      _labels[pSensorName] = vLabel;
    }
    await _labelStore.save(_labels);
    notifyListeners();
  }

  /// Dernier problème d'import, null si le dernier import s'est bien passé.
  ExchangeProblem? get problem => _problem;

  Future<void> load() async {
    _sensors = await _store.load();
    _labels = await _labelStore.load();
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

  /// Range des relevés (un export ThermoPro) dans le capteur [pSensorName], créé s'il n'existe pas ;
  /// un relevé à la même date est remplacé. Renvoie le nombre de relevés rangés.
  Future<int> importReadings(String pSensorName, List<Reading> pReadings) async {
    _sensors = mergeSensors(_sensors, [Sensor(name: pSensorName, readings: pReadings)]);
    await _store.save(_sensors);
    notifyListeners();

    return pReadings.length;
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

  /// Déplace les relevés de la période [pFrom] à [pTo] du capteur [pSensorName] vers le capteur
  /// [pNewName], créé s'il n'existe pas : un capteur qui a changé de pièce devient un capteur par
  /// pièce. Refuse (false) un nom vide ou identique, un capteur inconnu, une période sans relevé
  /// ou qui est tout le capteur.
  Future<bool> splitPeriod(
    String pSensorName,
    DateTime pFrom,
    DateTime pTo,
    String pNewName,
  ) async {
    final vName = pNewName.trim();
    final vSource = _sensors.where((pSensor) => pSensor.name == pSensorName).firstOrNull;
    if (vSource == null || vName.isEmpty || vName.toLowerCase() == pSensorName.toLowerCase()) {
      return false;
    }
    final vSplit = separatePeriod(vSource.readings, pFrom, pTo);
    if (vSplit.moved.isEmpty || vSplit.kept.isEmpty) {
      return false;
    }
    final vRest = Sensor(name: vSource.name, readings: vSplit.kept);
    _sensors = mergeSensors(
      [for (final vSensor in _sensors) vSensor.name == vSource.name ? vRest : vSensor],
      [Sensor(name: vName, readings: vSplit.moved)],
    );
    await _store.save(_sensors);
    notifyListeners();

    return true;
  }

  /// Cherche les capteurs à portée pendant [pScan], puis lit une mesure sur chacun (au plus [pWait]
  /// d'attente) et la range. Renvoie le nombre de capteurs lus.
  Future<int> refreshFromBluetooth(
    Tp357Link pLink, {
    Duration pScan = const Duration(seconds: 6),
    Duration pWait = const Duration(seconds: 20),
  }) async {
    final vDevices = await pLink
        .scan()
        .timeout(pScan, onTimeout: (pSink) => pSink.close())
        .toList();
    final vResults = await Future.wait([
      for (final vDevice in vDevices) _readOnce(pLink, vDevice, pWait),
    ]);

    return vResults.where((pRead) => pRead).length;
  }

  Future<bool> _readOnce(Tp357Link pLink, Tp357Device pDevice, Duration pWait) async {
    try {
      final vValue = await pLink.live(pDevice.id).first.timeout(pWait);
      await addLiveReading(
        pDevice.name,
        Reading(at: DateTime.now(), temp: vValue.temp, humidity: vValue.humidity),
      );

      return true;
    } on Object {
      // Capteur sorti de portée ou occupé par l'appli du fabricant : on passe au suivant
      return false;
    }
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
