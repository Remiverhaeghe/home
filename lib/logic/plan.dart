import 'dart:math';

import 'ac_units.dart';
import 'automations.dart';
import 'comfort.dart';
import 'daikin.dart';
import 'reading.dart';
import 'vacation.dart';

/// Une pièce suivie : sa clim, ses températures souhaitées et son planning.
class Room {
  const Room({required this.acHost, this.targets = const RoomTargets(), this.schedule = const []});

  final String acHost;
  final RoomTargets targets;
  final List<ScheduleSlot> schedule;
}

/// Pourquoi une commande est envoyée.
enum PlanReason { windowOpen, vacation, comfort, rule, stove }

/// Une commande à envoyer à la clim [host].
class PlanCommand {
  const PlanCommand({required this.host, required this.control, required this.reason, this.key});

  final String host;
  final DaikinControl control;
  final PlanReason reason;

  /// Clé du délai entre deux commandes, la règle pour une règle, la clim sinon.
  final String? key;

  String get lastRunKey => key ?? '$host|${reason.name}';
}

/// Commandes décidées et clims où une fenêtre ouverte vient d'être détectée.
class PlanResult {
  const PlanResult({required this.commands, required this.windowHosts});

  final List<PlanCommand> commands;
  final Set<String> windowHosts;
}

/// Une chute de [windowDrop] °C ou plus en [windowSpan] veut dire fenêtre ouverte ; la clim reste
/// alors au repos pendant [windowHold].
const windowDrop = 1.5;
const windowSpan = Duration(minutes: 10);
const windowHold = Duration(minutes: 30);

/// Quand le poêle marche, la clim ne chauffe pas en plus tant que la pièce est à cette température
/// ou plus. En dessous, il fait trop froid : les deux peuvent tourner ensemble.
const defaultStoveColdBelow = 16.0;

/// Délais minimaux entre deux commandes de même nature sur une clim.
const comfortGap = Duration(minutes: 10);
const frostGap = Duration(minutes: 30);

/// Vrai quand le capteur a perdu [windowDrop] °C ou plus pendant les [windowSpan] qui précèdent
/// [pNow], jusqu'à son dernier relevé.
bool windowOpened(Sensor pSensor, DateTime pNow) {
  final vLast = pSensor.last;
  if (vLast == null) {
    return false;
  }
  final vSince = pNow.subtract(windowSpan);
  final vRecent = pSensor.readings
      .where((pReading) => !pReading.at.isBefore(vSince) && !pReading.at.isAfter(pNow))
      .toList();
  if (vRecent.length < 2 || !vRecent.contains(vLast)) {
    return false;
  }
  final vHighest = vRecent.map((pReading) => pReading.temp).reduce(max);

  return vHighest - vLast.temp >= windowDrop;
}

bool _gapPassed(Map<String, DateTime> pLastRuns, String pKey, Duration pGap, DateTime pNow) {
  final vLast = pLastRuns[pKey];

  return vLast == null || pNow.difference(vLast) >= pGap;
}

/// Ce qui doit tourner à l'instant [pNow], clim par clim : fenêtre ouverte, puis absence (hors gel
/// ou remontée avant le retour), puis température souhaitée du planning, puis règles de seuil
/// pour les clims restées sans commande. Une clim n'est commandée que si son capteur est relié et
/// récent et si son état est connu. [pOutdoors] donne la température dehors par adresse de clim.
PlanResult evaluatePlan({
  required List<Room> pRooms,
  required List<AutoRule> pRules,
  required VacationMode? pVacation,
  required List<AcUnit> pUnits,
  required List<Sensor> pSensors,
  required Map<String, DaikinControl> pControls,
  required DateTime pNow,
  Map<String, double> pOutdoors = const {},
  Map<String, DateTime> pLastRuns = const {},
  Map<String, DateTime> pWindowSince = const {},
  bool pStoveRunning = false,
  double pStoveColdBelow = defaultStoveColdBelow,
}) {
  final vCommands = <PlanCommand>[];
  final vWindowHosts = <String>{};
  final vHandled = <String>{};
  final vActive = pVacation != null && pVacation.isActiveAt(pNow) ? pVacation : null;
  final vPreheating = vActive?.isPreheatingAt(pNow) ?? false;

  for (final vUnit in pUnits) {
    final vHost = vUnit.host;
    final vControl = pControls[vHost];
    final vSensor = pSensors.where((pSensor) => pSensor.name == vUnit.sensorName).firstOrNull;
    final vReading = vSensor?.last;
    if (vSensor == null || vControl == null || vReading == null) {
      continue;
    }
    final vAge = pNow.difference(vReading.at);
    if (vAge > maxReadingAge || vAge.isNegative) {
      continue;
    }
    final vSince = pWindowSince[vHost];
    final vHeld = vSince != null && pNow.difference(vSince) < windowHold;
    final vDetected = !vHeld && windowOpened(vSensor, pNow);
    if (vHeld || vDetected) {
      vHandled.add(vHost);
      if (vDetected) {
        vWindowHosts.add(vHost);
        if (vControl.power) {
          vCommands.add(
            PlanCommand(
              host: vHost,
              control: vControl.copyWith(power: false),
              reason: PlanReason.windowOpen,
            ),
          );
        }
      }
      continue;
    }
    DaikinControl? vTarget;
    PlanReason? vReason;
    var vGap = comfortGap;
    if (vActive != null && !vPreheating) {
      vTarget = frostControl(vActive, vReading.temp, vControl);
      vReason = PlanReason.vacation;
      vGap = frostGap;
    } else {
      final vRoom = pRooms.where((pRoom) => pRoom.acHost == vHost).firstOrNull;
      if (vRoom != null) {
        final vProfile = vPreheating ? ProfileKind.comfort : profileAt(vRoom.schedule, pNow);
        vTarget = comfortControl(
          pTarget: vRoom.targets.of(vProfile),
          pTemp: vReading.temp,
          pControl: vControl,
          pOutdoor: pOutdoors[vHost],
        );
        vReason = PlanReason.comfort;
      }
    }
    if (vReason == PlanReason.comfort && pStoveRunning && vReading.temp >= pStoveColdBelow) {
      // Le poêle chauffe déjà : la clim ne chauffe pas en plus, et s'arrête si elle chauffait
      final vHeating = vControl.power && vControl.mode == DaikinMode.heat;
      if (vTarget != null && vTarget.power && vTarget.mode == DaikinMode.heat) {
        vTarget = vHeating ? vControl.copyWith(power: false) : null;
        vReason = PlanReason.stove;
      } else if (vTarget == null && vHeating) {
        vTarget = vControl.copyWith(power: false);
        vReason = PlanReason.stove;
      }
    }
    if (vTarget != null && vReason != null) {
      final vCommand = PlanCommand(host: vHost, control: vTarget, reason: vReason);
      if (_gapPassed(pLastRuns, vCommand.lastRunKey, vGap, pNow)) {
        vCommands.add(vCommand);
        vHandled.add(vHost);
      }
    }
  }

  if (vActive == null) {
    for (final vDecision in evaluateRules(
      pRules: pRules,
      pUnits: pUnits,
      pSensors: pSensors,
      pControls: pControls,
      pNow: pNow,
      pLastRuns: pLastRuns,
    )) {
      final vHost = vDecision.rule.acHost;
      if (vHandled.add(vHost)) {
        vCommands.add(
          PlanCommand(
            host: vHost,
            control: vDecision.control,
            reason: PlanReason.rule,
            key: vDecision.rule.key,
          ),
        );
      }
    }
  }

  return PlanResult(commands: vCommands, windowHosts: vWindowHosts);
}
