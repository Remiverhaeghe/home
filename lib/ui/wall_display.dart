import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Ce que l'affichage mural demande au téléphone : plein écran, paysage, écran allumé.
abstract class WallDisplay {
  Future<void> enter();

  Future<void> leave();
}

/// Réglages réels de l'appareil.
class PlatformWallDisplay implements WallDisplay {
  @override
  Future<void> enter() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await WakelockPlus.enable();
  }

  @override
  Future<void> leave() async {
    await WakelockPlus.disable();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
}
