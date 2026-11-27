/// Boutons à relais Wi-Fi : porte de garage, Velux à radio simple, tout contact sec.
library;

import 'dart:convert';

import 'daikin.dart' show isPrivateAddress;

/// Ce que commande le bouton ; sert à l'icône et à la confirmation.
enum RelayKind { garage, velux, other }

/// Boîtier Shelly qui reçoit l'ordre. Les deux générations parlent HTTP sur le réseau local.
enum RelayModel { shellyGen2, shellyGen1 }

/// Un bouton de Home branché sur une sortie de relais, en parallèle du bouton ou de la
/// télécommande d'origine : un appui de [pulseSeconds] secondes, puis le relais retombe.
class RelayButton {
  const RelayButton({
    required this.name,
    required this.host,
    this.kind = RelayKind.other,
    this.model = RelayModel.shellyGen2,
    this.channel = 0,
    this.pulseSeconds = 1,
  });

  final String name;
  final String host;
  final RelayKind kind;
  final RelayModel model;

  /// Numéro de la sortie sur le boîtier, à partir de 0.
  final int channel;
  final int pulseSeconds;

  /// La porte de garage ne bouge jamais sans que l'on confirme.
  bool get needsConfirmation => kind == RelayKind.garage;
}

/// Plus longue impulsion acceptée : au-delà, un relais resté collé ferait autre chose qu'un appui.
const maxPulseSeconds = 10;

/// Adresse web de l'impulsion. Lève une [FormatException] si l'adresse n'est pas celle du réseau de
/// la maison : Home n'envoie rien hors de la maison.
Uri relayRequest(RelayButton pButton) {
  if (!isPrivateAddress(pButton.host)) {
    throw const FormatException('adresse hors du réseau de la maison');
  }
  final vSeconds = pButton.pulseSeconds.clamp(1, maxPulseSeconds);

  return switch (pButton.model) {
    RelayModel.shellyGen2 => Uri(
      scheme: 'http',
      host: pButton.host,
      path: '/rpc/Switch.Set',
      queryParameters: {
        'id': '${pButton.channel}',
        'on': 'true',
        'toggle_after': '$vSeconds',
      },
    ),
    RelayModel.shellyGen1 => Uri(
      scheme: 'http',
      host: pButton.host,
      path: '/relay/${pButton.channel}',
      queryParameters: {'turn': 'on', 'timer': '$vSeconds'},
    ),
  };
}

/// Version du fichier `relais.json`.
const relayFileVersion = 1;

T _byName<T extends Enum>(List<T> pValues, Object? pName, T pFallback) {
  for (final vValue in pValues) {
    if (vValue.name == pName) {
      return vValue;
    }
  }

  return pFallback;
}

/// Fichier des boutons. Une entrée sans nom ou sans adresse est ignorée ; les valeurs inconnues
/// reprennent le réglage par défaut.
List<RelayButton> parseRelays(String pJson) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pJson);
  } on FormatException {
    return [];
  }
  if (vRoot is! Map<String, dynamic> || vRoot['version'] != relayFileVersion) {
    return [];
  }
  final vList = vRoot['buttons'];
  final rButtons = <RelayButton>[];
  if (vList is List) {
    for (final vEntry in vList) {
      if (vEntry is! Map<String, dynamic>) {
        continue;
      }
      final vName = vEntry['name'];
      final vHost = vEntry['host'];
      final vChannel = vEntry['channel'];
      final vPulse = vEntry['pulse'];
      if (vName is String && vName.trim().isNotEmpty && vHost is String && vHost.isNotEmpty) {
        rButtons.add(
          RelayButton(
            name: vName,
            host: vHost,
            kind: _byName(RelayKind.values, vEntry['kind'], RelayKind.other),
            model: _byName(RelayModel.values, vEntry['model'], RelayModel.shellyGen2),
            channel: vChannel is int && vChannel >= 0 ? vChannel : 0,
            pulseSeconds: vPulse is int ? vPulse.clamp(1, maxPulseSeconds) : 1,
          ),
        );
      }
    }
  }

  return rButtons;
}

String relaysJson(List<RelayButton> pButtons) => const JsonEncoder.withIndent('  ').convert({
  'version': relayFileVersion,
  'buttons': [
    for (final vButton in pButtons)
      {
        'name': vButton.name,
        'host': vButton.host,
        'kind': vButton.kind.name,
        'model': vButton.model.name,
        'channel': vButton.channel,
        'pulse': vButton.pulseSeconds,
      },
  ],
});
