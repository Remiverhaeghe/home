import 'dart:io';

import '../logic/backup.dart';

/// Lecture et écriture des fichiers de données dans le dossier de l'appli, pour la sauvegarde.
class BackupFiles {
  BackupFiles(this.folder);

  final Directory folder;

  /// Texte de chaque fichier de données présent.
  Future<Map<String, String>> collect() async {
    final rFiles = <String, String>{};
    for (final vName in backupFileNames) {
      final vFile = File('${folder.path}/$vName');
      if (await vFile.exists()) {
        rFiles[vName] = await vFile.readAsString();
      }
    }

    return rFiles;
  }

  /// Remplace les fichiers par ceux de la sauvegarde. Chaque fichier remplacé est d'abord copié en
  /// `.avant`, puis le nouveau est écrit sans risque de fichier à moitié écrit. Renvoie le nombre
  /// de fichiers écrits.
  Future<int> restore(Map<String, String> pFiles) async {
    var rCount = 0;
    for (final vEntry in pFiles.entries) {
      if (!backupFileNames.contains(vEntry.key)) {
        continue;
      }
      final vFile = File('${folder.path}/${vEntry.key}');
      if (await vFile.exists()) {
        await vFile.copy('${vFile.path}.avant');
      }
      final vTemp = File('${vFile.path}.tmp');
      await vTemp.writeAsString(vEntry.value, flush: true);
      await vTemp.rename(vFile.path);
      rCount++;
    }

    return rCount;
  }
}
