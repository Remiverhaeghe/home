import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/thermopro_csv.dart';

const _header =
    '﻿Horodatage pour chaque échantillon de fréquence chaque 1 min\n'
    '﻿Date,Heure,Température_Celsius,Humidité_Relative(%)\n';

void main() {
  test('le nom vient du fichier, sans la date ni les tirets bas', () {
    expect(
      thermoproSensorName('TempProSensor_Export_chambre_parent_28112026.csv'),
      'Chambre parent',
    );
    expect(thermoproSensorName('/tmp/TempProSensor_Export_bureau_28112026.CSV'), 'Bureau');
    expect(thermoproSensorName('mesures_cave.csv'), 'Mesures cave');
    expect(thermoproSensorName('.csv'), 'ThermoPro');
  });

  test('un texte sans en-tête ThermoPro est refusé', () {
    expect(parseThermoproCsv('a,b,c\n1,2,3', 'x.csv'), isNull);
  });

  test('les lignes vides ou illisibles sont comptées et ignorées', () {
    final vCsv = parseThermoproCsv(
      '$_header'
          '﻿19/01/2025,10:31,17.7,35\r\n'
          '﻿19/01/2025,10:45,-,-\r\n'
          '﻿pas une ligne\r\n'
          '\r\n'
          '﻿19/01/2025,11:00,16.3,36\r\n',
      'TempProSensor_Export_bureau_28112026.csv',
    )!;

    expect(vCsv.sensorName, 'Bureau');
    expect(vCsv.skipped, 2);
    expect(vCsv.readings.map((pReading) => pReading.temp), [17.7, 16.3]);
    expect(vCsv.readings.first.at, DateTime(2025, 1, 19, 10, 31));
    expect(vCsv.readings.first.humidity, 35);
  });

  test('un relevé par tranche de dix minutes, trié par date', () {
    final vCsv = parseThermoproCsv(
      '${_header}19/01/2025,10:35,2,50\n'
          '19/01/2025,10:31,1,50\n'
          '19/01/2025,10:32,9,50\n'
          '19/01/2025,10:41,3,50\n',
      'x.csv',
    )!;

    expect(vCsv.readings.map((pReading) => pReading.temp), [1, 3]);

    final vAll = parseThermoproCsv(
      '${_header}19/01/2025,10:31,1,50\n19/01/2025,10:32,2,50\n',
      'x.csv',
      pStepMinutes: 1,
    )!;
    expect(vAll.readings, hasLength(2));
  });
}
