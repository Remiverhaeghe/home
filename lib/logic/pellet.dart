/// Poêle à pellets Ecoforest : lecture de l'état, marche et arrêt, consigne de température.
library;

import 'dart:convert';

import 'daikin.dart' show isPrivateAddress;

/// Port du serveur du poêle sur le réseau de la maison (HTTPS à certificat auto-signé).
const pelletPort = 8000;

/// Bornes de la consigne de température de la pièce, par pas de 0,5 °C.
const pelletMinTarget = 10.0;
const pelletMaxTarget = 30.0;

/// Poêle enregistré : l'identifiant est le numéro de série, le mot de passe les huit premiers
/// caractères de celui de l'étiquette du poêle.
class PelletStove {
  const PelletStove({
    required this.name,
    required this.host,
    required this.serial,
    required this.password,
  });

  final String name;
  final String host;
  final String serial;
  final String password;
}

/// Ce que dit le poêle, d'après le champ `estado`. Seuls l'arrêt (0) et la marche (7) sont connus
/// avec certitude ; les étapes intermédiaires gardent leur numéro.
enum PelletPhase { off, running, other }

class PelletState {
  const PelletState({
    required this.isOn,
    required this.phase,
    required this.code,
    required this.roomC,
    required this.targetC,
    required this.powerLevel,
  });

  /// Lit la réponse `clé=valeur`, une par ligne. Renvoie null si l'état ou les températures
  /// manquent : une réponse incomplète ne doit pas passer pour un poêle éteint.
  static PelletState? parse(String pText) {
    final vValues = <String, String>{};
    for (final vLine in const LineSplitter().convert(pText)) {
      final vIndex = vLine.indexOf('=');
      if (vIndex > 0) {
        vValues[vLine.substring(0, vIndex).trim()] = vLine.substring(vIndex + 1).trim();
      }
    }
    final vOnOff = int.tryParse(vValues['on_off'] ?? '');
    final vCode = int.tryParse(vValues['estado'] ?? '');
    final vRoom = double.tryParse(vValues['temperatura'] ?? '');
    final vTarget = double.tryParse(vValues['consigna_temperatura'] ?? '');
    if (vOnOff == null || vCode == null || vRoom == null || vTarget == null) {
      return null;
    }

    return PelletState(
      isOn: vOnOff == 1,
      phase: switch (vCode) {
        0 => PelletPhase.off,
        7 => PelletPhase.running,
        _ => PelletPhase.other,
      },
      code: vCode,
      roomC: vRoom,
      targetC: vTarget,
      powerLevel: int.tryParse(vValues['consigna_potencia'] ?? ''),
    );
  }

  final bool isOn;
  final PelletPhase phase;
  final int code;
  final double roomC;
  final double targetC;

  /// Niveau de puissance demandé, lu seulement.
  final int? powerLevel;
}

/// Corps de la requête d'état.
const pelletReadBody = 'idOperacion=1002';

/// Corps de la requête de marche (true) ou d'arrêt (false).
String pelletPowerBody({required bool pOn}) => 'idOperacion=1013&on_off=${pOn ? 1 : 0}';

/// Corps de la requête de consigne, ramenée aux bornes et au demi-degré le plus proche.
String pelletTargetBody(double pCelsius) =>
    'idOperacion=1019&temperatura=${pelletClampTarget(pCelsius).toStringAsFixed(1)}';

double pelletClampTarget(double pCelsius) =>
    ((pCelsius * 2).round() / 2).clamp(pelletMinTarget, pelletMaxTarget);

/// Adresse du serveur du poêle. Lève une [FormatException] hors du réseau de la maison.
Uri pelletUri(PelletStove pStove) {
  if (!isPrivateAddress(pStove.host)) {
    throw const FormatException('adresse hors du réseau de la maison');
  }

  return Uri(scheme: 'https', host: pStove.host, port: pelletPort, path: '/recepcion_datos_4.cgi');
}

/// Fichier `poele.json` : version 1, un seul poêle.
String pelletJson(PelletStove? pStove) => jsonEncode({
  'version': 1,
  'stove': pStove == null
      ? null
      : {
          'name': pStove.name,
          'host': pStove.host,
          'serial': pStove.serial,
          'password': pStove.password,
        },
});

PelletStove? parsePellet(String pText) {
  try {
    final vRoot = jsonDecode(pText);
    final vStove = vRoot is Map<String, dynamic> ? vRoot['stove'] : null;
    if (vStove is! Map<String, dynamic>) {
      return null;
    }
    final vName = vStove['name'];
    final vHost = vStove['host'];
    final vSerial = vStove['serial'];
    final vPassword = vStove['password'];
    if (vName is! String || vHost is! String || vSerial is! String || vPassword is! String) {
      return null;
    }

    return PelletStove(name: vName, host: vHost, serial: vSerial, password: vPassword);
  } on FormatException {
    return null;
  }
}
