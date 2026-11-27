import 'dart:async';
import 'dart:io';

import '../logic/relay.dart';
import 'local_network.dart';

/// Le relais n'a pas pris l'ordre.
class RelayException implements Exception {
  const RelayException(this.message);

  final String message;

  @override
  String toString() => 'RelayException: $message';
}

/// Liaison avec les relais ; remplacée par une fausse dans les tests.
abstract interface class RelayLink {
  /// Envoie l'impulsion du bouton.
  Future<void> pulse(RelayButton pButton);
}

/// HTTP sur le réseau local : l'adresse est vérifiée avant chaque envoi.
class HttpRelayLink implements RelayLink {
  static const _timeout = Duration(seconds: 4);

  @override
  Future<void> pulse(RelayButton pButton) async {
    final Uri vUri;
    try {
      vUri = relayRequest(pButton);
    } on FormatException {
      throw const RelayException('adresse hors du réseau de la maison');
    }
    if (!await requestLocalNetworkAccess()) {
      throw const RelayException('accès au réseau local refusé');
    }
    final vClient = HttpClient()..connectionTimeout = _timeout;
    try {
      final vRequest = await vClient.getUrl(vUri).timeout(_timeout);
      final vResponse = await vRequest.close().timeout(_timeout);
      await vResponse.drain<void>().timeout(_timeout);
      if (vResponse.statusCode != 200) {
        throw RelayException('code ${vResponse.statusCode}');
      }
    } on SocketException {
      throw const RelayException('injoignable');
    } on TimeoutException {
      throw const RelayException('injoignable');
    } finally {
      vClient.close(force: true);
    }
  }
}
