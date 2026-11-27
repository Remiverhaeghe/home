import 'dart:async';

import 'package:home/ble/tp357_link.dart';
import 'package:home/logic/tp357.dart';

/// Liaison Bluetooth de test : les capteurs et les trames sont poussés à la main.
class FakeTp357Link implements Tp357Link {
  final devices = StreamController<Tp357Device>.broadcast();
  final liveValues = StreamController<TempHumidity>.broadcast();
  final historyFrames = StreamController<List<int>>.broadcast();
  final requested = <(String, HistoryPeriod)>[];

  @override
  Stream<Tp357Device> scan() => devices.stream;

  @override
  Stream<TempHumidity> live(String pDeviceId) => liveValues.stream;

  @override
  Stream<List<int>> rawHistory(String pDeviceId, HistoryPeriod pPeriod) {
    requested.add((pDeviceId, pPeriod));

    return historyFrames.stream;
  }
}
