import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../logic/alerts.dart';

/// Affiche les alertes sous forme de notifications ; remplacé par un faux dans les tests.
abstract interface class AlertNotifier {
  Future<void> show(List<SensorAlert> pAlerts);

  /// Résumé du matin : une notification discrète, sans son.
  Future<void> showSummary(String pTitle, String pBody);
}

/// Notifications Android avec son et bannière, une par alerte : une alerte qui dure garde la même
/// notification, elle n'en ajoute pas une nouvelle à chaque tour.
class LocalAlertNotifier implements AlertNotifier {
  LocalAlertNotifier() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  var _ready = false;

  Future<void> _init() async {
    if (_ready) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Demande l'accord d'afficher des notifications (Android 13 et plus).
  Future<void> requestPermission() async {
    await _init();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> show(List<SensorAlert> pAlerts) async {
    if (pAlerts.isEmpty) {
      return;
    }
    await _init();
    for (final vAlert in pAlerts) {
      await _plugin.show(
        id: notificationId(vAlert),
        title: alertTitle(vAlert),
        body: alertSummary([vAlert]),
        notificationDetails: NotificationDetails(android: alertChannel(alertLevel(vAlert.kind))),
      );
    }
  }

  @override
  Future<void> showSummary(String pTitle, String pBody) async {
    await _init();
    await _plugin.show(
      id: summaryNotificationId,
      title: pTitle,
      body: pBody,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'resume_maison',
          'Résumé de la maison',
          channelDescription: 'Résumé du matin : pièces fraîches ou humides',
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
    );
  }
}

/// Numéro de la notification du résumé : le résumé du lendemain remplace celui de la veille.
const summaryNotificationId = 1;

/// Numéro stable d'une alerte : la même alerte remplace sa notification.
int notificationId(SensorAlert pAlert) => pAlert.key.hashCode & 0x7fffffff;

/// Titre court de la notification.
String alertTitle(SensorAlert pAlert) => switch (pAlert.kind) {
  AlertKind.frost => 'Risque de gel',
  AlertKind.humidity => 'Humidité haute',
  AlertKind.silent => 'Capteur muet',
  AlertKind.stuck => 'Capteur figé',
  AlertKind.ventilate => 'Aération conseillée',
  AlertKind.maintenance => 'Entretien à faire',
  AlertKind.airing => 'Aération terminée',
};

/// Canal Android de chaque niveau : le critique passe en tête, l'information reste discrète.
AndroidNotificationDetails alertChannel(AlertLevel pLevel) => switch (pLevel) {
  AlertLevel.critical => const AndroidNotificationDetails(
    'alertes_critiques',
    'Alertes critiques',
    channelDescription: 'Risque de gel',
    importance: Importance.max,
    priority: Priority.max,
    onlyAlertOnce: true,
  ),
  AlertLevel.important => const AndroidNotificationDetails(
    'alertes_maison',
    'Alertes de la maison',
    channelDescription: 'Humidité haute, capteur muet ou figé',
    importance: Importance.high,
    priority: Priority.high,
    onlyAlertOnce: true,
  ),
  AlertLevel.info => const AndroidNotificationDetails(
    'alertes_infos',
    'Conseils et entretien',
    channelDescription: 'Aération conseillée, entretien à faire',
    importance: Importance.low,
    priority: Priority.low,
    onlyAlertOnce: true,
  ),
};
