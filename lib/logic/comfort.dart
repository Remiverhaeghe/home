import 'daikin.dart';

/// Profil d'une pièce : chacun a sa température souhaitée.
enum ProfileKind { comfort, night, eco, away }

/// Températures souhaitées d'une pièce, en °C, par profil.
class RoomTargets {
  const RoomTargets({this.comfort = 21, this.night = 17, this.eco = 18, this.away = 15});

  final double comfort;
  final double night;
  final double eco;
  final double away;

  double of(ProfileKind pProfile) => switch (pProfile) {
    ProfileKind.comfort => comfort,
    ProfileKind.night => night,
    ProfileKind.eco => eco,
    ProfileKind.away => away,
  };
}

/// À partir de [minute] (0 à 1439), les jours [weekdays] (1 lundi à 7 dimanche) suivent [profile]
/// jusqu'à la plage suivante.
class ScheduleSlot {
  const ScheduleSlot({required this.weekdays, required this.minute, required this.profile});

  final Set<int> weekdays;
  final int minute;
  final ProfileKind profile;
}

/// Profil en vigueur à l'instant [pNow] : celui de la plage la plus récente, en remontant jusqu'à
/// une semaine en arrière. [pFallback] quand aucune plage ne s'applique.
ProfileKind profileAt(
  List<ScheduleSlot> pSlots,
  DateTime pNow, {
  ProfileKind pFallback = ProfileKind.eco,
}) {
  final vNowMinute = pNow.hour * 60 + pNow.minute;
  for (var vBack = 0; vBack <= 7; vBack++) {
    final vDay = DateTime(pNow.year, pNow.month, pNow.day - vBack);
    final vStarted =
        pSlots
            .where(
              (pSlot) =>
                  pSlot.weekdays.contains(vDay.weekday) &&
                  (vBack > 0 || pSlot.minute <= vNowMinute),
            )
            .toList()
          ..sort((pA, pB) => pB.minute.compareTo(pA.minute));
    if (vStarted.isNotEmpty) {
      return vStarted.first.profile;
    }
  }

  return pFallback;
}

/// Écart toléré autour de la température souhaitée avant de chauffer ou de refroidir.
const comfortMargin = 0.5;

/// Sous cette température dehors, le froid n'est pas utile ; au-dessus, le chauffage non plus.
const coolAboveOutdoor = 18.0;
const heatBelowOutdoor = 20.0;

/// Réglages pour tenir [pTarget] dans une pièce à [pTemp]. Chauffe sous la cible moins la marge,
/// refroidit au-dessus de la cible plus la marge, coupe une fois la cible atteinte. La température
/// de [pOutdoor] (celle que mesure la clim dehors) écarte le chauffage l'été et le froid l'hiver.
/// Null quand il n'y a rien à envoyer.
DaikinControl? comfortControl({
  required double pTarget,
  required double pTemp,
  required DaikinControl pControl,
  double? pOutdoor,
}) {
  final vCanHeat = pOutdoor == null || pOutdoor < heatBelowOutdoor;
  final vCanCool = pOutdoor == null || pOutdoor > coolAboveOutdoor;
  if (pTemp < pTarget - comfortMargin && vCanHeat) {
    return _switchedOn(pControl, DaikinMode.heat, pTarget);
  }
  if (pTemp > pTarget + comfortMargin && vCanCool) {
    return _switchedOn(pControl, DaikinMode.cool, pTarget);
  }
  if (pControl.power) {
    final vMode = pControl.mode;
    final vReached =
        (vMode == DaikinMode.heat && pTemp >= pTarget) ||
        (vMode == DaikinMode.cool && pTemp <= pTarget);

    return vReached ? pControl.copyWith(power: false) : null;
  }

  return null;
}

DaikinControl? _switchedOn(DaikinControl pControl, DaikinMode pMode, double pTarget) {
  final vOn = pControl.withMode(pMode)?.withSetpoint(pTarget)?.copyWith(power: true);

  return vOn == null || vOn.toQuery() == pControl.toQuery() ? null : vOn;
}
