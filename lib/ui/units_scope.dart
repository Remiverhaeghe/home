import 'package:flutter/widgets.dart';

import '../logic/units.dart';

/// Rend les unités choisies disponibles à tous les écrans ; sans elle, °C.
class UnitsScope extends InheritedWidget {
  const UnitsScope({super.key, required this.units, required super.child});

  final Units units;

  static Units of(BuildContext pContext) {
    final vScope = pContext.dependOnInheritedWidgetOfExactType<UnitsScope>();

    return vScope?.units ?? Units(pLocale: Localizations.localeOf(pContext).toString());
  }

  @override
  bool updateShouldNotify(UnitsScope pOld) => pOld.units.temperature != units.temperature;
}
