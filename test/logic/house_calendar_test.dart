import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/house_calendar.dart';

void main() {
  // Le 25 décembre 2026 est un vendredi férié ; le 1er décembre 2026 est un mardi
  final vChristmas = DateTime(2026, 12, 25);
  final vTuesday = DateTime(2026, 12, 1);

  test('un férié compte comme un repos, sauf règle contraire', () {
    expect(const HouseCalendar().kindOf(vChristmas), DayKind.rest);
    expect(const HouseCalendar(holidays: HolidayRule.none).kindOf(vChristmas), DayKind.normal);
    expect(const HouseCalendar().kindOf(DateTime(2026, 12, 24)), DayKind.normal);
  });

  test('le télétravail suit les jours choisis, le férié passe avant', () {
    const vCalendar = HouseCalendar(remoteWeekdays: {2, 5});

    expect(vCalendar.kindOf(vTuesday), DayKind.remote);
    expect(vCalendar.kindOf(vChristmas), DayKind.rest);
  });

  test('une décision pour une date passe avant tout', () {
    final vCalendar = HouseCalendar(
      remoteWeekdays: const {2},
      overrides: {
        DateTime(2026, 12, 1): DayOverride.normal,
        DateTime(2026, 12, 25): DayOverride.remote,
        DateTime(2026, 12, 4): DayOverride.rest,
      },
    );

    expect(vCalendar.kindOf(DateTime(2026, 12, 1, 14)), DayKind.normal);
    expect(vCalendar.kindOf(vChristmas), DayKind.remote);
    expect(vCalendar.kindOf(DateTime(2026, 12, 4)), DayKind.rest);
  });

  test('le numéro de planning suit la règle des fériés et la présence de plages télétravail', () {
    expect(const HouseCalendar().keyOf(vChristmas, pHasRemoteSlots: false), DateTime.sunday);
    expect(
      const HouseCalendar(holidays: HolidayRule.saturday).keyOf(vChristmas, pHasRemoteSlots: false),
      DateTime.saturday,
    );
    const vRemote = HouseCalendar(remoteWeekdays: {2});

    expect(vRemote.keyOf(vTuesday, pHasRemoteSlots: true), remoteDayKey);
    expect(vRemote.keyOf(vTuesday, pHasRemoteSlots: false), DateTime.tuesday);
  });

  test('le fichier garde le calendrier ; un fichier abîmé redonne celui de départ', () {
    final vCalendar = HouseCalendar(
      remoteWeekdays: const {2, 4},
      holidays: HolidayRule.saturday,
      overrides: {DateTime(2026, 12, 24): DayOverride.rest},
    );
    final vBack = parseCalendar(calendarJson(vCalendar));

    expect(vBack.remoteWeekdays, {2, 4});
    expect(vBack.holidays, HolidayRule.saturday);
    expect(vBack.overrides, {DateTime(2026, 12, 24): DayOverride.rest});
    expect(parseCalendar('pas du json').isDefault, isTrue);
    expect(parseCalendar('{"version":2}').isDefault, isTrue);
    expect(
      parseCalendar('{"version":1,"remoteWeekdays":[0,9,3],"holidays":"x"}').remoteWeekdays,
      {3},
    );
  });

  group('planning avec calendrier', () {
    const vSlots = [
      ScheduleSlot(weekdays: {1, 2, 3, 4, 5}, minute: 420, profile: ProfileKind.comfort),
      ScheduleSlot(weekdays: {1, 2, 3, 4, 5}, minute: 1080, profile: ProfileKind.night),
      ScheduleSlot(weekdays: {6, 7}, minute: 540, profile: ProfileKind.comfort),
      ScheduleSlot(weekdays: {6, 7}, minute: 1380, profile: ProfileKind.night),
      ScheduleSlot(weekdays: {remoteDayKey}, minute: 360, profile: ProfileKind.comfort),
      ScheduleSlot(weekdays: {remoteDayKey}, minute: 1380, profile: ProfileKind.night),
    ];

    test('un férié en semaine suit le planning du dimanche', () {
      final vMorning = DateTime(2026, 12, 25, 8);

      expect(profileAt(vSlots, vMorning), ProfileKind.comfort);
      expect(profileAt(vSlots, vMorning, pCalendar: const HouseCalendar()), ProfileKind.night);
    });

    test('un jour de télétravail suit les plages télétravail', () {
      final vEvening = DateTime(2026, 12, 1, 20);

      expect(profileAt(vSlots, vEvening), ProfileKind.night);
      expect(
        profileAt(vSlots, vEvening, pCalendar: const HouseCalendar(remoteWeekdays: {2})),
        ProfileKind.comfort,
      );
    });

    test('sans plage télétravail, le planning habituel reste', () {
      final vEvening = DateTime(2026, 12, 1, 20);
      final vPlain = vSlots.take(4).toList();

      expect(
        profileAt(vPlain, vEvening, pCalendar: const HouseCalendar(remoteWeekdays: {2})),
        ProfileKind.night,
      );
    });
  });
}
