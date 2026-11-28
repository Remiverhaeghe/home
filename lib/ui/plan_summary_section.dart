import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../storage/background_files.dart';

/// Heures proposées pour l'envoi du résumé.
const summaryHourChoices = [5, 6, 7, 8, 9, 10, 11, 12];

/// Interrupteur du résumé du matin, envoyé par le service d'arrière-plan, et heure d'envoi.
class SummarySection extends StatefulWidget {
  const SummarySection({super.key, required this.files});

  final BackgroundFiles files;

  @override
  State<SummarySection> createState() => SummarySectionState();
}

class SummarySectionState extends State<SummarySection> {
  late Future<(bool, int)> _state = _load();

  Future<(bool, int)> _load() async =>
      (await widget.files.summaryEnabled(), await widget.files.summaryStartHour());

  void _reload() {
    setState(() {
      _state = _load();
    });
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return FutureBuilder<(bool, int)>(
      future: _state,
      builder: (pContext, pSnapshot) {
        final vOn = pSnapshot.data?.$1 ?? false;
        final vHour = pSnapshot.data?.$2 ?? 8;

        return Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(vTexts.planSummaryTitle),
              subtitle: Text(vTexts.planSummaryHint),
              value: vOn,
              onChanged: (pOn) async {
                await widget.files.setSummaryEnabled(pOn: pOn);
                if (mounted) {
                  _reload();
                }
              },
            ),
            if (vOn)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(vTexts.planSummaryHour),
                trailing: DropdownButton<int>(
                  key: const Key('summary-hour'),
                  value: summaryHourChoices.contains(vHour) ? vHour : null,
                  items: [
                    for (final vChoice in summaryHourChoices)
                      DropdownMenuItem(
                        value: vChoice,
                        child: Text(vTexts.planSummaryHourValue(vChoice)),
                      ),
                  ],
                  onChanged: (pChoice) async {
                    if (pChoice == null) {
                      return;
                    }
                    await widget.files.setSummaryStartHour(pChoice);
                    if (mounted) {
                      _reload();
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
