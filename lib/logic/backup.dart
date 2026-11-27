/// Sauvegarde de toutes les données de Home dans un seul fichier, et lecture de ce fichier.
library;

import 'dart:convert';

/// Fichiers de données de Home que contient une sauvegarde. Seuls ces noms sont acceptés à la
/// restauration : un fichier qui en porterait un autre est ignoré.
const backupFileNames = [
  'capteurs.json',
  'noms-capteurs.json',
  'climatisations.json',
  'pieces.json',
  'automatismes.json',
  'vacances.json',
  'relais.json',
  'poele.json',
  'maison.json',
  'meteo.json',
  'apparence.json',
  'notes.json',
];

/// Version du format de sauvegarde.
const backupVersion = 1;

enum BackupProblem { notJson, notBackup, wrongVersion, empty }

/// Contenu lu d'une sauvegarde.
class Backup {
  const Backup({required this.files, required this.createdAt});

  /// Texte de chaque fichier, par nom, tel qu'il était au moment de la sauvegarde.
  final Map<String, String> files;
  final DateTime? createdAt;

  /// Le mot de passe du poêle fait partie de la sauvegarde : le fichier est à garder en lieu sûr.
  bool get hasSecrets => files.containsKey('poele.json');
}

/// Résultat de la lecture : la sauvegarde, ou ce qui ne va pas.
typedef BackupParse = ({Backup? backup, BackupProblem? problem});

/// Écrit la sauvegarde. Les fichiers sont gardés comme texte, sans être relus ni réécrits : la
/// restauration rend exactement ce qui avait été sauvegardé.
String backupJson(Map<String, String> pFiles, DateTime pNow) => jsonEncode({
  'app': 'home',
  'version': backupVersion,
  'createdAt': pNow.toIso8601String(),
  'files': {
    for (final vName in backupFileNames)
      if (pFiles.containsKey(vName)) vName: pFiles[vName],
  },
});

BackupParse parseBackup(String pText) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pText);
  } on FormatException {
    return (backup: null, problem: BackupProblem.notJson);
  }
  if (vRoot is! Map<String, dynamic> || vRoot['app'] != 'home' || vRoot['files'] is! Map) {
    return (backup: null, problem: BackupProblem.notBackup);
  }
  if (vRoot['version'] != backupVersion) {
    return (backup: null, problem: BackupProblem.wrongVersion);
  }
  final vFiles = <String, String>{};
  for (final vEntry in (vRoot['files'] as Map).entries) {
    final vName = vEntry.key;
    final vContent = vEntry.value;
    if (vName is String &&
        backupFileNames.contains(vName) &&
        vContent is String &&
        _isJson(vContent)) {
      vFiles[vName] = vContent;
    }
  }
  if (vFiles.isEmpty) {
    return (backup: null, problem: BackupProblem.empty);
  }
  final vDate = vRoot['createdAt'];

  return (
    backup: Backup(files: vFiles, createdAt: vDate is String ? DateTime.tryParse(vDate) : null),
    problem: null,
  );
}

bool _isJson(String pText) {
  try {
    jsonDecode(pText);

    return true;
  } on FormatException {
    return false;
  }
}
