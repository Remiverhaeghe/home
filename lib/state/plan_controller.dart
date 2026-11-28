import 'package:flutter/foundation.dart';

import '../logic/alerts.dart';
import '../logic/automations.dart';
import '../logic/boost.dart';
import '../logic/scenarios.dart';
import '../logic/house_calendar.dart';
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

  /// Capteurs placés dehors : l'humidité de l'air extérieur ne dit pas d'aérer la maison.
  Set<String> outdoor = const {};

  /// Le poêle à pellets est allumé : la clim ne chauffe pas en plus, sauf s'il fait très froid.
  bool stoveRunning = false;

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

  /// Sous cette température, la clim peut chauffer en plus du poêle.
  double get stoveColdBelow => _settings.stoveColdBelow;

  /// Au-dessus de ce taux d'humidité, une alerte est donnée.
  double get humidityAlertAt => _settings.humidityAlertAt;

  /// Coups de chaud enregistrés, en cours ou passés.
  List<Boost> get boosts => _settings.boosts;
  VacationMode? get vacation => _settings.vacation;

  /// Jours de repos, fériés et télétravail.
  HouseCalendar get calendar => _settings.calendar;

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
      calendar: calendar,
      stoveColdBelow: stoveColdBelow,
      humidityAlertAt: humidityAlertAt,
      boosts: boosts,
    ),
  );

  /// Remplace le planning d'une pièce, en gardant ses températures souhaitées.
  Future<void> setSchedule(String pHost, List<ScheduleSlot> pSlots) {
    final vRoom = roomOf(pHost);

    return setRoom(
      Room(acHost: pHost, targets: vRoom?.targets ?? const RoomTargets(), schedule: pSlots),
    );
  }

  Future<void> setRules(List<AutoRule> pRules) => _save(
    PlanSettings(
      rooms: rooms,
      rules: pRules,
      vacation: vacation,
      calendar: calendar,
      stoveColdBelow: stoveColdBelow,
      humidityAlertAt: humidityAlertAt,
      boosts: boosts,
    ),
  );

  /// Règle le mode vacances, ou le retire avec null.
  Future<void> setVacation(VacationMode? pVacation) => _save(
    PlanSettings(
      rooms: rooms,
      rules: rules,
      vacation: pVacation,
      calendar: calendar,
      stoveColdBelow: stoveColdBelow,
      humidityAlertAt: humidityAlertAt,
      boosts: boosts,
    ),
  );

  /// Remplace le calendrier de la maison.
  Future<void> setCalendar(HouseCalendar pCalendar) => _save(
    PlanSettings(
      rooms: rooms,
      rules: rules,
      vacation: vacation,
      calendar: pCalendar,
      stoveColdBelow: stoveColdBelow,
      humidityAlertAt: humidityAlertAt,
      boosts: boosts,
    ),
  );

  /// Règle le seuil de froid sous lequel la clim chauffe en plus du poêle : borné et arrondi au
  /// demi-degré.
  Future<void> setStoveColdBelow(double pValue) {
    final vValue = (pValue.clamp(stoveColdMin, stoveColdMax) * 2).round() / 2;

    return _save(
      PlanSettings(
        rooms: rooms,
        rules: rules,
        vacation: vacation,
        calendar: calendar,
        stoveColdBelow: vValue,
        humidityAlertAt: humidityAlertAt,
        boosts: boosts,
      ),
    );
  }

  /// Règle le seuil d'humidité des alertes : borné et arrondi au pour cent.
  Future<void> setHumidityAlertAt(double pValue) {
    final vValue = pValue.clamp(humidityAlertMin, humidityAlertMax).roundToDouble();

    return _save(
      PlanSettings(
        rooms: rooms,
        rules: rules,
        vacation: vacation,
        calendar: calendar,
        stoveColdBelow: stoveColdBelow,
        boosts: boosts,
        humidityAlertAt: vValue,
      ),
    );
  }

  /// Lance un coup de chaud dans la pièce de la clim [pHost] : [pTemp] °C pendant [pMinutes]
  /// minutes. Un coup de chaud déjà en cours sur cette clim est remplacé, les finis sont retirés.
  Future<void> startBoost(
    String pHost,
    BoostKind pKind,
    double pTemp,
    int pMinutes,
    DateTime pNow,
  ) {
    final vTemp = (pTemp.clamp(boostMinTemp, boostMaxTemp) * 2).round() / 2;
    final vMinutes = pMinutes.clamp(boostMinMinutes, boostMaxMinutes).toInt();
    final vKept = activeBoosts(boosts, pNow).values.where((pBoost) => pBoost.host != pHost);

    return _save(
      PlanSettings(
        rooms: rooms,
        rules: rules,
        vacation: vacation,
        calendar: calendar,
        stoveColdBelow: stoveColdBelow,
        humidityAlertAt: humidityAlertAt,
        boosts: [
          ...vKept,
          Boost(
            host: pHost,
            kind: pKind,
            temp: vTemp,
            until: pNow.add(Duration(minutes: vMinutes)),
          ),
        ],
      ),
    );
  }

  /// Arrête le coup de chaud de la clim [pHost] ; le planning reprend au prochain tour.
  Future<void> stopBoost(String pHost) => _save(
    PlanSettings(
      rooms: rooms,
      rules: rules,
      vacation: vacation,
      calendar: calendar,
      stoveColdBelow: stoveColdBelow,
      humidityAlertAt: humidityAlertAt,
      boosts: [
        for (final vBoost in boosts)
          if (vBoost.host != pHost) vBoost,
      ],
    ),
  );

  /// Lance la nuit : chaque pièce prend sa température « nuit » jusqu'au prochain réveil.
  Future<void> startNight(DateTime pNow) {
    final vNight = nightBoosts(rooms, pNow);
    final vHosts = {for (final vBoost in vNight) vBoost.host};
    final vKept = activeBoosts(boosts, pNow).values.where((pBoost) => !vHosts.contains(pBoost.host));

    return _save(
      PlanSettings(
        rooms: rooms,
        rules: rules,
        vacation: vacation,
        calendar: calendar,
        stoveColdBelow: stoveColdBelow,
        humidityAlertAt: humidityAlertAt,
        boosts: [...vKept, ...vNight],
      ),
    );
  }

  /// Annule la nuit : les pièces reprennent leur planning.
  Future<void> stopNight(DateTime pNow) => _save(
    PlanSettings(
      rooms: rooms,
      rules: rules,
      vacation: vacation,
      calendar: calendar,
      stoveColdBelow: stoveColdBelow,
      humidityAlertAt: humidityAlertAt,
      boosts: [
        for (final vBoost in activeBoosts(boosts, pNow).values)
          if (vBoost.kind != BoostKind.night) vBoost,
      ],
    ),
  );

  /// Coup de chaud en cours sur la clim [pHost] à l'instant [pNow], s'il y en a un.
  Boost? boostOf(String pHost, DateTime pNow) => activeBoosts(boosts, pNow)[pHost];

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
      pCalendar: calendar,
      pUnits: vUnits,
      pSensors: _sensors.sensors,
      pControls: vControls,
      pNow: pNow,
      pOutdoors: vOutdoors,
      pLastRuns: _lastRuns,
      pWindowSince: _windowSince,
      pStoveRunning: stoveRunning,
      pStoveColdBelow: stoveColdBelow,
      pBoosts: activeBoosts(boosts, pNow),
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
    final vCurrent = evaluateAlerts(
      _sensors.sensors,
      pNow,
      pWatched: watched,
      pHumidityLevel: humidityAlertAt,
      pOutdoor: outdoor,
    );
    final rFresh = freshAlerts(vCurrent, _knownAlerts);
    _knownAlerts = {for (final vAlert in vCurrent) vAlert.key};
    notifyListeners();

    return rFresh;
  }
}
