import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../storage/detail_log.dart';

/// Journal détaillé : un interrupteur, puis les lignes notées que l'on peut enregistrer ou vider.
class AboutDetailSection extends StatefulWidget {
  const AboutDetailSection({super.key, required this.detail, required this.saveFile});

  final DetailLog detail;
  final Future<bool> Function(String pFileName, Uint8List pBytes) saveFile;

  @override
  State<AboutDetailSection> createState() => _AboutDetailSectionState();
}

class _AboutDetailSectionState extends State<AboutDetailSection> {
  late Future<(bool, String)> _state = _load();

  Future<(bool, String)> _load() async => (await widget.detail.isOn(), await widget.detail.read());

  void _reload() => setState(() {
    _state = _load();
  });

  Future<void> _switch(bool pOn) async {
    await widget.detail.setOn(pOn: pOn);
    _reload();
  }

  Future<void> _clear() async {
    await widget.detail.clear();
    _reload();
  }

  Future<void> _save(String pText) async {
    final vTexts = AppLocalizations.of(context);
    final vMessenger = ScaffoldMessenger.of(context);
    final vSaved = await widget.saveFile(
      'home-journal-detail.txt',
      Uint8List.fromList(utf8.encode(pText)),
    );
    if (vSaved) {
      vMessenger.showSnackBar(SnackBar(content: Text(vTexts.aboutSaved)));
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return FutureBuilder<(bool, String)>(
      future: _state,
      builder: (pContext, pSnapshot) {
        final vOn = pSnapshot.data?.$1 ?? false;
        final vText = pSnapshot.data?.$2 ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(vTexts.aboutDetailTitle),
              subtitle: Text(vTexts.aboutDetailHelp),
              value: vOn,
              onChanged: _switch,
            ),
            if (vText.isEmpty)
              Text(vTexts.aboutDetailEmpty)
            else
              SelectableText(vText, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (vText.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => _save(vText),
                    icon: const Icon(Icons.ios_share),
                    label: Text(vTexts.aboutSave),
                  ),
                if (vText.isNotEmpty)
                  OutlinedButton(onPressed: _clear, child: Text(vTexts.aboutClear)),
                OutlinedButton(onPressed: _reload, child: Text(vTexts.aboutDetailReload)),
              ],
            ),
          ],
        );
      },
    );
  }
}
