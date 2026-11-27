import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'readings_task.dart';

/// Service d'arrière-plan qui relève les capteurs suivis ; remplacé par un faux dans les tests.
abstract interface class BackgroundControl {
  Future<bool> isRunning();

  /// Démarre le service après l'accord pour les notifications. Renvoie false si l'accord est
  /// refusé ou si le service ne démarre pas.
  Future<bool> start({required String pTitle, required String pText});

  Future<void> stop();
}

/// Service de premier plan Android : une notification discrète reste affichée, et le système ne
/// coupe pas l'appli pendant qu'elle relève les capteurs.
class ForegroundBackgroundControl implements BackgroundControl {
  static const _serviceId = 2711;

  /// Intervalle entre deux relevés : assez rare pour ménager la pile, assez fréquent pour des
  /// courbes utiles.
  static const _interval = Duration(minutes: 5);

  void _init() => FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'releves_capteurs',
      channelName: 'Relevés des capteurs',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(_interval.inMilliseconds),
      autoRunOnBoot: false,
      allowWakeLock: true,
    ),
  );

  @override
  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  @override
  Future<bool> start({required String pTitle, required String pText}) async {
    var vPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (vPermission != NotificationPermission.granted) {
      vPermission = await FlutterForegroundTask.requestNotificationPermission();
    }
    if (vPermission != NotificationPermission.granted) {
      return false;
    }
    _init();
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }
    final vResult = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: pTitle,
      notificationText: pText,
      callback: readingsTaskStart,
    );

    return vResult is ServiceRequestSuccess;
  }

  @override
  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}
