import 'dart:io';

import '../logic/alert_history.dart';
import '../logic/day_summary.dart';
import '../logic/heating_costs.dart';
import '../logic/pending_readings.dart';
import '../logic/read_health.dart';

/// Fichiers partagés entre l'appli et le service d'arrière-plan, qui tourne dans un autre
/// processus Dart : ils ne partagent pas la mémoire, seulement ces deux fichiers.
///
/// Le service ajoute des lignes à `releves_en_attente.jsonl` ; l'appli les reprend et les range
/// dans ses capteurs. `suivi.json` liste les capteurs que le service doit relever.
class BackgroundFiles {
  BackgroundFiles(Directory pFolder)
    : _pending = File('${pFolder.path}/releves_en_attente.jsonl'),
      _followed = File('${pFolder.path}/suivi.json'),
      _appOpen = File('${pFolder.path}/appli_ouverte.txt'),
      _summaryOn = File('${pFolder.path}/resume_actif.txt'),
      _summarySent = File('${pFolder.path}/resume_envoye.txt'),
      _summaryHour = File('${pFolder.path}/resume_heure.txt'),
      _health = File('${pFolder.path}/sante-releves.json'),
      _interval = File('${pFolder.path}/releve_intervalle.txt'),
      _quiet = File('${pFolder.path}/heures-silencieuses.txt'),
      _alerts = File('${pFolder.path}/historique-alertes.jsonl');

  final File _pending;
  final File _followed;
  final File _appOpen;
  final File _summaryOn;
  final File _summarySent;
  final File _health;
  final File _summaryHour;
  final File _quiet;
  final File _interval;
  final File _alerts;

  Future<List<FollowedDevice>> loadFollowed() async =>
      await _followed.exists() ? parseFollowed(await _followed.readAsString()) : [];

  Future<void> saveFollowed(List<FollowedDevice> pDevices) =>
      _followed.writeAsString(followedJson(pDevices), flush: true);

  /// Ajoute une ligne à la fin du fichier des relevés en attente.
  Future<void> appendPending(String pLine) =>
      _pending.writeAsString('$pLine\n', mode: FileMode.append, flush: true);

  /// Relevés en attente, laissés dans le fichier : le service s'en sert pour décider sans les
  /// ranger à la place de l'appli.
  Future<List<PendingReading>> peekPending() async =>
      await _pending.exists() ? parsePending(await _pending.readAsString()) : [];

  /// L'appli ouverte note l'heure : tant que c'est récent, c'est elle qui applique le plan, et le
  /// service s'en abstient pour ne pas envoyer deux fois les mêmes commandes.
  Future<void> markAppOpen(DateTime pNow) =>
      _appOpen.writeAsString(pNow.toIso8601String(), flush: true);

  /// Vrai quand l'appli s'est signalée il y a moins de [pWithin].
  Future<bool> isAppOpen(DateTime pNow, Duration pWithin) async {
    if (!await _appOpen.exists()) {
      return false;
    }
    final vSeen = DateTime.tryParse(await _appOpen.readAsString());

    return vSeen != null && pNow.difference(vSeen) < pWithin;
  }

  /// Le résumé du matin est-il voulu ? L'appli écrit le fichier, le service le lit.
  Future<bool> summaryEnabled() => _summaryOn.exists();

  Future<void> setSummaryEnabled({required bool pOn}) async {
    if (pOn) {
      await _summaryOn.writeAsString('1', flush: true);
    } else if (await _summaryOn.exists()) {
      await _summaryOn.delete();
    }
  }

  /// Heure à partir de laquelle le résumé part : celle choisie, sinon [summaryHour].
  Future<int> summaryStartHour() async {
    if (!await _summaryHour.exists()) {
      return summaryHour;
    }
    final vHour = int.tryParse((await _summaryHour.readAsString()).trim());

    return vHour != null && vHour >= 0 && vHour <= 23 ? vHour : summaryHour;
  }

  Future<void> setSummaryStartHour(int pHour) =>
      _summaryHour.writeAsString('${pHour.clamp(0, 23)}', flush: true);

  /// Minutes entre deux relevés en arrière-plan : celles choisies, sinon [defaultReadInterval].
  Future<int> readIntervalMinutes() async {
    if (!await _interval.exists()) {
      return defaultReadInterval;
    }
    final vMinutes = int.tryParse((await _interval.readAsString()).trim());

    return vMinutes != null && readIntervalChoices.contains(vMinutes)
        ? vMinutes
        : defaultReadInterval;
  }

  Future<void> setReadIntervalMinutes(int pMinutes) =>
      _interval.writeAsString('$pMinutes', flush: true);

  /// Heures silencieuses (« 22-7 »), null quand il n'y en a pas : seul le gel sonne dans la plage.
  Future<OffPeak?> quietHours() async {
    if (!await _quiet.exists()) {
      return null;
    }
    final vParts = (await _quiet.readAsString()).trim().split('-');
    final vStart = vParts.length == 2 ? int.tryParse(vParts[0]) : null;
    final vEnd = vParts.length == 2 ? int.tryParse(vParts[1]) : null;
    if (vStart == null || vEnd == null) {
      return null;
    }
    final vQuiet = OffPeak(startHour: vStart, endHour: vEnd);

    return vQuiet.isValid ? vQuiet : null;
  }

  Future<void> setQuietHours(OffPeak? pQuiet) => pQuiet == null || !pQuiet.isValid
      ? _quiet.writeAsString('', flush: true)
      : _quiet.writeAsString('${pQuiet.startHour}-${pQuiet.endHour}', flush: true);

  Future<List<AlertEntry>> loadAlertHistory() async =>
      await _alerts.exists() ? parseAlertHistory(await _alerts.readAsString()) : [];

  Future<void> saveAlertHistory(List<AlertEntry> pEntries) =>
      _alerts.writeAsString(alertHistoryText(pEntries), flush: true);

  /// Date du dernier résumé envoyé, null s'il n'en est jamais parti.
  Future<DateTime?> lastSummary() async =>
      await _summarySent.exists() ? DateTime.tryParse(await _summarySent.readAsString()) : null;

  Future<void> markSummarySent(DateTime pNow) =>
      _summarySent.writeAsString(pNow.toIso8601String(), flush: true);

  /// Santé du relevé en arrière-plan : le service l'écrit à chaque tour, l'appli la lit.
  Future<ReadHealth> loadHealth() async =>
      await _health.exists() ? parseReadHealth(await _health.readAsString()) : const ReadHealth();

  Future<void> saveHealth(ReadHealth pHealth) =>
      _health.writeAsString(readHealthJson(pHealth), flush: true);

  /// Relevés en attente, retirés du fichier. Le fichier est d'abord renommé : une ligne ajoutée
  /// par le service pendant la lecture va dans un nouveau fichier, sans rien perdre.
  Future<List<PendingReading>> takePending() async {
    if (!await _pending.exists()) {
      return [];
    }
    final vTaking = File('${_pending.path}.lecture');
    await _pending.rename(vTaking.path);
    final vText = await vTaking.readAsString();
    await vTaking.delete();

    return parsePending(vText);
  }
}
