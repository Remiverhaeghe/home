import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/backup.dart';
import '../storage/backup_files.dart';

/// Sauvegarde et restauration de toutes les données de Home dans un seul fichier.
class BackupScreen extends StatelessWidget {
  const BackupScreen({
    super.key,
    required this.files,
    required this.pickFile,
    required this.saveFile,
    required this.onRestored,
    this.clock = DateTime.now,
  });

  final BackupFiles files;
  final Future<String?> Function() pickFile;
  final Future<bool> Function(String pFileName, Uint8List pBytes) saveFile;

  /// Relit toutes les données une fois les fichiers remplacés.
  final Future<void> Function() onRestored;
  final DateTime Function() clock;

  void _say(BuildContext pContext, String pMessage) {
    final vMessenger = ScaffoldMessenger.of(pContext);
    vMessenger.hideCurrentSnackBar();
    vMessenger.showSnackBar(SnackBar(content: Text(pMessage)));
  }

  Future<void> _save(BuildContext pContext) async {
    final vTexts = AppLocalizations.of(pContext);
    final vNow = clock();
    final vText = backupJson(await files.collect(), vNow);
    final vName = 'home-sauvegarde-${DateFormat('yyyy-MM-dd').format(vNow)}.json';
    final vSaved = await saveFile(vName, Uint8List.fromList(utf8.encode(vText)));
    if (vSaved && pContext.mounted) {
      _say(pContext, vTexts.backupSaved);
    }
  }

  Future<void> _restore(BuildContext pContext) async {
    final vTexts = AppLocalizations.of(pContext);
    final vText = await pickFile();
    if (vText == null || !pContext.mounted) {
      return;
    }
    final vParsed = parseBackup(vText);
    final vBackup = vParsed.backup;
    if (vBackup == null) {
      _say(
        pContext,
        switch (vParsed.problem!) {
          BackupProblem.notJson => vTexts.backupNotJson,
          BackupProblem.notBackup => vTexts.backupNotBackup,
          BackupProblem.wrongVersion => vTexts.backupWrongVersion,
          BackupProblem.empty => vTexts.backupEmpty,
        },
      );

      return;
    }
    final vDate = vBackup.createdAt == null
        ? vTexts.backupUnknownDate
        : DateFormat.yMMMd(Localizations.localeOf(pContext).toString()).format(vBackup.createdAt!);
    final vOk = await showDialog<bool>(
      context: pContext,
      builder: (pDialog) => AlertDialog(
        title: Text(vTexts.backupRestoreTitle),
        content: Text(vTexts.backupRestoreBody(vBackup.files.length, vDate)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(pDialog, false), child: Text(vTexts.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(pDialog, true),
            child: Text(vTexts.backupRestoreGo),
          ),
        ],
      ),
    );
    if (!(vOk ?? false)) {
      return;
    }
    final vCount = await files.restore(vBackup.files);
    await onRestored();
    if (pContext.mounted) {
      _say(pContext, vTexts.backupRestored(vCount));
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.backupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(vTexts.backupHelp),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _save(pContext),
            icon: const Icon(Icons.save_alt),
            label: Text(vTexts.backupSave),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _restore(pContext),
            icon: const Icon(Icons.restore),
            label: Text(vTexts.backupRestore),
          ),
          const SizedBox(height: 16),
          Text(vTexts.backupSecrets, style: Theme.of(pContext).textTheme.bodySmall),
        ],
      ),
    );
  }
}
