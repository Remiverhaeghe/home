import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../logic/daikin.dart';
import 'local_network.dart';

/// Liaison avec les climatisations ; remplacée par une fausse dans les tests.
abstract interface class DaikinLink {
  Future<DaikinInfo> info(String pHost);

  Future<DaikinState> read(String pHost);

  Future<void> write(String pHost, DaikinControl pControl);

  /// Adresses des modules qui répondent sur le réseau de la maison.
  Stream<String> discover();
}

/// HTTP sur le réseau local, sans aucun envoi hors de la maison : les adresses sont vérifiées
/// avant chaque requête.
class HttpDaikinLink implements DaikinLink {
  static const _timeout = Duration(seconds: 4);
  static const _discoveryPort = 30050;
  static const _discoveryWindow = Duration(seconds: 4);

  Future<String> _get(String pHost, String pPath) async {
    if (!isPrivateAddress(pHost)) {
      throw const DaikinException('adresse hors du réseau de la maison');
    }
    if (!await requestLocalNetworkAccess()) {
      throw const DaikinException('accès au réseau local refusé');
    }
    final vClient = HttpClient()..connectionTimeout = _timeout;
    try {
      final vRequest = await vClient.getUrl(Uri.parse('http://$pHost$pPath')).timeout(_timeout);
      final vResponse = await vRequest.close().timeout(_timeout);
      if (vResponse.statusCode != 200) {
        throw DaikinException('code ${vResponse.statusCode}');
      }

      return await vResponse.transform(utf8.decoder).join().timeout(_timeout);
    } on SocketException {
      throw const DaikinException('injoignable');
    } on TimeoutException {
      throw const DaikinException('injoignable');
    } finally {
      vClient.close(force: true);
    }
  }

  @override
  Future<DaikinInfo> info(String pHost) async =>
      DaikinInfo.parse(await _get(pHost, '/common/basic_info'));

  @override
  Future<DaikinState> read(String pHost) async {
    final vControl = DaikinControl.parse(await _get(pHost, '/aircon/get_control_info'));
    final vSensors = DaikinSensors.parse(await _get(pHost, '/aircon/get_sensor_info'));

    return DaikinState(control: vControl, sensors: vSensors);
  }

  @override
  Future<void> write(String pHost, DaikinControl pControl) async {
    parseDaikinReply(await _get(pHost, '/aircon/set_control_info?${pControl.toQuery()}'));
  }

  @override
  Stream<String> discover() async* {
    if (!await requestLocalNetworkAccess()) {
      return;
    }
    final vSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    vSocket.broadcastEnabled = true;
    vSocket.send(
      utf8.encode('DAIKIN_UDP/common/basic_info'),
      InternetAddress('255.255.255.255'),
      _discoveryPort,
    );
    final vSeen = <String>{};
    final vEnd = DateTime.now().add(_discoveryWindow);
    try {
      await for (final vEvent in vSocket.timeout(
        _discoveryWindow,
        onTimeout: (pSink) => pSink.close(),
      )) {
        if (vEvent == RawSocketEvent.read) {
          final vDatagram = vSocket.receive();
          if (vDatagram != null &&
              isPrivateAddress(vDatagram.address.address) &&
              vSeen.add(vDatagram.address.address)) {
            yield vDatagram.address.address;
          }
        }
        if (DateTime.now().isAfter(vEnd)) {
          break;
        }
      }
    } finally {
      vSocket.close();
    }
  }
}
