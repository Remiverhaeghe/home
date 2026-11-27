import 'dart:async';

import 'package:home/logic/daikin.dart';
import 'package:home/net/daikin_link.dart';

/// Climatisation de test : un état modifiable, les commandes reçues, et des pannes à volonté.
class FakeDaikinLink implements DaikinLink {
  final states = <String, DaikinState>{};
  final names = <String, String>{};
  final written = <(String, DaikinControl)>[];
  final found = <String>[];
  final unreachable = <String>{};
  var refuseWrites = false;

  static DaikinState coolingAt22() => const DaikinState(
    control: DaikinControl(
      power: true,
      modeCode: '3',
      setpoint: '22.0',
      humidity: '0',
      fanRate: 'A',
      fanDirection: '0',
    ),
    sensors: DaikinSensors(indoorTemp: 23.5, outdoorTemp: 8, indoorHumidity: null),
  );

  @override
  Future<DaikinInfo> info(String pHost) async {
    if (unreachable.contains(pHost) || !names.containsKey(pHost)) {
      throw const DaikinException('injoignable');
    }

    return DaikinInfo(name: names[pHost]!, mac: 'AABBCCDDEEFF');
  }

  @override
  Future<DaikinState> read(String pHost) async {
    if (unreachable.contains(pHost) || !states.containsKey(pHost)) {
      throw const DaikinException('injoignable');
    }

    return states[pHost]!;
  }

  @override
  Future<void> write(String pHost, DaikinControl pControl) async {
    if (refuseWrites) {
      throw const DaikinException('PARAM NG');
    }
    written.add((pHost, pControl));
    states[pHost] = DaikinState(control: pControl, sensors: states[pHost]!.sensors);
  }

  @override
  Stream<String> discover() => Stream.fromIterable(found);
}

/// Appareil en mode sec : la consigne est `M`.
class DaikinStateDry {
  static DaikinState build() => const DaikinState(
    control: DaikinControl(
      power: true,
      modeCode: '2',
      setpoint: 'M',
      humidity: '0',
      fanRate: 'A',
      fanDirection: '0',
    ),
    sensors: DaikinSensors(indoorTemp: 24),
  );
}
