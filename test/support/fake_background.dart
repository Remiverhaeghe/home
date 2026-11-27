import 'package:home/background/background_control.dart';

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
}
