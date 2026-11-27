import 'dart:convert';

/// Une climatisation connue de Home : son nom, son adresse sur le réseau de la maison et, si elle
/// est reliée, le nom du capteur de la même pièce.
class AcUnit {
  const AcUnit({required this.name, required this.host, this.sensorName});

  final String name;
  final String host;
  final String? sensorName;

  AcUnit withSensor(String? pSensorName) => AcUnit(name: name, host: host, sensorName: pSensorName);
}

/// Version du fichier `climatisations.json`.
const acUnitsVersion = 1;

/// Fichier des climatisations. Une entrée sans nom ou sans adresse est ignorée.
List<AcUnit> parseAcUnits(String pJson) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pJson);
  } on FormatException {
    return [];
  }
  if (vRoot is! Map<String, dynamic> || vRoot['version'] != acUnitsVersion) {
    return [];
  }
  final vList = vRoot['units'];
  final rUnits = <AcUnit>[];
  if (vList is List) {
    for (final vEntry in vList) {
      if (vEntry is! Map<String, dynamic>) {
        continue;
      }
      final vName = vEntry['name'];
      final vHost = vEntry['host'];
      final vSensor = vEntry['sensor'];
      if (vName is String && vName.trim().isNotEmpty && vHost is String && vHost.isNotEmpty) {
        rUnits.add(
          AcUnit(name: vName, host: vHost, sensorName: vSensor is String ? vSensor : null),
        );
      }
    }
  }

  return rUnits;
}

String acUnitsJson(List<AcUnit> pUnits) => const JsonEncoder.withIndent('  ').convert({
  'version': acUnitsVersion,
  'units': [
    for (final vUnit in pUnits)
      {
        'name': vUnit.name,
        'host': vUnit.host,
        if (vUnit.sensorName != null) 'sensor': vUnit.sensorName,
      },
  ],
});
