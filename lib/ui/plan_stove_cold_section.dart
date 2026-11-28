import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../state/plan_controller.dart';
import '../storage/plan_store.dart';
import 'units_scope.dart';

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
    final vUnits = UnitsScope.of(pContext);
    final vValue = _dragging ?? widget.plan.stoveColdBelow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(vTexts.planStoveTitle, style: Theme.of(pContext).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(vTexts.planStoveHint(vUnits.temp(vValue))),
        Slider(
          value: vValue,
          min: stoveColdMin,
          max: stoveColdMax,
          divisions: ((stoveColdMax - stoveColdMin) * 2).round(),
          label: vUnits.temp(vValue),
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
