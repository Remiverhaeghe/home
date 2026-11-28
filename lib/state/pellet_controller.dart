import 'package:flutter/foundation.dart';

import '../logic/daikin.dart' show isPrivateAddress;
import '../logic/pellet.dart';
import '../logic/pellet_runs.dart';
import '../logic/vacation.dart';
import '../net/pellet_link.dart';
import '../storage/pellet_runs_store.dart';
import '../storage/pellet_store.dart';

/// Ce qui empêche d'enregistrer le poêle.
enum PelletSetupProblem { emptyName, notPrivate, noLogin }

/// Résultat d'une commande.
enum PelletResult { done, failed, refused }

/// Poêle à pellets de la maison : état lu, marche et arrêt, consigne.
class PelletController extends ChangeNotifier {
  PelletController(
    this._store,
    this._link, {
    PelletRunsStore? runsStore,
    DateTime Function() clock = DateTime.now,
  }) : _runsStore = runsStore ?? MemoryPelletRunsStore(),
       _clock = clock;

  final PelletStore _store;
  final PelletLink _link;
  final PelletRunsStore _runsStore;
  final DateTime Function() _clock;
  var _runs = const PelletRuns();
  PelletStove? _stove;
  PelletState? _state;
  var _failed = false;
  var _commandedOff = false;
  DateTime? _unexpectedStopAt;

  PelletStove? get stove => _stove;

  /// Heures de marche relevées et débit donné par l'utilisateur.
  PelletRuns get runs => _runs;
  PelletState? get state => _state;

  /// Le dernier relevé n'a pas abouti.
  bool get failed => _failed;

  /// Heure à laquelle le poêle s'est arrêté sans ordre de Home (plus de pellets, fin de programme,
  /// défaut), tant qu'il n'a pas été rallumé ; null sinon.
  DateTime? get unexpectedStopAt => _unexpectedStopAt;

  Future<void> load() async {
    _stove = await _store.load();
    _runs = await _runsStore.load();
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
    final vWasOn = _state?.isOn ?? false;
    try {
      _state = await _link.read(vStove);
      _failed = false;
      final vNow = _clock();
      if (_state!.isOn) {
        _commandedOff = false;
        _unexpectedStopAt = null;
      } else if (vWasOn && !_commandedOff) {
        _unexpectedStopAt = vNow;
      }
      _runs = _runs.record(vNow, pOn: _state!.isOn);
      await _runsStore.save(_runs);
    } on PelletException {
      _failed = true;
    }
    notifyListeners();
  }

  /// Relit le poêle et l'éteint pendant les vacances s'il marche. Renvoie true s'il marche encore
  /// à la fin, ce que le plan utilise pour ne pas lancer la clim en même temps sans besoin.
  Future<bool> refreshAndStopIfAway(VacationMode? pVacation, DateTime pNow) async {
    await refresh();
    final vOn = !failed && (state?.isOn ?? false);
    final vMustStop =
        stoveMustStop(pVacation, pNow, pStoveOn: vOn) || (vOn && _runs.shouldStopNow(pNow));
    if (vMustStop && await setPower(pOn: false) == PelletResult.done) {
      return false;
    }

    return vOn;
  }

  Future<PelletResult> setPower({required bool pOn}) async {
    // Un arrêt demandé par Home n'est pas un arrêt inattendu
    if (!pOn) {
      _commandedOff = true;
    }
    final vResult = await _command((pStove) => _link.setPower(pStove, pOn: pOn));
    if (!pOn && vResult != PelletResult.done) {
      _commandedOff = false;
    }

    return vResult;
  }

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

  /// Range le débit de pellets (kg par heure de marche, null pour l'effacer) le poids et le prix d'un sac.
  /// Range le nombre de sacs en stock à cet instant ; null efface le stock.
  Future<void> setStock(double? pBags) async {
    _runs = _runs.withStock(pBags, _clock());
    await _runsStore.save(_runs);
    notifyListeners();
  }

  /// Règle l'heure d'arrêt programmé, en minutes depuis minuit ; null la retire.
  Future<void> setStopAt(int? pMinute) async {
    _runs = _runs.withStopAt(pMinute);
    await _runsStore.save(_runs);
    notifyListeners();
  }

  Future<void> setFlow({
    required double? pKgPerHour,
    required double pBagKg,
    double? pBagPrice,
  }) async {
    _runs = _runs.withFlow(pKgPerHour: pKgPerHour, pBagKg: pBagKg, pBagPrice: pBagPrice);
    await _runsStore.save(_runs);
    notifyListeners();
  }
}
