import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import '../logic/tp357.dart';

typedef Tp357Device = ({String id, String name});

/// Liaison avec les capteurs TP357 ; remplacée par une fausse dans les tests.
abstract interface class Tp357Link {
  /// Capteurs TP357 à portée.
  Stream<Tp357Device> scan();

  /// Mesures en direct d'un capteur, tant qu'on écoute.
  Stream<TempHumidity> live(String pDeviceId);

  /// Trames brutes de l'historique d'une période, pour l'écran de diagnostic.
  Stream<List<int>> rawHistory(String pDeviceId, HistoryPeriod pPeriod);
}

/// Bluetooth basse consommation du téléphone, après l'accord de l'utilisateur.
class BleTp357Link implements Tp357Link {
  final _aBle = FlutterReactiveBle();

  /// Reçoit une phrase à chaque étape d'une connexion (état, abonnement, trames), pour le journal
  /// détaillé : sans elle, un délai dépassé ne dit pas où la connexion s'est arrêtée.
  void Function(String pStep)? onTrace;

  Future<bool> _allowed() async {
    final vStatus = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // Android 11 et avant : la recherche Bluetooth passe par la localisation
      Permission.locationWhenInUse,
    ].request();

    return vStatus[Permission.bluetoothConnect] != PermissionStatus.permanentlyDenied &&
        vStatus[Permission.bluetoothScan] != PermissionStatus.permanentlyDenied;
  }

  @override
  Stream<Tp357Device> scan() async* {
    if (!await _allowed()) {
      return;
    }
    final vSeen = <String>{};
    await for (final vDevice in _aBle.scanForDevices(withServices: const [])) {
      if (isTp357Name(vDevice.name) && vSeen.add(vDevice.id)) {
        yield (id: vDevice.id, name: vDevice.name);
      }
    }
  }

  /// Caractéristique du capteur portant cet identifiant. Le service qui la contient n'est pas
  /// connu à l'avance : on le lit sur le capteur.
  Future<QualifiedCharacteristic?> _find(String pDeviceId, String pUuid) async {
    final vTarget = Uuid.parse(pUuid);
    await _aBle.discoverAllServices(pDeviceId);
    for (final vService in await _aBle.getDiscoveredServices(pDeviceId)) {
      for (final vCharacteristic in vService.characteristics) {
        if (vCharacteristic.id == vTarget) {
          return QualifiedCharacteristic(
            serviceId: vService.id,
            characteristicId: vTarget,
            deviceId: pDeviceId,
          );
        }
      }
    }

    return null;
  }

  /// Trames reçues d'un capteur connecté ; [pOnReady] part une fois abonné.
  Stream<List<int>> _frames(String pDeviceId, Future<void> Function(String pDeviceId) pOnReady) {
    late final StreamController<List<int>> rController;
    StreamSubscription<ConnectionStateUpdate>? vConnection;
    StreamSubscription<List<int>>? vFrames;
    var vStarted = false;
    rController = StreamController<List<int>>(
      onListen: () {
        onTrace?.call('connexion lancée');
        vConnection = _aBle.connectToDevice(id: pDeviceId).listen((pUpdate) async {
          onTrace?.call('connexion : ${pUpdate.connectionState.name}');
          if (pUpdate.connectionState != DeviceConnectionState.connected || vStarted) {
            return;
          }
          // Marqué tout de suite : une deuxième mise à jour ne doit pas rouvrir l'abonnement
          vStarted = true;
          final vNotify = await _find(pDeviceId, tp357NotifyCharacteristic);
          onTrace?.call(
            vNotify == null ? 'caractéristique introuvable' : 'caractéristique trouvée, abonnement',
          );
          if (vNotify == null) {
            rController.addError(StateError('Caractéristique du TP357 introuvable'));
            return;
          }
          vFrames = _aBle
              .subscribeToCharacteristic(vNotify)
              .listen((pFrame) {
                onTrace?.call('trame de ${pFrame.length} octets');
                rController.add(pFrame);
              }, onError: rController.addError);
          await pOnReady(pDeviceId);
        }, onError: (Object pError) {
          onTrace?.call('connexion en erreur : ${pError.runtimeType}');
          rController.addError(pError);
        });
      },
      onCancel: () async {
        await vFrames?.cancel();
        await vConnection?.cancel();
      },
    );

    return rController.stream;
  }

  @override
  Stream<TempHumidity> live(String pDeviceId) => _frames(
    pDeviceId,
    (_) async {},
  ).map(parseLiveFrame).where((pValue) => pValue != null).cast<TempHumidity>();

  @override
  Stream<List<int>> rawHistory(String pDeviceId, HistoryPeriod pPeriod) =>
      _frames(pDeviceId, (pId) async {
        final vWrite = await _find(pId, tp357WriteCharacteristic);
        if (vWrite == null) {
          throw StateError('Caractéristique d\'écriture du TP357 introuvable');
        }
        await _aBle.writeCharacteristicWithResponse(vWrite, value: historyRequest(pPeriod));
      });
}
