import 'dart:io';

import '../logic/automations.dart';
import '../logic/plan.dart';
import '../logic/rooms_file.dart';
import '../logic/vacation.dart';

/// Tout ce que l'utilisateur règle pour piloter la maison : pièces, règles et mode vacances.
class PlanSettings {
  const PlanSettings({this.rooms = const [], this.rules = const [], this.vacation});

  final List<Room> rooms;
  final List<AutoRule> rules;
  final VacationMode? vacation;
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

/// `pieces.json`, `automatismes.json` et `vacances.json` dans [directory], chacun écrit sans
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

    return PlanSettings(
      rooms: vRooms == null ? [] : parseRooms(vRooms),
      rules: vRules == null ? [] : parseAutoRules(vRules),
      vacation: vVacation == null ? null : parseVacation(vVacation),
    );
  }

  @override
  Future<void> save(PlanSettings pSettings) async {
    await _write('pieces.json', roomsJson(pSettings.rooms));
    await _write('automatismes.json', autoRulesJson(pSettings.rules));
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
