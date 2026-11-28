import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';

/// Choix d'une heure entière de la journée, ou « Aucune ».
class HourChoice extends StatelessWidget {
  const HourChoice({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<int?>(
          value: value,
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(vTexts.heatingOffNone)),
            for (var vHour = 0; vHour < 24; vHour++)
              DropdownMenuItem<int?>(value: vHour, child: Text(vTexts.heatingHourValue(vHour))),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
