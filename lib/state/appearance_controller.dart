import 'package:flutter/foundation.dart';

import '../logic/appearance.dart';
import '../logic/units.dart';
import '../storage/appearance_store.dart';

/// Thème et taille du texte, appliqués à toute l'appli.
class AppearanceController extends ChangeNotifier {
  AppearanceController(this._store);

  final AppearanceStore _store;
  var _settings = const AppearanceSettings();

  AppearanceSettings get settings => _settings;

  Future<void> load() async {
    _settings = await _store.load();
    notifyListeners();
  }

  Future<void> setTheme(ThemeChoice pTheme) => _change(_settings.copyWith(theme: pTheme));

  Future<void> setTextScale(double pScale) => _change(_settings.copyWith(textScale: pScale));

  Future<void> setTemperatureUnit(TemperatureUnit pUnit) =>
      _change(_settings.copyWith(temperatureUnit: pUnit));

  Future<void> setLanguage(AppLanguage pLanguage) => _change(_settings.copyWith(language: pLanguage));

  Future<void> _change(AppearanceSettings pSettings) async {
    _settings = pSettings;
    await _store.save(_settings);
    notifyListeners();
  }
}
