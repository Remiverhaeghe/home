import 'dart:convert';
import 'dart:io';

import '../logic/alerts.dart';
import '../logic/automations.dart';
import '../logic/boost.dart';
import '../logic/plan.dart';
import '../logic/rooms_file.dart';
import '../logic/vacation.dart';

/// Tout ce que l'utilisateur règle pour piloter la maison : pièces, règles et mode vacances.
class PlanSettings {
  const PlanSettings({
    this.rooms = const [],
    this.rules = const [],
    this.vacation,
    this.stoveColdBelow = defaultStoveColdBelow,
    this.boosts = const [],
    this.humidityAlertAt = humidityAlertLevel,
  });

  final List<Room> rooms;
  final List<AutoRule> rules;
  final VacationMode? vacation;

  /// Sous cette température, la clim peut chauffer en plus du poêle.
  final double stoveColdBelow;

  /// Coups de chaud (douche, bain, lessive), en cours ou passés.
  final List<Boost> boosts;

  /// Au-dessus de ce taux d'humidité, une alerte est donnée.
  final double humidityAlertAt;
}

/// Où vivent ces réglages : trois fichiers sur le téléphone, ou la mémoire dans les tests.
abstract class PlanStore {
  Future<PlanSettings> load();

  Future<void> save(PlanSettings pSettings);
}

class MemoryPlanStore implements PlanStore {
  MemoryPlanStore([this.saved = const PlanSettings()]);

  PlanSettings saved;

  @override
  Future<PlanSettings> load() async => saved;

  @override
  Future<void> save(PlanSettings pSettings) async => saved = pSettings;
}

/// `pieces.json`, `automatismes.json`, `vacances.json` et `reglages-plan.json` dans [directory], chacun écrit sans
/// risque de fichier à moitié écrit. Sans vacances, le fichier est supprimé.
class FilePlanStore implements PlanStore {
  FilePlanStore(this.directory);

  final Directory directory;

  File _file(String pName) => File('${directory.path}/$pName');

  Future<String?> _read(String pName) async {
    final vFile = _file(pName);

    return await vFile.exists() ? vFile.readAsString() : null;
  }

  Future<void> _write(String pName, String pContent) async {
    final vTemp = _file('$pName.tmp');
    await vTemp.writeAsString(pContent, flush: true);
    await vTemp.rename(_file(pName).path);
  }

  @override
  Future<PlanSettings> load() async {
    final vRooms = await _read('pieces.json');
    final vRules = await _read('automatismes.json');
    final vVacation = await _read('vacances.json');
    final vOptions = await _read('reglages-plan.json');

    return PlanSettings(
      rooms: vRooms == null ? [] : parseRooms(vRooms),
      rules: vRules == null ? [] : parseAutoRules(vRules),
      vacation: vVacation == null ? null : parseVacation(vVacation),
      stoveColdBelow: vOptions == null ? defaultStoveColdBelow : parseStoveColdBelow(vOptions),
      boosts: vOptions == null ? [] : parseBoostsFile(vOptions),
      humidityAlertAt: vOptions == null ? humidityAlertLevel : parseHumidityAlertAt(vOptions),
    );
  }

  @override
  Future<void> save(PlanSettings pSettings) async {
    await _write('pieces.json', roomsJson(pSettings.rooms));
    await _write('automatismes.json', autoRulesJson(pSettings.rules));
    await _write(
      'reglages-plan.json',
      planOptionsJson(pSettings.stoveColdBelow, pSettings.boosts, pSettings.humidityAlertAt),
    );
    final vVacation = pSettings.vacation;
    if (vVacation == null) {
      final vFile = _file('vacances.json');
      if (await vFile.exists()) {
        await vFile.delete();
      }
    } else {
      await _write('vacances.json', vacationJson(vVacation));
    }
  }
}

/// Bornes du seuil de froid réglable, par pas de 0,5 °C.
const stoveColdMin = 10.0;
const stoveColdMax = 22.0;

/// Contenu de `reglages-plan.json` : le seuil de froid, les coups de chaud et le seuil d'humidité.
String planOptionsJson(
  double pStoveColdBelow,
  List<Boost> pBoosts, [
  double pHumidityAlertAt = humidityAlertLevel,
]) => jsonEncode({
  'poeleFroidSous': pStoveColdBelow,
  'alerteHumidite': pHumidityAlertAt,
  'coupsDeChaud': jsonDecode(boostsToJson(pBoosts)),
});

/// Coups de chaud lus dans `reglages-plan.json` ; fichier abîmé, aucun.
List<Boost> parseBoostsFile(String pJson) {
  try {
    final vRoot = jsonDecode(pJson);

    return vRoot is Map<String, dynamic> ? parseBoosts(vRoot['coupsDeChaud']) : [];
  } on FormatException {
    return [];
  }
}

/// Seuil lu dans `reglages-plan.json` ; une valeur absente, illisible ou hors bornes redonne la
/// valeur par défaut.
double parseStoveColdBelow(String pJson) {
  try {
    final vRoot = jsonDecode(pJson);
    final vValue = vRoot is Map<String, dynamic> ? vRoot['poeleFroidSous'] : null;
    if (vValue is num && vValue >= stoveColdMin && vValue <= stoveColdMax) {
      return vValue.toDouble();
    }
  } on FormatException {
    // Fichier abîmé : valeur par défaut
  }

  return defaultStoveColdBelow;
}

/// Seuil d'humidité lu dans `reglages-plan.json` ; absent, illisible ou hors bornes, 70 %.
double parseHumidityAlertAt(String pJson) {
  try {
    final vRoot = jsonDecode(pJson);
    final vValue = vRoot is Map<String, dynamic> ? vRoot['alerteHumidite'] : null;
    if (vValue is num && vValue >= humidityAlertMin && vValue <= humidityAlertMax) {
      return vValue.toDouble();
    }
  } on FormatException {
    // Fichier abîmé : valeur par défaut
  }

  return humidityAlertLevel;
}
