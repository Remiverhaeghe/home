import 'package:flutter/foundation.dart';

import '../logic/ac_units.dart';
import '../logic/daikin.dart';
import '../net/daikin_link.dart';
import '../storage/ac_store.dart';

/// Ce qui empêche d'ajouter une climatisation.
enum AddProblem { notPrivate, alreadyKnown, unreachable }

/// Dernier état connu d'une climatisation : lu, ou injoignable.
class AcStatus {
  const AcStatus.read(DaikinState this.state) : failed = false;

  const AcStatus.failed() : state = null, failed = true;

  final DaikinState? state;
  final bool failed;
}

/// Climatisations de la maison, leur état et leurs commandes.
class AcController extends ChangeNotifier {
  AcController(this._store, this._link);

  final AcStore _store;
  final DaikinLink _link;
  List<AcUnit> _units = [];
  final _status = <String, AcStatus>{};

  List<AcUnit> get units => List.unmodifiable(_units);

  AcStatus? statusOf(String pHost) => _status[pHost];

  /// Adresses des modules qui répondent sur le réseau de la maison.
  Stream<String> discover() => _link.discover();

  Future<void> load() async {
    _units = await _store.load();
    notifyListeners();
  }

  /// Lit l'état de chaque climatisation, l'une après l'autre : un module ne tient que quelques
  /// connexions à la fois.
  Future<void> refresh() async {
    for (final vUnit in _units) {
      await _read(vUnit.host);
    }
    notifyListeners();
  }

  Future<void> _read(String pHost) async {
    try {
      _status[pHost] = AcStatus.read(await _link.read(pHost));
    } on DaikinException {
      _status[pHost] = const AcStatus.failed();
    }
  }

  /// Ajoute la climatisation qui répond à cette adresse, sous le nom que son module donne (ou
  /// [pName] si l'utilisateur en a choisi un). Renvoie le motif du refus, null si c'est fait.
  Future<AddProblem?> add(String pHost, {String? pName}) async {
    final vHost = pHost.trim();
    if (!isPrivateAddress(vHost)) {
      return AddProblem.notPrivate;
    }
    if (_units.any((pUnit) => pUnit.host == vHost)) {
      return AddProblem.alreadyKnown;
    }
    final DaikinInfo vInfo;
    try {
      vInfo = await _link.info(vHost);
    } on DaikinException {
      return AddProblem.unreachable;
    }
    final vName = (pName?.trim().isNotEmpty ?? false) ? pName!.trim() : vInfo.name;
    _units = [..._units, AcUnit(name: vName.isEmpty ? vHost : vName, host: vHost)];
    await _store.save(_units);
    await _read(vHost);
    notifyListeners();

    return null;
  }

  Future<void> remove(String pHost) async {
    _units = [
      for (final vUnit in _units)
        if (vUnit.host != pHost) vUnit,
    ];
    _status.remove(pHost);
    await _store.save(_units);
    notifyListeners();
  }

  /// Relie la climatisation au capteur de sa pièce, ou la délie avec null.
  Future<void> linkSensor(String pHost, String? pSensorName) async {
    _units = [
      for (final vUnit in _units) vUnit.host == pHost ? vUnit.withSensor(pSensorName) : vUnit,
    ];
    await _store.save(_units);
    notifyListeners();
  }

  /// Envoie les nouveaux réglages puis relit l'appareil. Renvoie false si l'appareil ne répond pas
  /// ou refuse.
  Future<bool> _send(String pHost, DaikinControl? pControl) async {
    if (pControl == null) {
      return false;
    }
    try {
      await _link.write(pHost, pControl);
    } on DaikinException {
      return false;
    } finally {
      await _read(pHost);
      notifyListeners();
    }

    return true;
  }

  /// Envoie des réglages déjà calculés, par exemple ceux du plan. Renvoie false si l'appareil ne
  /// répond pas ou refuse.
  Future<bool> apply(String pHost, DaikinControl pControl) => _send(pHost, pControl);

  DaikinControl? _controlOf(String pHost) => _status[pHost]?.state?.control;

  Future<bool> setPower(String pHost, {required bool pOn}) =>
      _send(pHost, _controlOf(pHost)?.copyWith(power: pOn));

  Future<bool> setMode(String pHost, DaikinMode pMode) =>
      _send(pHost, _controlOf(pHost)?.withMode(pMode));

  Future<bool> setSetpoint(String pHost, double pDegrees) =>
      _send(pHost, _controlOf(pHost)?.withSetpoint(pDegrees));
}
