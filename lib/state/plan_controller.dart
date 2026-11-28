import 'package:flutter/foundation.dart';

import '../logic/alerts.dart';
import '../logic/automations.dart';
import '../logic/comfort.dart';
import '../logic/daikin.dart';
import '../logic/plan.dart';
import '../logic/vacation.dart';
import '../storage/plan_store.dart';
import 'ac_controller.dart';
import 'sensors_controller.dart';

/// Pilotage de la maison : réglages des pièces, des règles et des vacances, et application du plan
/// à chaque passage de [tick].
class PlanController extends ChangeNotifier {
  PlanController(this._store, this._ac, this._sensors);

  /// Capteurs suivis en arrière-plan, seuls à pouvoir être signalés muets ; null avant la première
  /// lecture de la liste, tous sont alors surveillés.
  Set<String>? watched;

  final PlanStore _store;
  final AcController _ac;
  final SensorsController _sensors;
  var _settings = const PlanSettings();
  final _lastRuns = <String, DateTime>{};
  final _windowSince = <String, DateTime>{};
  var _knownAlerts = <String>{};
  var _applied = <PlanCommand>[];

  List<Room> get rooms => _settings.rooms;
  List<AutoRule> get rules => _settings.rules;
  VacationMode? get vacation => _settings.vacation;

  /// Commandes envoyées lors du dernier passage.
  List<PlanCommand> get applied => List.unmodifiable(_applied);

  Room? roomOf(String pHost) => rooms.where((pRoom) => pRoom.acHost == pHost).firstOrNull;

  Future<void> load() async {
    _settings = await _store.load();
    notifyListeners();
  }

  Future<void> _save(PlanSettings pSettings) async {
    _settings = pSettings;
    await _store.save(pSettings);
    notifyListeners();
  }

  /// Enregistre la pièce, qui remplace celle de la même climatisation.
  Future<void> setRoom(Room pRoom) => _save(
    PlanSettings(
      rooms: [
        for (final vRoom in rooms)
          if (vRoom.acHost != pRoom.acHost) vRoom,
        pRoom,
      ],
      rules: rules,
      vacation: vacation,
    ),
  );

  /// Remplace le planning d'une pièce, en gardant ses températures souhaitées.
  Future<void> setSchedule(String pHost, List<ScheduleSlot> pSlots) {
    final vRoom = roomOf(pHost);

    return setRoom(
      Room(acHost: pHost, targets: vRoom?.targets ?? const RoomTargets(), schedule: pSlots),
    );
  }

  Future<void> setRules(List<AutoRule> pRules) =>
      _save(PlanSettings(rooms: rooms, rules: pRules, vacation: vacation));

  /// Règle le mode vacances, ou le retire avec null.
  Future<void> setVacation(VacationMode? pVacation) =>
      _save(PlanSettings(rooms: rooms, rules: rules, vacation: pVacation));

  /// Évalue le plan à l'instant [pNow], envoie les commandes et renvoie les alertes qui viennent
  /// d'apparaître. Les états des climatisations doivent être à jour (voir [AcController.refresh]).
  Future<List<SensorAlert>> tick(DateTime pNow) async {
    final vUnits = _ac.units;
    final vControls = <String, DaikinControl>{};
    final vOutdoors = <String, double>{};
    for (final vUnit in vUnits) {
      final vState = _ac.statusOf(vUnit.host)?.state;
      if (vState != null) {
        vControls[vUnit.host] = vState.control;
        final vOutdoor = vState.sensors.outdoorTemp;
        if (vOutdoor != null) {
          vOutdoors[vUnit.host] = vOutdoor;
        }
      }
    }
    final vResult = evaluatePlan(
      pRooms: rooms,
      pRules: rules,
      pVacation: vacation,
      pUnits: vUnits,
      pSensors: _sensors.sensors,
      pControls: vControls,
      pNow: pNow,
      pOutdoors: vOutdoors,
      pLastRuns: _lastRuns,
      pWindowSince: _windowSince,
    );
    for (final vHost in vResult.windowHosts) {
      _windowSince[vHost] = pNow;
    }
    _applied = [];
    for (final vCommand in vResult.commands) {
      if (await _ac.apply(vCommand.host, vCommand.control)) {
        _lastRuns[vCommand.lastRunKey] = pNow;
        _applied.add(vCommand);
      }
    }
    final vCurrent = evaluateAlerts(_sensors.sensors, pNow, pWatched: watched);
    final rFresh = freshAlerts(vCurrent, _knownAlerts);
    _knownAlerts = {for (final vAlert in vCurrent) vAlert.key};
    notifyListeners();

    return rFresh;
  }
}
