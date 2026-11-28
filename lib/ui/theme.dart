import 'package:flutter/material.dart';

/// Palette sombre de Home : fond ardoise, température en ambre, humidité en bleu.
@immutable
class HomeColors extends ThemeExtension<HomeColors> {
  const HomeColors({
    required this.temperature,
    required this.humidity,
    required this.good,
    required this.warning,
  });

  /// Température.
  final Color temperature;

  /// Humidité.
  final Color humidity;

  /// Air confortable.
  final Color good;

  /// Air sec ou humide.
  final Color warning;

  static const slate = HomeColors(
    temperature: Color(0xFFF2A65A),
    humidity: Color(0xFF5AB4E0),
    good: Color(0xFF6FCF97),
    warning: Color(0xFFEB8F6F),
  );

  /// Variante claire : mêmes teintes, assombries pour rester lisibles sur fond clair.
  static const paper = HomeColors(
    temperature: Color(0xFFB0600D),
    humidity: Color(0xFF16709E),
    good: Color(0xFF2B7F50),
    warning: Color(0xFFB84A25),
  );

  static HomeColors of(BuildContext pContext) => Theme.of(pContext).extension<HomeColors>()!;

  @override
  HomeColors copyWith({Color? temperature, Color? humidity, Color? good, Color? warning}) =>
      HomeColors(
        temperature: temperature ?? this.temperature,
        humidity: humidity ?? this.humidity,
        good: good ?? this.good,
        warning: warning ?? this.warning,
      );

  @override
  HomeColors lerp(HomeColors? pOther, double pT) {
    if (pOther == null) {
      return this;
    }

    return HomeColors(
      temperature: Color.lerp(temperature, pOther.temperature, pT)!,
      humidity: Color.lerp(humidity, pOther.humidity, pT)!,
      good: Color.lerp(good, pOther.good, pT)!,
      warning: Color.lerp(warning, pOther.warning, pT)!,
    );
  }
}

/// Thème de l'appli : sombre, pensé pour un écran regardé le soir, ou clair.
ThemeData buildTheme({Brightness pBrightness = Brightness.dark}) {
  final vDark = pBrightness == Brightness.dark;
  final vScheme = vDark
      ? const ColorScheme.dark(
          surface: Color(0xFF12161C),
          onSurface: Color(0xFFE6EAF0),
          surfaceContainerHigh: Color(0xFF1B222B),
          primary: Color(0xFFF2A65A),
          onPrimary: Color(0xFF2A1A08),
          secondary: Color(0xFF5AB4E0),
          error: Color(0xFFEB6F6F),
        )
      : const ColorScheme.light(
          surface: Color(0xFFF5F6F8),
          onSurface: Color(0xFF1B222B),
          surfaceContainerHigh: Color(0xFFFFFFFF),
          primary: Color(0xFFB0600D),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF16709E),
          error: Color(0xFFB3261E),
        );

  return ThemeData(
    useMaterial3: true,
    colorScheme: vScheme,
    scaffoldBackgroundColor: vScheme.surface,
    appBarTheme: AppBarTheme(backgroundColor: vScheme.surface, centerTitle: false),
    cardTheme: CardThemeData(
      color: vScheme.surfaceContainerHigh,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: vDark ? BorderSide.none : const BorderSide(color: Color(0xFFD9DEE5)),
      ),
    ),
    extensions: [vDark ? HomeColors.slate : HomeColors.paper],
  );
}
