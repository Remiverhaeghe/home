import 'dart:io';

import '../logic/detail_log.dart';
import '../logic/error_log.dart';

/// Journal détaillé, activable : l'appli écrit le fichier d'activation, le service d'arrière-plan
/// le lit à chaque tour. Désactivé, [note] ne fait rien.
abstract class DetailLog {
  Future<bool> isOn();

  Future<void> setOn({required bool pOn});

  /// Ajoute une ligne si le journal est activé.
  Future<void> note(String pTopic, String pMessage);

  Future<String> read();

  Future<void> clear();
}

class MemoryDetailLog implements DetailLog {
  MemoryDetailLog({DateTime Function()? pNow, this.on = false}) : _now = pNow ?? DateTime.now;

  final DateTime Function() _now;
  var on = false;
  var text = '';

  @override
  Future<bool> isOn() async => on;

  @override
  Future<void> setOn({required bool pOn}) async => on = pOn;

  @override
  Future<void> note(String pTopic, String pMessage) async {
    if (!on) {
      return;
    }
    final vLine = detailEntry(_now(), pTopic, pMessage);
    text = trimLog(text.isEmpty ? vLine : '$text\n$vLine', pMax: maxDetailLines);
  }

  @override
  Future<String> read() async => text;

  @override
  Future<void> clear() async => text = '';
}

/// Fichiers `journal-detail.txt` et `journal-detail-actif` dans le dossier privé de l'appli.
class FileDetailLog implements DetailLog {
  FileDetailLog(Directory pFolder, {DateTime Function()? pNow})
    : _file = File('${pFolder.path}/journal-detail.txt'),
      _flag = File('${pFolder.path}/journal-detail-actif'),
      _now = pNow ?? DateTime.now;

  final File _file;
  final File _flag;
  final DateTime Function() _now;

  @override
  Future<bool> isOn() => _flag.exists();

  @override
  Future<void> setOn({required bool pOn}) async {
    if (pOn) {
      await _flag.writeAsString('1', flush: true);
    } else if (await _flag.exists()) {
      await _flag.delete();
    }
  }

  @override
  Future<void> note(String pTopic, String pMessage) async {
    try {
      if (!await isOn()) {
        return;
      }
      final vOld = await read();
      final vLine = detailEntry(_now(), pTopic, pMessage);
      await _file.writeAsString(
        trimLog(vOld.isEmpty ? vLine : '$vOld\n$vLine', pMax: maxDetailLines),
        flush: true,
      );
    } on Object {
      // Le journal ne doit jamais gêner ce qu'il décrit
    }
  }

  @override
  Future<String> read() async => await _file.exists() ? _file.readAsString() : '';

  @override
  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}
