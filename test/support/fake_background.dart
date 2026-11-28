import 'package:home/background/alert_notifier.dart';
import 'package:home/background/background_control.dart';
import 'package:home/logic/alerts.dart';

/// Service d'arrière-plan de test : il note ce qu'on lui demande.
class FakeBackgroundControl implements BackgroundControl {
  var running = false;
  var allowed = true;
  var starts = 0;
  var stops = 0;
  String? lastTitle;
  String? lastText;

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<bool> start({required String pTitle, required String pText}) async {
    starts++;
    lastTitle = pTitle;
    lastText = pText;
    running = allowed;

    return allowed;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  var ignoringBattery = false;
  var allowBatteryRequest = true;
  var batteryRequests = 0;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => ignoringBattery;

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async {
    batteryRequests++;
    ignoringBattery = allowBatteryRequest;

    return ignoringBattery;
  }
}

/// Notifications de test : elles notent les alertes montrées.
class FakeAlertNotifier implements AlertNotifier {
  final shown = <List<SensorAlert>>[];
  final summaries = <String>[];

  @override
  Future<void> show(List<SensorAlert> pAlerts) async => shown.add(pAlerts);

  @override
  Future<void> showSummary(String pTitle, String pBody) async => summaries.add('$pTitle|$pBody');
}
