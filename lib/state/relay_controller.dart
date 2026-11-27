import 'package:flutter/foundation.dart';

import '../logic/daikin.dart' show isPrivateAddress;
import '../logic/relay.dart';
import '../net/relay_link.dart';
import '../storage/relay_store.dart';

/// Ce qui empêche d'ajouter un bouton.
enum RelayAddProblem { emptyName, notPrivate }

/// Résultat d'un appui.
enum PressResult { sent, tooSoon, failed }

/// Délai minimal entre deux appuis sur le même bouton : un double toucher ne doit pas ouvrir puis
/// refermer une porte.
const pressLockout = Duration(seconds: 5);

/// Boutons à relais de la maison et leurs commandes.
class RelayController extends ChangeNotifier {
  RelayController(this._store, this._link, {DateTime Function() clock = DateTime.now})
    : _clock = clock;

  final RelayStore _store;
  final RelayLink _link;
  final DateTime Function() _clock;
  List<RelayButton> _buttons = [];
  final _lastPress = <String, DateTime>{};

  List<RelayButton> get buttons => List.unmodifiable(_buttons);

  Future<void> load() async {
    _buttons = await _store.load();
    notifyListeners();
  }

  /// Ajoute un bouton. Renvoie le motif du refus, null si c'est fait.
  Future<RelayAddProblem?> add(RelayButton pButton) async {
    if (pButton.name.trim().isEmpty) {
      return RelayAddProblem.emptyName;
    }
    final vHost = pButton.host.trim();
    if (!isPrivateAddress(vHost)) {
      return RelayAddProblem.notPrivate;
    }
    _buttons = [
      ..._buttons,
      RelayButton(
        name: pButton.name.trim(),
        host: vHost,
        kind: pButton.kind,
        model: pButton.model,
        channel: pButton.channel,
        pulseSeconds: pButton.pulseSeconds.clamp(1, maxPulseSeconds),
      ),
    ];
    await _store.save(_buttons);
    notifyListeners();

    return null;
  }

  Future<void> remove(RelayButton pButton) async {
    _buttons = [
      for (final vButton in _buttons)
        if (!identical(vButton, pButton)) vButton,
    ];
    _lastPress.remove(_keyOf(pButton));
    await _store.save(_buttons);
    notifyListeners();
  }

  static String _keyOf(RelayButton pButton) =>
      '${pButton.host}/${pButton.model.name}/${pButton.channel}';

  /// Envoie l'impulsion, sauf si le même bouton vient d'être pressé.
  Future<PressResult> press(RelayButton pButton) async {
    final vNow = _clock();
    final vLast = _lastPress[_keyOf(pButton)];
    if (vLast != null && vNow.difference(vLast) < pressLockout) {
      return PressResult.tooSoon;
    }
    try {
      await _link.pulse(pButton);
    } on RelayException {
      return PressResult.failed;
    }
    _lastPress[_keyOf(pButton)] = vNow;

    return PressResult.sent;
  }
}
