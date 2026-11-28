import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../storage/background_files.dart';

/// Interrupteur du résumé du matin, envoyé par le service d'arrière-plan.
class SummarySection extends StatefulWidget {
  const SummarySection({required this.files});

  final BackgroundFiles files;

  @override
  State<SummarySection> createState() => SummarySectionState();
}

class SummarySectionState extends State<SummarySection> {
  late Future<bool> _enabled = widget.files.summaryEnabled();

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return FutureBuilder<bool>(
      future: _enabled,
      builder: (pContext, pSnapshot) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(vTexts.planSummaryTitle),
        subtitle: Text(vTexts.planSummaryHint),
        value: pSnapshot.data ?? false,
        onChanged: (pOn) async {
          await widget.files.setSummaryEnabled(pOn: pOn);
          if (mounted) {
            setState(() {
              _enabled = widget.files.summaryEnabled();
            });
          }
        },
      ),
    );
  }
}
