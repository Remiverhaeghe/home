import 'dart:io';

import '../logic/alerts.dart';
import '../logic/pending_readings.dart';
import '../net/daikin_link.dart';
import '../state/ac_controller.dart';
import '../state/plan_controller.dart';
import '../state/sensors_controller.dart';
import '../storage/ac_store.dart';
import '../storage/background_files.dart';
import '../storage/file_sensor_store.dart';
import '../storage/plan_store.dart';
import '../storage/sensor_store.dart';

/// Au-delà de ce délai sans signe de l'appli, le service applique le plan à sa place.
const appOpenWindow = Duration(minutes: 7);

/// Applique le plan depuis le service d'arrière-plan, appli fermée. Les capteurs sont ceux du
/// fichier de l'appli plus les relevés en attente, que l'appli rangera à sa prochaine ouverture.
/// Garde ses contrôleurs d'un tour à l'autre : les délais entre commandes et les alertes déjà
/// signalées se retiennent.
class PlanRunner {
  PlanRunner({required Directory pFolder, required DaikinLink pLink})
    : _files = BackgroundFiles(pFolder),
      _sensorFile = FileSensorStore(File('${pFolder.path}/capteurs.json')),
      _sensorStore = MemorySensorStore() {
    _sensors = SensorsController(_sensorStore);
    _ac = AcController(FileAcStore(File('${pFolder.path}/climatisations.json')), pLink);
    _plan = PlanController(FilePlanStore(pFolder), _ac, _sensors);
  }

  final BackgroundFiles _files;
  final FileSensorStore _sensorFile;
  final MemorySensorStore _sensorStore;
  late final SensorsController _sensors;
  late final AcController _ac;
  late final PlanController _plan;

  /// Un tour : renvoie les alertes apparues, ou une liste vide quand l'appli est ouverte (c'est
  /// elle qui applique alors le plan).
  Future<List<SensorAlert>> run(DateTime pNow) async {
    if (await _files.isAppOpen(pNow, appOpenWindow)) {
      return [];
    }
    _sensorStore.saved = applyPending(await _sensorFile.load(), await _files.peekPending());
    await _sensors.load();
    await _ac.load();
    await _plan.load();
    _plan.watched = {for (final vDevice in await _files.loadFollowed()) vDevice.name};
    await _ac.refresh();

    return _plan.tick(pNow);
  }
}
