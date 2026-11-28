import 'dart:io';

import '../logic/home_widget.dart';
import '../logic/pending_readings.dart';
import '../logic/rooms.dart';
import '../storage/background_files.dart';
import '../storage/file_sensor_store.dart';
import '../storage/house_store.dart';

/// Écrit `widget.json`, que le widget d'écran d'accueil lit. Les capteurs sont ceux du fichier de
/// l'appli plus les relevés en attente, comme pour le résumé du matin. Renvoie false quand aucune
/// pièce n'a de relevé : le fichier n'est alors pas touché.
Future<bool> writeHomeWidget({required Directory pFolder, required DateTime pNow}) async {
  final vSensors = applyPending(
    await FileSensorStore(File('${pFolder.path}/capteurs.json')).load(),
    await BackgroundFiles(pFolder).peekPending(),
  );
  final vHouse = await FileHouseStore(File('${pFolder.path}/maison.json')).load();
  final vRooms = roomStatuses(vSensors, vHouse);
  if (vRooms.isEmpty) {
    return false;
  }
  await File('${pFolder.path}/widget.json').writeAsString(widgetJson(vRooms, pNow), flush: true);

  return true;
}
