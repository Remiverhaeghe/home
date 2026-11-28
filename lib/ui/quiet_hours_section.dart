import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/heating_costs.dart';
import '../storage/background_files.dart';
import 'alert_history_screen.dart';
import 'hour_choice.dart';

/// Plage d'heures silencieuses : seul le gel sonne. Écrite dans un fichier lu par le service.
class QuietHoursSection extends StatefulWidget {
  const QuietHoursSection({super.key, required this.files});

  final BackgroundFiles files;

  @override
  State<QuietHoursSection> createState() => _QuietHoursSectionState();
}

class _QuietHoursSectionState extends State<QuietHoursSection> {
  int? _from;
  int? _to;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.files.quietHours().then((pQuiet) {
      if (mounted) {
        setState(() {
          _from = pQuiet?.startHour;
          _to = pQuiet?.endHour;
          _loaded = true;
        });
      }
    });
  }

  /// Une plage ne s'écrit que complète et non vide ; sinon le fichier est vidé.
  Future<void> _save() => widget.files.setQuietHours(
    _from != null && _to != null ? OffPeak(startHour: _from!, endHour: _to!) : null,
  );

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    if (!_loaded) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(vTexts.quietTitle, style: Theme.of(pContext).textTheme.titleMedium),
        Text(vTexts.quietHint),
        HourChoice(
          key: const Key('quiet-from'),
          label: vTexts.quietFrom,
          value: _from,
          onChanged: (pHour) {
            setState(() => _from = pHour);
            _save();
          },
        ),
        HourChoice(
          key: const Key('quiet-to'),
          label: vTexts.quietTo,
          value: _to,
          onChanged: (pHour) {
            setState(() => _to = pHour);
            _save();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: Text(vTexts.alertHistoryOpen),
          onTap: () => Navigator.of(
            pContext,
          ).push(MaterialPageRoute<void>(builder: (_) => AlertHistoryScreen(files: widget.files))),
        ),
      ],
    );
  }
}
