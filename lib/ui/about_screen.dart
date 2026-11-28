import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../l10n/gen/app_localizations.dart';
import '../logic/error_log.dart';
import '../logic/release_notes.dart';
import '../storage/error_log_store.dart';

/// À propos : version de l'appli et journal des erreurs, que l'on peut enregistrer dans un fichier
/// pour le joindre à un signalement. Rien n'est envoyé nulle part.
class AboutScreen extends StatefulWidget {
  const AboutScreen({
    super.key,
    required this.log,
    required this.saveFile,
    this.loadChangelog = _bundledChangelog,
  });

  final ErrorLogStore log;

  /// Lit le CHANGELOG livré avec l'appli ; remplacé dans les tests.
  final Future<String> Function() loadChangelog;

  /// Enregistre un fichier choisi par l'utilisateur ; renvoie false s'il renonce.
  final Future<bool> Function(String pFileName, Uint8List pBytes) saveFile;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late Future<String> _text = widget.log.read();
  late final Future<ReleaseNotes> _notes = _readNotes();

  Future<ReleaseNotes> _readNotes() async {
    try {
      return latestReleaseNotes(await widget.loadChangelog());
    } on Object {
      return const ReleaseNotes(title: '', sections: {});
    }
  }

  Future<void> _save(String pText) async {
    final vTexts = AppLocalizations.of(context);
    final vMessenger = ScaffoldMessenger.of(context);
    final vSaved = await widget.saveFile(
      'home-journal.txt',
      Uint8List.fromList(utf8.encode(pText)),
    );
    if (vSaved) {
      vMessenger.showSnackBar(SnackBar(content: Text(vTexts.aboutSaved)));
    }
  }

  Future<void> _clear() async {
    await widget.log.clear();
    setState(() {
      _text = widget.log.read();
    });
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.aboutTitle)),
      body: FutureBuilder<String>(
        future: _text,
        builder: (pContext, pSnapshot) {
          final vText = pSnapshot.data ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                vTexts.aboutVersion(appVersion),
                style: Theme.of(pContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(vTexts.aboutPrivacy),
              const SizedBox(height: 16),
              FutureBuilder<ReleaseNotes>(
                future: _notes,
                builder: (pContext, pNotes) => _NotesSection(notes: pNotes.data),
              ),
              Text(vTexts.aboutLogTitle, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (vText.isEmpty)
                Text(vTexts.aboutLogEmpty)
              else ...[
                SelectableText(
                  vText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _save(vText),
                      icon: const Icon(Icons.ios_share),
                      label: Text(vTexts.aboutSave),
                    ),
                    OutlinedButton(onPressed: _clear, child: Text(vTexts.aboutClear)),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

Future<String> _bundledChangelog() => rootBundle.loadString('CHANGELOG.md');

/// Nouveautés de la version, repliées par défaut : le CHANGELOG livré avec l'appli.
class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.notes});

  final ReleaseNotes? notes;

  @override
  Widget build(BuildContext pContext) {
    final vNotes = notes;
    if (vNotes == null || vNotes.isEmpty) {
      return const SizedBox.shrink();
    }
    final vTexts = AppLocalizations.of(pContext);

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(vTexts.aboutNotesTitle, style: Theme.of(pContext).textTheme.titleMedium),
      subtitle: Text(vNotes.title),
      children: [
        for (final vEntry in vNotes.sections.entries)
          if (vEntry.value.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(vEntry.key, style: Theme.of(pContext).textTheme.titleSmall),
              ),
            ),
            for (final vLine in vEntry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(vLine)),
                  ],
                ),
              ),
          ],
      ],
    );
  }
}
