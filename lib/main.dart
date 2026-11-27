import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'background/background_control.dart';
import 'net/daikin_link.dart';
import 'state/ac_controller.dart';
import 'state/sensors_controller.dart';
import 'storage/ac_store.dart';
import 'storage/background_files.dart';
import 'storage/file_sensor_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  final vFolder = await getApplicationDocumentsDirectory();
  final vController = SensorsController(FileSensorStore(File('${vFolder.path}/capteurs.json')));
  await vController.load();
  final vAc = AcController(
    FileAcStore(File('${vFolder.path}/climatisations.json')),
    HttpDaikinLink(),
  );
  await vAc.load();
  runApp(
    HomeApp(
      controller: vController,
      acController: vAc,
      background: ForegroundBackgroundControl(),
      files: BackgroundFiles(vFolder),
    ),
  );
}
