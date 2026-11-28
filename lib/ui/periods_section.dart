import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/periods.dart';
import '../logic/reading.dart';

/// Périodes de mesure d'un capteur séparées par un long trou. Chacune peut devenir un capteur à
/// part, pour la ranger dans la pièce où il se trouvait.
class PeriodsSection extends StatelessWidget {
  const PeriodsSection({super.key, required this.sensor, required this.onSplit});

  final Sensor sensor;

  /// Déplace une période vers un capteur du nom donné ; renvoie false si c'est refusé.
  final Future<bool> Function(DateTime pFrom, DateTime pTo, String pName) onSplit;

  Future<void> _split(BuildContext pContext, ReadingPeriod pPeriod) async {
    final vTexts = AppLocalizations.of(pContext);
    final vMessenger = ScaffoldMessenger.of(pContext);
    final vName = await showDialog<String>(context: pContext, builder: (_) => const _SplitDialog());
    if (vName == null) {
      return;
    }
    final vDone = await onSplit(pPeriod.from, pPeriod.to, vName);
    vMessenger.hideCurrentSnackBar();
    vMessenger.showSnackBar(
      SnackBar(
        content: Text(vDone ? vTexts.periodsSplitDone(vName.trim()) : vTexts.periodsSplitFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext pContext) {
    final vPeriods = findPeriods(sensor.readings);
    if (vPeriods.length < 2) {
      return const SizedBox.shrink();
    }
    final vTexts = AppLocalizations.of(pContext);
    final vLocale = Localizations.localeOf(pContext).toString();
    final vDate = DateFormat.yMMMd(vLocale);
    final vNumber = NumberFormat('0.0', vLocale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(vTexts.periodsTitle, style: Theme.of(pContext).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(vTexts.periodsHint, style: Theme.of(pContext).textTheme.bodySmall),
        for (final vPeriod in vPeriods)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(vTexts.periodsDates(vDate.format(vPeriod.from), vDate.format(vPeriod.to))),
            subtitle: Text(vTexts.periodsStats(vPeriod.count, vNumber.format(vPeriod.avgTemp))),
            trailing: TextButton(
              onPressed: () => _split(pContext, vPeriod),
              child: Text(vTexts.periodsSplit),
            ),
          ),
      ],
    );
  }
}

/// Saisie du nom du capteur qui recevra la période. Le champ vit dans cette boîte.
class _SplitDialog extends StatefulWidget {
  const _SplitDialog();

  @override
  State<_SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<_SplitDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return AlertDialog(
      title: Text(vTexts.periodsSplitTitle),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(hintText: vTexts.periodsSplitHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(pContext, _field.text),
          child: Text(vTexts.periodsSplit),
        ),
      ],
    );
  }
}
