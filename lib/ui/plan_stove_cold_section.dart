import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../state/plan_controller.dart';
import '../storage/plan_store.dart';

/// Seuil de froid : sous cette température, la clim peut chauffer en plus du poêle.
class StoveColdSection extends StatefulWidget {
  const StoveColdSection({super.key, required this.plan});

  final PlanController plan;

  @override
  State<StoveColdSection> createState() => StoveColdSectionState();
}

class StoveColdSectionState extends State<StoveColdSection> {
  double? _dragging;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());
    final vValue = _dragging ?? widget.plan.stoveColdBelow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(vTexts.planStoveTitle, style: Theme.of(pContext).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(vTexts.planStoveHint(vNumber.format(vValue))),
        Slider(
          value: vValue,
          min: stoveColdMin,
          max: stoveColdMax,
          divisions: ((stoveColdMax - stoveColdMin) * 2).round(),
          label: '${vNumber.format(vValue)} °C',
          onChanged: (pNew) => setState(() => _dragging = pNew),
          onChangeEnd: (pNew) async {
            await widget.plan.setStoveColdBelow(pNew);
            if (mounted) {
              setState(() => _dragging = null);
            }
          },
        ),
      ],
    );
  }
}
