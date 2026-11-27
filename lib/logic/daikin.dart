/// Climatiseurs Daikin à module Wi-Fi BRP069 (et BRP072 sans clé), pilotés sur le réseau de la
/// maison. Le format vient d'outils libres écrits à partir de ces modules, pas d'une notice du
/// fabricant : voir `docs/daikin.md` pour ce qui reste à vérifier sur les appareils.
library;

/// Réponse refusée ou illisible.
class DaikinException implements Exception {
  const DaikinException(this.reason);

  final String reason;

  @override
  String toString() => 'DaikinException($reason)';
}

/// Réponse du module : paires `clé=valeur` séparées par des virgules, qui commence par `ret=OK`.
Map<String, String> parseDaikinReply(String pReply) {
  final rValues = <String, String>{};
  for (final vPart in pReply.trim().split(',')) {
    final vAt = vPart.indexOf('=');
    if (vAt > 0) {
      rValues[vPart.substring(0, vAt)] = vPart.substring(vAt + 1);
    }
  }
  if (rValues['ret'] != 'OK') {
    throw DaikinException(rValues['ret'] ?? 'réponse illisible');
  }

  return rValues;
}

/// Mode de fonctionnement lu sur l'appareil.
enum DaikinMode { auto, dry, cool, heat, fan }

/// Mode d'après le code de l'appareil : 0, 1 et 7 sont l'automatique. Null si le code est inconnu.
DaikinMode? daikinModeOf(String pCode) => switch (pCode) {
  '0' || '1' || '7' => DaikinMode.auto,
  '2' => DaikinMode.dry,
  '3' => DaikinMode.cool,
  '4' => DaikinMode.heat,
  '6' => DaikinMode.fan,
  _ => null,
};

/// Code envoyé pour un mode. Seuls les modes à température de consigne sont commandés depuis
/// Home : sec et ventilation affichent `M` et `--` à la place de la consigne.
String? daikinCodeOf(DaikinMode pMode) => switch (pMode) {
  DaikinMode.auto => '0',
  DaikinMode.cool => '3',
  DaikinMode.heat => '4',
  DaikinMode.dry || DaikinMode.fan => null,
};

/// Consigne choisie quand l'appareil n'en a pas (sec ou ventilation) et qu'on passe en froid, chaud
/// ou automatique.
const daikinDefaultSetpoint = 22.0;

/// Plage de consigne acceptée par l'appareil, en °C.
const daikinMinSetpoint = 10.0;
const daikinMaxSetpoint = 32.0;

/// Réglages de l'appareil : les six valeurs que `set_control_info` exige à chaque envoi, même
/// celles qu'on ne change pas.
class DaikinControl {
  const DaikinControl({
    required this.power,
    required this.modeCode,
    required this.setpoint,
    required this.humidity,
    required this.fanRate,
    required this.fanDirection,
  });

  /// Lit la réponse de `get_control_info`.
  factory DaikinControl.parse(String pReply) {
    final vValues = parseDaikinReply(pReply);
    final vPower = vValues['pow'];
    final vMode = vValues['mode'];
    final vSetpoint = vValues['stemp'];
    final vHumidity = vValues['shum'];
    final vRate = vValues['f_rate'];
    final vDirection = vValues['f_dir'];
    if (vPower == null ||
        vMode == null ||
        vSetpoint == null ||
        vHumidity == null ||
        vRate == null ||
        vDirection == null) {
      throw const DaikinException('réglages incomplets');
    }

    return DaikinControl(
      power: vPower == '1',
      modeCode: vMode,
      setpoint: vSetpoint,
      humidity: vHumidity,
      fanRate: vRate,
      fanDirection: vDirection,
    );
  }

  final bool power;
  final String modeCode;

  /// Consigne telle que l'appareil la donne : un nombre, `M` en sec, `--` en ventilation.
  final String setpoint;
  final String humidity;
  final String fanRate;
  final String fanDirection;

  DaikinMode? get mode => daikinModeOf(modeCode);

  /// Consigne en °C, null quand l'appareil n'en affiche pas.
  double? get setpointDegrees => double.tryParse(setpoint);

  DaikinControl copyWith({bool? power, String? modeCode, String? setpoint}) => DaikinControl(
    power: power ?? this.power,
    modeCode: modeCode ?? this.modeCode,
    setpoint: setpoint ?? this.setpoint,
    humidity: humidity,
    fanRate: fanRate,
    fanDirection: fanDirection,
  );

  /// Paramètres de `set_control_info`, tous présents.
  String toQuery() =>
      'pow=${power ? 1 : 0}&mode=$modeCode&stemp=$setpoint&shum=$humidity'
      '&f_rate=$fanRate&f_dir=$fanDirection';

  /// Même appareil avec le mode demandé. Null si Home ne commande pas ce mode. Quand l'appareil n'a
  /// pas de consigne (sec, ventilation), une consigne par défaut est envoyée.
  DaikinControl? withMode(DaikinMode pMode) {
    final vCode = daikinCodeOf(pMode);
    if (vCode == null) {
      return null;
    }

    return copyWith(
      modeCode: vCode,
      setpoint: setpointDegrees == null ? daikinDefaultSetpoint.toStringAsFixed(1) : setpoint,
    );
  }

  /// Même appareil avec une autre consigne, ramenée à la plage acceptée et au demi-degré. Null
  /// quand le mode n'a pas de consigne.
  DaikinControl? withSetpoint(double pDegrees) {
    if (setpointDegrees == null) {
      return null;
    }
    final vClamped = pDegrees.clamp(daikinMinSetpoint, daikinMaxSetpoint);
    final vHalf = (vClamped * 2).round() / 2;

    return copyWith(setpoint: vHalf.toStringAsFixed(1));
  }
}

/// Mesures du module : température intérieure et extérieure, humidité intérieure si l'appareil
/// en a une.
class DaikinSensors {
  const DaikinSensors({this.indoorTemp, this.outdoorTemp, this.indoorHumidity});

  /// Lit la réponse de `get_sensor_info`. `-` et `--` veulent dire « pas de mesure ».
  factory DaikinSensors.parse(String pReply) {
    final vValues = parseDaikinReply(pReply);

    return DaikinSensors(
      indoorTemp: double.tryParse(vValues['htemp'] ?? ''),
      outdoorTemp: double.tryParse(vValues['otemp'] ?? ''),
      indoorHumidity: double.tryParse(vValues['hhum'] ?? ''),
    );
  }

  final double? indoorTemp;
  final double? outdoorTemp;
  final double? indoorHumidity;
}

/// État complet d'un appareil, lu en deux requêtes.
class DaikinState {
  const DaikinState({required this.control, required this.sensors});

  final DaikinControl control;
  final DaikinSensors sensors;
}

/// Identité du module, lue dans `basic_info`.
class DaikinInfo {
  const DaikinInfo({required this.name, required this.mac});

  /// Lit la réponse de `basic_info`. Le nom est encodé comme une adresse web.
  factory DaikinInfo.parse(String pReply) {
    final vValues = parseDaikinReply(pReply);
    final vRawName = vValues['name'] ?? '';
    String vName;
    try {
      vName = Uri.decodeComponent(vRawName);
    } on FormatException {
      vName = vRawName;
    }

    return DaikinInfo(name: vName, mac: vValues['mac'] ?? '');
  }

  final String name;
  final String mac;
}

/// Adresse IPv4 d'un réseau privé (10.x, 172.16 à 172.31, 192.168.x) : Home ne parle qu'aux
/// appareils de la maison, jamais à une adresse d'Internet.
bool isPrivateAddress(String pHost) {
  final vParts = pHost.trim().split('.');
  if (vParts.length != 4) {
    return false;
  }
  final vNumbers = <int>[];
  for (final vPart in vParts) {
    final vNumber = int.tryParse(vPart);
    if (vNumber == null || vNumber < 0 || vNumber > 255 || vPart != '$vNumber') {
      return false;
    }
    vNumbers.add(vNumber);
  }

  return vNumbers[0] == 10 ||
      (vNumbers[0] == 172 && vNumbers[1] >= 16 && vNumbers[1] <= 31) ||
      (vNumbers[0] == 192 && vNumbers[1] == 168);
}
