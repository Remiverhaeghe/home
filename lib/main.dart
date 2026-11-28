import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'background/alert_notifier.dart';
import 'background/background_control.dart';
import 'logic/error_log.dart';
import 'net/daikin_link.dart';
import 'net/pellet_link.dart';
import 'net/weather_link.dart';
import 'net/relay_link.dart';
import 'state/ac_controller.dart';
import 'state/plan_controller.dart';
import 'state/house_controller.dart';
import 'state/appearance_controller.dart';
import 'state/notes_controller.dart';
import 'state/pellet_controller.dart';
import 'state/weather_controller.dart';
import 'state/relay_controller.dart';
import 'state/sensors_controller.dart';
import 'storage/ac_runs_store.dart';
import 'storage/error_log_store.dart';
import 'storage/ac_store.dart';
import 'storage/appearance_store.dart';
import 'storage/backup_files.dart';
import 'storage/background_files.dart';
import 'storage/file_sensor_store.dart';
import 'storage/house_store.dart';
import 'storage/label_store.dart';
import 'storage/plan_store.dart';
import 'storage/notes_store.dart';
import 'storage/pellet_runs_store.dart';
import 'storage/pellet_store.dart';
import 'storage/weather_store.dart';
import 'storage/relay_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  final vFolder = await getApplicationDocumentsDirectory();
  final vErrors = FileErrorLogStore(File('${vFolder.path}/journal-erreurs.txt'));
  // Les erreurs vont dans un journal local, jamais sur Internet
  final vPreviousHandler = FlutterError.onError;
  FlutterError.onError = (pDetails) {
    unawaited(vErrors.append(errorEntry(DateTime.now(), pDetails.exception, pDetails.stack)));
    vPreviousHandler?.call(pDetails);
  };
  PlatformDispatcher.instance.onError = (pError, pStack) {
    unawaited(vErrors.append(errorEntry(DateTime.now(), pError, pStack)));

    return true;
  };
  final vController = SensorsController(
    FileSensorStore(File('${vFolder.path}/capteurs.json')),
    FileLabelStore(File('${vFolder.path}/noms-capteurs.json')),
  );
  await vController.load();
  final vAc = AcController(
    FileAcStore(File('${vFolder.path}/climatisations.json')),
    HttpDaikinLink(),
    runsStore: FileAcRunsStore(File('${vFolder.path}/marche-clims.json')),
  );
  await vAc.load();
  final vPlan = PlanController(FilePlanStore(vFolder), vAc, vController);
  await vPlan.load();
  final vRelays = RelayController(
    FileRelayStore(File('${vFolder.path}/relais.json')),
    HttpRelayLink(),
  );
  await vRelays.load();
  final vPellet = PelletController(
    FilePelletStore(File('${vFolder.path}/poele.json')),
    HttpsPelletLink(),
    runsStore: FilePelletRunsStore(File('${vFolder.path}/marche-poele.json')),
  );
  await vPellet.load();
  final vHouse = HouseController(FileHouseStore(File('${vFolder.path}/maison.json')));
  await vHouse.load();
  final vWeather = WeatherController(
    FileWeatherStore(File('${vFolder.path}/meteo.json')),
    HttpWeatherLink(),
  );
  await vWeather.load();
  final vLook = AppearanceController(FileAppearanceStore(File('${vFolder.path}/apparence.json')));
  await vLook.load();
  final vNotes = NotesController(FileNotesStore(File('${vFolder.path}/notes.json')));
  await vNotes.load();
  // Sans autorisation ou sans lieu, rien ne part ; au plus une récupération par heure
  unawaited(vWeather.refresh(vHouse.house.location));
  final vNotifier = LocalAlertNotifier();
  await vNotifier.requestPermission();
  runApp(
    HomeApp(
      controller: vController,
      acController: vAc,
      planController: vPlan,
      relayController: vRelays,
      pelletController: vPellet,
      errorLog: vErrors,
      houseController: vHouse,
      weatherController: vWeather,
      backupFiles: BackupFiles(vFolder),
      appearance: vLook,
      notes: vNotes,
      onRestored: () async {
        await vController.load();
        await vAc.load();
        await vPlan.load();
        await vRelays.load();
        await vPellet.load();
        await vHouse.load();
        await vWeather.load();
        await vLook.load();
        await vNotes.load();
      },
      notifier: vNotifier,
      background: ForegroundBackgroundControl(),
      files: BackgroundFiles(vFolder),
    ),
  );
}
