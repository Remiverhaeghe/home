import 'package:home/logic/pellet.dart';
import 'package:home/net/pellet_link.dart';

/// Poêle de test : un état à volonté, les ordres reçus et une panne à volonté.
class FakePelletLink implements PelletLink {
  var state = const PelletState(
    isOn: false,
    phase: PelletPhase.off,
    code: 0,
    roomC: 18.5,
    targetC: 20,
    powerLevel: 3,
  );
  var fail = false;
  final powers = <bool>[];
  final targets = <double>[];

  @override
  Future<PelletState> read(PelletStove pStove) async {
    if (fail) {
      throw const PelletException('injoignable');
    }

    return state;
  }

  @override
  Future<void> setPower(PelletStove pStove, {required bool pOn}) async {
    if (fail) {
      throw const PelletException('injoignable');
    }
    powers.add(pOn);
    state = PelletState(
      isOn: pOn,
      phase: pOn ? PelletPhase.running : PelletPhase.off,
      code: pOn ? 7 : 0,
      roomC: state.roomC,
      targetC: state.targetC,
      powerLevel: state.powerLevel,
    );
  }

  @override
  Future<void> setTarget(PelletStove pStove, double pCelsius) async {
    if (fail) {
      throw const PelletException('injoignable');
    }
    targets.add(pCelsius);
    state = PelletState(
      isOn: state.isOn,
      phase: state.phase,
      code: state.code,
      roomC: state.roomC,
      targetC: pCelsius,
      powerLevel: state.powerLevel,
    );
  }
}
