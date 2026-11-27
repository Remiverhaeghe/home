import 'package:flutter/foundation.dart';

import '../logic/daikin.dart' show isPrivateAddress;
import '../logic/pellet.dart';
import '../net/pellet_link.dart';
import '../storage/pellet_store.dart';

/// Ce qui empêche d'enregistrer le poêle.
enum PelletSetupProblem { emptyName, notPrivate, noLogin }

/// Résultat d'une commande.
enum PelletResult { done, failed, refused }

/// Poêle à pellets de la maison : état lu, marche et arrêt, consigne.
class PelletController extends ChangeNotifier {
  PelletController(this._store, this._link);

  final PelletStore _store;
  final PelletLink _link;
  PelletStove? _stove;
  PelletState? _state;
  var _failed = false;

  PelletStove? get stove => _stove;
  PelletState? get state => _state;

  /// Le dernier relevé n'a pas abouti.
  bool get failed => _failed;

  Future<void> load() async {
    _stove = await _store.load();
    notifyListeners();
  }

  /// Enregistre le poêle. Renvoie le motif du refus, null si c'est fait.
  Future<PelletSetupProblem?> setup(PelletStove pStove) async {
    final vHost = pStove.host.trim();
    if (pStove.name.trim().isEmpty) {
      return PelletSetupProblem.emptyName;
    }
    if (!isPrivateAddress(vHost)) {
      return PelletSetupProblem.notPrivate;
    }
    if (pStove.serial.trim().isEmpty || pStove.password.trim().isEmpty) {
      return PelletSetupProblem.noLogin;
    }
    _stove = PelletStove(
      name: pStove.name.trim(),
      host: vHost,
      serial: pStove.serial.trim(),
      password: pStove.password.trim(),
    );
    _state = null;
    _failed = false;
    await _store.save(_stove);
    notifyListeners();

    return null;
  }

  Future<void> remove() async {
    _stove = null;
    _state = null;
    _failed = false;
    await _store.save(null);
    notifyListeners();
  }

  Future<void> refresh() async {
    final vStove = _stove;
    if (vStove == null) {
      return;
    }
    try {
      _state = await _link.read(vStove);
      _failed = false;
    } on PelletException {
      _failed = true;
    }
    notifyListeners();
  }

  Future<PelletResult> setPower({required bool pOn}) =>
      _command((pStove) => _link.setPower(pStove, pOn: pOn));

  Future<PelletResult> setTarget(double pCelsius) =>
      _command((pStove) => _link.setTarget(pStove, pelletClampTarget(pCelsius)));

  Future<PelletResult> _command(Future<void> Function(PelletStove) pSend) async {
    final vStove = _stove;
    if (vStove == null) {
      return PelletResult.refused;
    }
    try {
      await pSend(vStove);
    } on PelletException {
      return PelletResult.failed;
    }
    await refresh();

    return PelletResult.done;
  }
}
