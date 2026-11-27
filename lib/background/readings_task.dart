import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';

import '../ble/tp357_link.dart';
import '../logic/alerts.dart';
import '../logic/pending_readings.dart';
import '../logic/reading.dart';
import '../net/daikin_link.dart';
import '../storage/background_files.dart';
import 'alert_notifier.dart';
import 'plan_runner.dart';

/// Point d'entrée du service, appelé dans son propre processus Dart.
@pragma('vm:entry-point')
void readingsTaskStart() {
  FlutterForegroundTask.setTaskHandler(ReadingsTaskHandler());
}

/// À chaque tour, se connecte à chaque capteur suivi, attend sa première mesure, l'ajoute au
/// fichier des relevés en attente et se déconnecte. Une connexion courte laisse le capteur libre
/// pour l'appli du fabricant.
class ReadingsTaskHandler extends TaskHandler {
  static const _wait = Duration(seconds: 25);

  final _link = BleTp357Link();
  var _busy = false;

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
  Future<void> _plan(Directory pFolder) async {
    try {
      final vRunner = _runner ??= PlanRunner(pFolder: pFolder, pLink: HttpDaikinLink());
      final vAlerts = await vRunner.run(DateTime.now());
      if (vAlerts.isNotEmpty) {
        await _notifier.show(vAlerts);
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Alerte',
          notificationText: alertSummary(vAlerts),
        );
      }
    } on Object {
      // Réseau de la maison indisponible, fichier en cours d'écriture : tour suivant
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
      for (final vDevice in await vFiles.loadFollowed()) {
        try {
          final vValue = await _link.live(vDevice.id).first.timeout(_wait);
          await vFiles.appendPending(
            pendingLine(
              vDevice.name,
              Reading(at: DateTime.now(), temp: vValue.temp, humidity: vValue.humidity),
            ),
          );
        } on Object {
          // Capteur hors de portée ou Bluetooth coupé : on réessaie au tour suivant
          continue;
        }
      }
      await _plan(vFolder);
    } finally {
      _busy = false;
    }
  }
}
