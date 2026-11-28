import 'dart:io';

import '../logic/alerts.dart';
import '../logic/pending_readings.dart';
import '../net/daikin_link.dart';
import '../net/pellet_link.dart';
import '../state/ac_controller.dart';
import '../state/pellet_controller.dart';
import '../state/plan_controller.dart';
import '../state/sensors_controller.dart';
import '../storage/ac_runs_store.dart';
import '../storage/ac_store.dart';
import '../storage/background_files.dart';
import '../storage/detail_log.dart';
import '../storage/file_sensor_store.dart';
import '../storage/pellet_runs_store.dart';
import '../storage/pellet_store.dart';
import '../storage/plan_store.dart';
import '../storage/sensor_store.dart';

/// Au-delà de ce délai sans signe de l'appli, le service applique le plan à sa place.
const appOpenWindow = Duration(minutes: 7);

/// Applique le plan depuis le service d'arrière-plan, appli fermée. Les capteurs sont ceux du
/// fichier de l'appli plus les relevés en attente, que l'appli rangera à sa prochaine ouverture.
/// Garde ses contrôleurs d'un tour à l'autre : les délais entre commandes et les alertes déjà
/// signalées se retiennent.
class PlanRunner {
  PlanRunner({required Directory pFolder, required DaikinLink pLink, PelletLink? pPelletLink})
    : _files = BackgroundFiles(pFolder),
      _sensorFile = FileSensorStore(File('${pFolder.path}/capteurs.json')),
      _sensorStore = MemorySensorStore() {
    _sensors = SensorsController(_sensorStore);
    _ac = AcController(
      FileAcStore(File('${pFolder.path}/climatisations.json')),
      pLink,
      runsStore: FileAcRunsStore(File('${pFolder.path}/marche-clims.json')),
    );
    _plan = PlanController(FilePlanStore(pFolder), _ac, _sensors);
    if (pPelletLink != null) {
      _pellet = PelletController(
        FilePelletStore(File('${pFolder.path}/poele.json')),
        pPelletLink,
        runsStore: FilePelletRunsStore(File('${pFolder.path}/marche-poele.json')),
      );
    }
  }

  final BackgroundFiles _files;
  final FileSensorStore _sensorFile;
  final MemorySensorStore _sensorStore;
  late final SensorsController _sensors;
  late final AcController _ac;
  late final PlanController _plan;
  PelletController? _pellet;

  /// Un tour : renvoie les alertes apparues, ou une liste vide quand l'appli est ouverte (c'est
  /// elle qui applique alors le plan).
  Future<List<SensorAlert>> run(DateTime pNow, {DetailLog? pDetail}) async {
    if (await _files.isAppOpen(pNow, appOpenWindow)) {
      await pDetail?.note('plan', 'appli ouverte : le plan reste à l\'appli');

      return [];
    }
    _sensorStore.saved = applyPending(await _sensorFile.load(), await _files.peekPending());
    await _sensors.load();
    await _ac.load();
    await _plan.load();
    _plan.watched = {for (final vDevice in await _files.loadFollowed()) vDevice.name};
    final vPellet = _pellet;
    if (vPellet != null) {
      await vPellet.load();
      _plan.stoveRunning = await vPellet.refreshAndStopIfAway(_plan.vacation, pNow);
    }
    await _ac.refresh();

    final vAlerts = await _plan.tick(pNow);
    await pDetail?.note('plan', 'plan appliqué, ${vAlerts.length} alerte(s)');

    return vAlerts;
  }
}
