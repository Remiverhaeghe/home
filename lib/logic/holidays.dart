/// Jours fériés de France métropolitaine, calculés sans réseau : onze jours par an, dont trois
/// dépendent de la date de Pâques.
library;

enum Holiday {
  newYear,
  easterMonday,
  labourDay,
  victoryDay,
  ascension,
  whitMonday,
  bastilleDay,
  assumption,
  allSaints,
  armistice,
  christmas,
}

/// Dimanche de Pâques de l'année [pYear] (calendrier grégorien, méthode de Meeus, Jones et Butcher).
DateTime easterSunday(int pYear) {
  final vA = pYear % 19;
  final vB = pYear ~/ 100;
  final vC = pYear % 100;
  final vD = vB ~/ 4;
  final vE = vB % 4;
  final vF = (vB + 8) ~/ 25;
  final vG = (vB - vF + 1) ~/ 3;
  final vH = (19 * vA + vB - vD - vG + 15) % 30;
  final vI = vC ~/ 4;
  final vK = vC % 4;
  final vL = (32 + 2 * vE + 2 * vI - vH - vK) % 7;
  final vM = (vA + 11 * vH + 22 * vL) ~/ 451;
  final vSum = vH + vL - 7 * vM + 114;

  return DateTime(pYear, vSum ~/ 31, vSum % 31 + 1);
}

/// Les jours fériés de l'année [pYear], à minuit, dans l'ordre du calendrier.
Map<DateTime, Holiday> holidaysOf(int pYear) {
  final vEaster = easterSunday(pYear);
  DateTime after(int pDays) => DateTime(vEaster.year, vEaster.month, vEaster.day + pDays);

  return {
    DateTime(pYear, 1, 1): Holiday.newYear,
    after(1): Holiday.easterMonday,
    DateTime(pYear, 5, 1): Holiday.labourDay,
    DateTime(pYear, 5, 8): Holiday.victoryDay,
    after(39): Holiday.ascension,
    after(50): Holiday.whitMonday,
    DateTime(pYear, 7, 14): Holiday.bastilleDay,
    DateTime(pYear, 8, 15): Holiday.assumption,
    DateTime(pYear, 11, 1): Holiday.allSaints,
    DateTime(pYear, 11, 11): Holiday.armistice,
    DateTime(pYear, 12, 25): Holiday.christmas,
  };
}

/// Le jour férié de [pDay], ou null.
Holiday? holidayOn(DateTime pDay) =>
    holidaysOf(pDay.year)[DateTime(pDay.year, pDay.month, pDay.day)];
