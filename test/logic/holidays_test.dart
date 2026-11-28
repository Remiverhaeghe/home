import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/holidays.dart';

void main() {
  test('Pâques tombe aux bonnes dates', () {
    expect(easterSunday(2026), DateTime(2026, 4, 5));
    expect(easterSunday(2027), DateTime(2027, 3, 28));
    expect(easterSunday(2024), DateTime(2024, 3, 31));
  });

  test('les onze jours fériés de 2026, dont ceux qui suivent Pâques', () {
    final vHolidays = holidaysOf(2026);

    expect(vHolidays, hasLength(11));
    expect(vHolidays[DateTime(2026, 4, 6)], Holiday.easterMonday);
    expect(vHolidays[DateTime(2026, 5, 14)], Holiday.ascension);
    expect(vHolidays[DateTime(2026, 5, 25)], Holiday.whitMonday);
    expect(vHolidays[DateTime(2026, 12, 25)], Holiday.christmas);
  });

  test('holidayOn ignore l\'heure et renvoie null un jour ordinaire', () {
    expect(holidayOn(DateTime(2026, 7, 14, 18, 30)), Holiday.bastilleDay);
    expect(holidayOn(DateTime(2026, 7, 15)), isNull);
  });
}
