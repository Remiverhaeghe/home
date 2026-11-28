import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';

import '../ble/tp357_link.dart';
import '../logic/alerts.dart';
import '../logic/error_log.dart';
import '../logic/pending_readings.dart';
import '../logic/reading.dart';
import '../net/daikin_link.dart';
import '../net/pellet_link.dart';
import '../storage/background_files.dart';
import '../storage/detail_log.dart';
import '../storage/error_log_store.dart';
import 'alert_notifier.dart';
import 'day_summary_runner.dart';
import 'plan_runner.dart';
import 'widget_writer.dart';

/// Point d'entrée du service, appelé dans son propre processus Dart.
@pragma('vm:entry-point')
void readingsTaskStart() {
  FlutterForegroundTask.setTaskHandler(ReadingsTaskHandler());
}

/// À chaque tour, se connecte à chaque capteur suivi, attend sa première mesure, l'ajoute au
/// fichier des relevés en attente et se déconnecte. Une connexion courte laisse le capteur libre
/// pour l'appli du fabricant.
class ReadingsTaskHandler extends TaskHandler {
  static const _wait = Duration(seconds: 30);
  static const _tries = 2;

  final _link = BleTp357Link();
  var _busy = false;
  final _misses = <String, int>{};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_round());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  PlanRunner? _runner;
  final AlertNotifier _notifier = LocalAlertNotifier();

  /// Applique le plan de la maison, puis montre les nouvelles alertes dans la notification du
  /// service. Un échec ici ne doit jamais arrêter les relevés.
  Future<void> _plan(Directory pFolder, DetailLog pDetail) async {
    try {
      final vRunner = _runner ??= PlanRunner(
        pFolder: pFolder,
        pLink: HttpDaikinLink(),
        pPelletLink: HttpsPelletLink(),
      );
      final vAlerts = await vRunner.run(DateTime.now(), pDetail: pDetail);
      if (vAlerts.isNotEmpty) {
        await pDetail.note('plan', '${vAlerts.length} alerte(s) à signaler');
        await _notifier.show(vAlerts);
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Alerte',
          notificationText: alertSummary(vAlerts),
        );
      }
    } on Object catch (pCaught) {
      // Réseau de la maison indisponible, fichier en cours d'écriture : tour suivant
      await pDetail.note('plan', 'échec : ${pCaught.runtimeType}');
    }
  }

  /// Une mesure du capteur, avec une seconde tentative : le Bluetooth manque parfois un tour. Les
  /// tours manqués d'affilée sont comptés et notés au journal, pour comprendre un capteur muet.
  Future<void> _readOne(
    Directory pFolder,
    BackgroundFiles pFiles,
    FollowedDevice pDevice,
    int pRank,
    DetailLog pDetail,
  ) async {
    Object? vError;
    for (var vTry = 0; vTry < _tries; vTry++) {
      try {
        final vStart = DateTime.now();
        _link.onTrace = (pStep) => unawaited(pDetail.note('capteur $pRank', pStep));
        final vValue = await _link.live(pDevice.id).first.timeout(_wait);
        await pFiles.appendPending(
          pendingLine(
            pDevice.name,
            Reading(at: DateTime.now(), temp: vValue.temp, humidity: vValue.humidity),
          ),
        );
        await _recordHealth(pFiles, pDevice.name, pOk: true);
        final vAfter = _misses.remove(pDevice.id);
        await pDetail.note(
          'capteur $pRank',
          'mesure reçue en ${DateTime.now().difference(vStart).inSeconds} s '
              '(essai ${vTry + 1}${vAfter == null ? '' : ', après $vAfter tours manqués'})',
        );

        return;
      } on Object catch (pCaught) {
        // Capteur hors de portée ou Bluetooth coupé : seconde tentative, puis tour suivant
        vError = pCaught;
        await pDetail.note(
          'capteur $pRank',
          'essai ${vTry + 1} sans mesure : ${pCaught.runtimeType}',
        );
      }
    }
    await _recordHealth(pFiles, pDevice.name, pOk: false);
    final vMisses = (_misses[pDevice.id] ?? 0) + 1;
    _misses[pDevice.id] = vMisses;
    if (shouldLogMiss(vMisses)) {
      try {
        await FileErrorLogStore(
          File('${pFolder.path}/journal-erreurs.txt'),
        ).append(backgroundMissEntry(DateTime.now(), pRank, vMisses, vError ?? 'inconnue'));
      } on Object {
        // Le journal ne doit jamais arrêter les relevés
      }
    }
  }

  /// Note le tour dans la santé du relevé ; un échec ici ne doit jamais arrêter les relevés.
  Future<void> _recordHealth(BackgroundFiles pFiles, String pName, {required bool pOk}) async {
    try {
      final vHealth = await pFiles.loadHealth();
      await pFiles.saveHealth(vHealth.record(pName, DateTime.now(), pOk: pOk));
    } on Object {
      // Fichier en cours d'écriture : le tour suivant le notera
    }
  }

  /// Résumé du matin ; un échec ici ne doit jamais arrêter les relevés.
  Future<void> _summary(Directory pFolder, DetailLog pDetail) async {
    try {
      await sendDaySummaryIfDue(pFolder: pFolder, pNow: DateTime.now(), pNotifier: _notifier);
    } on Object catch (pCaught) {
      // Fichier en cours d'écriture : tour suivant
      await pDetail.note('résumé', 'échec : ${pCaught.runtimeType}');
    }
  }

  /// Met à jour le fichier du widget d'écran d'accueil. Un échec ne doit pas arrêter le relevé.
  Future<void> _widget(Directory pFolder, DetailLog pDetail) async {
    try {
      await writeHomeWidget(pFolder: pFolder, pNow: DateTime.now());
    } on Object catch (pCaught) {
      await pDetail.note('widget', 'échec : ${pCaught.runtimeType}');
    }
  }

  Future<void> _round() async {
    // Un tour long ne doit pas se superposer au suivant
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      final vFolder = await getApplicationDocumentsDirectory();
      final vFiles = BackgroundFiles(vFolder);
      final vDetail = FileDetailLog(vFolder);
      final vStart = DateTime.now();
      final vDevices = await vFiles.loadFollowed();
      await vDetail.note('tour', 'début, ${vDevices.length} capteur(s) suivi(s)');
      for (var vRank = 0; vRank < vDevices.length; vRank++) {
        await _readOne(vFolder, vFiles, vDevices[vRank], vRank + 1, vDetail);
      }
      await _plan(vFolder, vDetail);
      await _summary(vFolder, vDetail);
      await _widget(vFolder, vDetail);
      await vDetail.note('tour', 'fin après ${DateTime.now().difference(vStart).inSeconds} s');
    } finally {
      _busy = false;
    }
  }
}
