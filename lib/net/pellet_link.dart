import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../logic/pellet.dart';
import 'local_network.dart';

class PelletException implements Exception {
  const PelletException(this.message);

  final String message;

  @override
  String toString() => 'PelletException: $message';
}

/// Liaison avec le poêle ; remplacée par une fausse dans les tests.
abstract interface class PelletLink {
  Future<PelletState> read(PelletStove pStove);

  Future<void> setPower(PelletStove pStove, {required bool pOn});

  Future<void> setTarget(PelletStove pStove, double pCelsius);
}

/// HTTPS sur le réseau local. Le poêle présente un certificat auto-signé : il n'est accepté que
/// pour l'adresse déjà vérifiée comme privée, jamais pour un autre serveur.
class HttpsPelletLink implements PelletLink {
  static const _timeout = Duration(seconds: 5);

  Future<String> _post(PelletStove pStove, String pBody) async {
    final Uri vUri;
    try {
      vUri = pelletUri(pStove);
    } on FormatException {
      throw const PelletException('adresse hors du réseau de la maison');
    }
    if (!await requestLocalNetworkAccess()) {
      throw const PelletException('accès au réseau local refusé');
    }
    final vClient = HttpClient()
      ..connectionTimeout = _timeout
      ..badCertificateCallback = (pCert, pHost, pPort) => pHost == pStove.host;
    try {
      final vRequest = await vClient.postUrl(vUri).timeout(_timeout);
      final vLogin = base64.encode(utf8.encode('${pStove.serial}:${pStove.password}'));
      vRequest.headers
        ..set(HttpHeaders.authorizationHeader, 'Basic $vLogin')
        ..contentType = ContentType.text;
      vRequest.write(pBody);
      final vResponse = await vRequest.close().timeout(_timeout);
      final vText = await vResponse.transform(utf8.decoder).join().timeout(_timeout);
      if (vResponse.statusCode == 401) {
        throw const PelletException('identifiants refusés');
      }
      if (vResponse.statusCode != 200) {
        throw PelletException('code ${vResponse.statusCode}');
      }

      return vText;
    } on SocketException {
      throw const PelletException('injoignable');
    } on HandshakeException {
      throw const PelletException('injoignable');
    } on TimeoutException {
      throw const PelletException('injoignable');
    } finally {
      vClient.close(force: true);
    }
  }

  @override
  Future<PelletState> read(PelletStove pStove) async {
    final vState = PelletState.parse(await _post(pStove, pelletReadBody));
    if (vState == null) {
      throw const PelletException('réponse incomplète');
    }

    return vState;
  }

  @override
  Future<void> setPower(PelletStove pStove, {required bool pOn}) async {
    await _post(pStove, pelletPowerBody(pOn: pOn));
  }

  @override
  Future<void> setTarget(PelletStove pStove, double pCelsius) async {
    await _post(pStove, pelletTargetBody(pCelsius));
  }
}
