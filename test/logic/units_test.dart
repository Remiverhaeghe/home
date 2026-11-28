import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/appearance.dart';
import 'package:home/logic/units.dart';

void main() {
  test('en Celsius, la température s\'écrit avec une décimale et °C', () {
    expect(Units().temp(21.5), '21,5 °C');
    expect(Units().temp(-3), '-3,0 °C');
  });

  test('en Fahrenheit, la température est convertie', () {
    final vUnits = Units(temperature: TemperatureUnit.fahrenheit);

    expect(vUnits.temp(0), '32,0 °F');
    expect(vUnits.temp(21.5), '70,7 °F');
    expect(vUnits.tempNumber(100), '212,0');
  });

  test('un écart garde son signe et ne reçoit pas le décalage de 32', () {
    expect(Units().delta(1.5), '+1,5 °C');
    expect(Units().delta(-0.8), '-0,8 °C');
    expect(Units(temperature: TemperatureUnit.fahrenheit).delta(10), '+18,0 °F');
  });

  test('le fichier d\'apparence garde l\'unité, Celsius par défaut', () {
    const vSettings = AppearanceSettings(temperatureUnit: TemperatureUnit.fahrenheit);

    expect(parseAppearance(appearanceJson(vSettings)).temperatureUnit, TemperatureUnit.fahrenheit);
    expect(
      parseAppearance('{"version":1,"theme":"dark","textScale":1.0}').temperatureUnit,
      TemperatureUnit.celsius,
    );
    expect(
      parseAppearance('{"version":1,"temperatureUnit":"kelvin"}').temperatureUnit,
      TemperatureUnit.celsius,
    );
  });

  test('le fichier d\'apparence garde la langue, français par défaut', () {
    const vSettings = AppearanceSettings(language: AppLanguage.english);

    expect(parseAppearance(appearanceJson(vSettings)).language, AppLanguage.english);
    expect(AppLanguage.english.code, 'en');
    expect(parseAppearance('{"version":1}').language, AppLanguage.french);
    expect(parseAppearance('{"version":1,"language":"de"}').language, AppLanguage.french);
  });
}
