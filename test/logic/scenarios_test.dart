import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/alerts.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/house_calendar.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/scenarios.dart';

void main() {
  final vNow = DateTime(2026, 12, 7, 18, 30);

  group('départ', () {
    test('l\'absence commence aujourd\'hui et finit le matin du retour', () {
      final vAbsence = departure(vNow, DateTime(2026, 12, 12, 15));

      expect(vAbsence!.from, DateTime(2026, 12, 7));
      expect(vAbsence.until, DateTime(2026, 12, 12));
      expect(vAbsence.isActiveAt(vNow), isTrue);
    });

    test('un retour aujourd\'hui ou avant ne programme rien', () {
      expect(departure(vNow, DateTime(2026, 12, 7)), isNull);
      expect(departure(vNow, DateTime(2026, 12, 1)), isNull);
    });
  });

  group('télétravail du jour', () {
    test('un jour normal devient un jour de télétravail, et inversement', () {
      const vNormal = HouseCalendar();
      final vOn = toggleRemoteToday(vNormal, vNow);

      expect(isRemoteToday(vNormal, vNow), isFalse);
      expect(isRemoteToday(vOn, vNow), isTrue);
      expect(isRemoteToday(toggleRemoteToday(vOn, vNow), vNow), isFalse);
    });

    test('un jour de télétravail du calendrier devient normal pour aujourd\'hui seulement', () {
      final vCalendar = HouseCalendar(remoteWeekdays: {vNow.weekday});
      final vOff = toggleRemoteToday(vCalendar, vNow);

      expect(isRemoteToday(vCalendar, vNow), isTrue);
      expect(isRemoteToday(vOff, vNow), isFalse);
      expect(isRemoteToday(vOff, vNow.add(const Duration(days: 7))), isTrue);
    });

    test('les autres décisions du calendrier sont gardées', () {
      final vCalendar = HouseCalendar(overrides: {DateTime(2026, 12, 24): DayOverride.rest});

      final vNext = toggleRemoteToday(vCalendar, vNow);

      expect(vNext.overrides[DateTime(2026, 12, 24)], DayOverride.rest);
      expect(vNext.overrides[DateTime(2026, 12, 7)], DayOverride.remote);
    });
  });

  group('nuit', () {
    test('le réveil est à 7 h, le lendemain une fois l\'heure passée', () {
      expect(nightEnd(DateTime(2026, 12, 7, 18, 30)), DateTime(2026, 12, 8, 7));
      expect(nightEnd(DateTime(2026, 12, 7, 2)), DateTime(2026, 12, 7, 7));
      expect(nightEnd(DateTime(2026, 12, 7, 7)), DateTime(2026, 12, 8, 7));
    });

    test('chaque pièce prend sa température de nuit', () {
      final vBoosts = nightBoosts([
        const Room(acHost: 'a', targets: RoomTargets(night: 16.5)),
        const Room(acHost: 'b'),
      ], vNow);

      expect(vBoosts.map((pBoost) => pBoost.temp), [16.5, 17]);
      expect(vBoosts.every((pBoost) => pBoost.until == DateTime(2026, 12, 8, 7)), isTrue);
      expect(isNightOn(vBoosts, vNow), isTrue);
      expect(isNightOn(vBoosts, DateTime(2026, 12, 8, 7)), isFalse);
      expect(isNightOn(const [], vNow), isFalse);
    });
  });

  group('aération', () {
    test('le rappel n\'apparaît qu\'une fois la fin passée', () {
      final vUntil = DateTime(2026, 12, 7, 18, 45);

      expect(airingAlerts(null, vNow), isEmpty);
      expect(airingAlerts(vUntil, vNow), isEmpty);
      expect(airingAlerts(vUntil, vUntil).single.kind, AlertKind.airing);
    });
  });
}
