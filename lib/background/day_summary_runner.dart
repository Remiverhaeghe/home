import 'dart:io';

import '../logic/day_summary.dart';
import '../logic/pending_readings.dart';
import '../logic/rooms.dart';
import '../storage/background_files.dart';
import '../storage/file_sensor_store.dart';
import '../storage/house_store.dart';
import 'alert_notifier.dart';

/// Envoie le résumé du matin quand il est voulu, que l'heure est passée et qu'il n'est pas encore
/// parti aujourd'hui. Les capteurs sont ceux du fichier de l'appli plus les relevés en attente.
/// Renvoie true quand un résumé est parti.
Future<bool> sendDaySummaryIfDue({
  required Directory pFolder,
  required DateTime pNow,
  required AlertNotifier pNotifier,
}) async {
  final vFiles = BackgroundFiles(pFolder);
  if (!await vFiles.summaryEnabled() || !summaryDue(pNow, pLastSent: await vFiles.lastSummary())) {
    return false;
  }
  final vSensors = applyPending(
    await FileSensorStore(File('${pFolder.path}/capteurs.json')).load(),
    await vFiles.peekPending(),
  );
  final vHouse = await FileHouseStore(File('${pFolder.path}/maison.json')).load();
  final vSummary = buildDaySummary(roomStatuses(vSensors, vHouse));
  if (vSummary == null) {
    return false;
  }
  await pNotifier.showSummary(vSummary.title, vSummary.body);
  await vFiles.markSummarySent(pNow);

  return true;
}
