import '../logic/alert_history.dart';
import '../logic/alerts.dart';
import '../logic/reminders.dart';
import '../logic/scenarios.dart';
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
  // Les entretiens échus voyagent avec les alertes : même historique, mêmes heures silencieuses
  final vAlerts = [
    ...pAlerts,
    ...dueReminderAlerts(await pFiles.loadReminders(), pNow),
    ...airingAlerts(await pFiles.airingUntil(), pNow),
  ];
  if (vAlerts.isEmpty) {
    return const [];
  }
  await pFiles.saveAlertHistory(appendAlerts(await pFiles.loadAlertHistory(), vAlerts, pNow));
  final rAudible = audibleAlerts(vAlerts, pNow, await pFiles.quietHours());
  await pNotifier.show(rAudible);

  return rAudible;
}
