import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'state/sensors_controller.dart';
import 'storage/file_sensor_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final vFolder = await getApplicationDocumentsDirectory();
  final vController = SensorsController(FileSensorStore(File('${vFolder.path}/capteurs.json')));
  await vController.load();
  runApp(HomeApp(controller: vController));
}
