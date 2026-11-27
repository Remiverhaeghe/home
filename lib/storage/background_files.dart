import 'dart:io';

import '../logic/pending_readings.dart';

/// Fichiers partagés entre l'appli et le service d'arrière-plan, qui tourne dans un autre
/// processus Dart : ils ne partagent pas la mémoire, seulement ces deux fichiers.
///
/// Le service ajoute des lignes à `releves_en_attente.jsonl` ; l'appli les reprend et les range
/// dans ses capteurs. `suivi.json` liste les capteurs que le service doit relever.
class BackgroundFiles {
  BackgroundFiles(Directory pFolder)
    : _pending = File('${pFolder.path}/releves_en_attente.jsonl'),
      _followed = File('${pFolder.path}/suivi.json'),
      _appOpen = File('${pFolder.path}/appli_ouverte.txt');

  final File _pending;
  final File _followed;
  final File _appOpen;

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
