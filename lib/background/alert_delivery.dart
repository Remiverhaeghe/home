import '../logic/alert_history.dart';
import '../logic/alerts.dart';
import '../storage/background_files.dart';
import 'alert_notifier.dart';

/// Note les alertes dans l'historique, puis notifie celles qui ont le droit de sonner à cette
/// heure. Rend la liste notifiée. Commun à l'appli et au service d'arrière-plan.
Future<List<SensorAlert>> deliverAlerts({
  required BackgroundFiles pFiles,
  required AlertNotifier pNotifier,
  required List<SensorAlert> pAlerts,
  required DateTime pNow,
}) async {
  if (pAlerts.isEmpty) {
    return const [];
  }
  await pFiles.saveAlertHistory(appendAlerts(await pFiles.loadAlertHistory(), pAlerts, pNow));
  final rAudible = audibleAlerts(pAlerts, pNow, await pFiles.quietHours());
  await pNotifier.show(rAudible);

  return rAudible;
}
