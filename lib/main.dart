import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'background/alert_notifier.dart';
import 'background/background_control.dart';
import 'net/daikin_link.dart';
import 'net/pellet_link.dart';
import 'net/relay_link.dart';
import 'state/ac_controller.dart';
import 'state/plan_controller.dart';
import 'state/house_controller.dart';
import 'state/pellet_controller.dart';
import 'state/relay_controller.dart';
import 'state/sensors_controller.dart';
import 'storage/ac_store.dart';
import 'storage/background_files.dart';
import 'storage/file_sensor_store.dart';
import 'storage/house_store.dart';
import 'storage/label_store.dart';
import 'storage/plan_store.dart';
import 'storage/pellet_store.dart';
import 'storage/relay_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  final vFolder = await getApplicationDocumentsDirectory();
  final vController = SensorsController(
    FileSensorStore(File('${vFolder.path}/capteurs.json')),
    FileLabelStore(File('${vFolder.path}/noms-capteurs.json')),
  );
  await vController.load();
  final vAc = AcController(
    FileAcStore(File('${vFolder.path}/climatisations.json')),
    HttpDaikinLink(),
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
  );
  await vPellet.load();
  final vHouse = HouseController(FileHouseStore(File('${vFolder.path}/maison.json')));
  await vHouse.load();
  final vNotifier = LocalAlertNotifier();
  await vNotifier.requestPermission();
  runApp(
    HomeApp(
      controller: vController,
      acController: vAc,
      planController: vPlan,
      relayController: vRelays,
      pelletController: vPellet,
      houseController: vHouse,
      notifier: vNotifier,
      background: ForegroundBackgroundControl(),
      files: BackgroundFiles(vFolder),
    ),
  );
}
