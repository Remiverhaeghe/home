import 'package:home/logic/relay.dart';
import 'package:home/net/relay_link.dart';

/// Relais de test : les impulsions reçues, et une panne à volonté.
class FakeRelayLink implements RelayLink {
  final pulses = <RelayButton>[];
  var fail = false;

  @override
  Future<void> pulse(RelayButton pButton) async {
    if (fail) {
      throw const RelayException('injoignable');
    }
    pulses.add(pButton);
  }
}
