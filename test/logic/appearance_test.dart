import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/appearance.dart';

void main() {
  test('les réglages de départ gardent le thème sombre et le texte normal', () {
    const vSettings = AppearanceSettings();

    expect(vSettings.theme, ThemeChoice.dark);
    expect(vSettings.textScale, 1.0);
  });

  test('le fichier garde le thème et la taille du texte', () {
    final vBack = parseAppearance(
      appearanceJson(const AppearanceSettings(theme: ThemeChoice.light, textScale: 1.3)),
    );

    expect(vBack.theme, ThemeChoice.light);
    expect(vBack.textScale, 1.3);
  });

  test('un fichier abîmé ou une valeur inconnue redonnent les réglages de départ', () {
    expect(parseAppearance('pas du json').theme, ThemeChoice.dark);
    expect(parseAppearance('{"version":2,"theme":"light"}').theme, ThemeChoice.dark);
    final vOdd = parseAppearance('{"version":1,"theme":"rose","textScale":9}');

    expect(vOdd.theme, ThemeChoice.dark);
    expect(vOdd.textScale, 1.0);
  });

  test('copyWith ne change que ce qui est demandé', () {
    final vSettings = const AppearanceSettings().copyWith(textScale: 1.5);

    expect(vSettings.theme, ThemeChoice.dark);
    expect(vSettings.textScale, 1.5);
  });
}
