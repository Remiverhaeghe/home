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
  static const _sweepTimeout = Duration(milliseconds: 800);
  static const _sweepBatch = 48;

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
    final vLocals = await _localAddresses();
    final vSeen = <String>{...vLocals};
    // Diffusion UDP d'abord, puis balayage du réseau pour les box qui la bloquent
    await for (final vHost in _discoverUdp(vLocals, vSeen)) {
      yield vHost;
    }
    await for (final vHost in _discoverBySweep(vLocals, vSeen)) {
      yield vHost;
    }
  }

  /// Adresses IPv4 de réseau privé du téléphone.
  Future<List<String>> _localAddresses() async {
    try {
      final vInterfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);

      return [
        for (final vInterface in vInterfaces)
          for (final vAddress in vInterface.addresses)
            if (isPrivateAddress(vAddress.address)) vAddress.address,
      ];
    } on SocketException {
      return const [];
    }
  }

  Stream<String> _discoverUdp(List<String> pLocals, Set<String> pSeen) async* {
    final RawDatagramSocket vSocket;
    try {
      vSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } on SocketException {
      return;
    }
    vSocket.broadcastEnabled = true;
    final vTargets = {
      '255.255.255.255',
      for (final vLocal in pLocals) ?subnetBroadcast(vLocal),
    };
    for (final vTarget in vTargets) {
      try {
        vSocket.send(utf8.encode('DAIKIN_UDP/common/basic_info'), InternetAddress(vTarget), _discoveryPort);
      } on SocketException {
        // Une destination refusée n'empêche pas les autres
      }
    }
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
              pSeen.add(vDatagram.address.address)) {
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

  /// Interroge chaque adresse du réseau de la maison par HTTP, quelques dizaines à la fois.
  Stream<String> _discoverBySweep(List<String> pLocals, Set<String> pSeen) async* {
    final vHosts = <String>{for (final vLocal in pLocals) ...subnetHosts(vLocal)}..removeAll(pSeen);
    final vList = vHosts.toList();
    for (var vStart = 0; vStart < vList.length; vStart += _sweepBatch) {
      final vBatch = vList.skip(vStart).take(_sweepBatch);
      final vFound = await Future.wait(vBatch.map(_isDaikin));
      var vIndex = 0;
      for (final vHost in vBatch) {
        if (vFound[vIndex++] && pSeen.add(vHost)) {
          yield vHost;
        }
      }
    }
  }

  /// Vrai si l'adresse répond comme un module Daikin ; les délais sont courts pour tout balayer.
  Future<bool> _isDaikin(String pHost) async {
    final vClient = HttpClient()..connectionTimeout = _sweepTimeout;
    try {
      final vRequest = await vClient
          .getUrl(Uri.parse('http://$pHost/common/basic_info'))
          .timeout(_sweepTimeout);
      final vResponse = await vRequest.close().timeout(_sweepTimeout);
      if (vResponse.statusCode != 200) {
        return false;
      }
      final vBody = await vResponse.transform(utf8.decoder).join().timeout(_sweepTimeout);

      return vBody.contains('ret=OK');
    } on Object {
      return false;
    } finally {
      vClient.close(force: true);
    }
  }
}
