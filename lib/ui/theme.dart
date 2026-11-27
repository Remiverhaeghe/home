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

/// Thème unique de l'appli : sombre, pensé pour un écran regardé le soir.
ThemeData buildTheme() {
  const vScheme = ColorScheme.dark(
    surface: Color(0xFF12161C),
    onSurface: Color(0xFFE6EAF0),
    surfaceContainerHigh: Color(0xFF1B222B),
    primary: Color(0xFFF2A65A),
    onPrimary: Color(0xFF2A1A08),
    secondary: Color(0xFF5AB4E0),
    error: Color(0xFFEB6F6F),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    extensions: const [HomeColors.slate],
  );
}
