import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/alerts.dart';
import '../state/plan_controller.dart';
import 'value_slider.dart';

/// Seuil d'humidité des alertes.
class HumiditySection extends StatefulWidget {
  const HumiditySection({super.key, required this.plan});

  final PlanController plan;

  @override
  State<HumiditySection> createState() => HumiditySectionState();
}

class HumiditySectionState extends State<HumiditySection> {
  double? _dragging;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vValue = _dragging ?? widget.plan.humidityAlertAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(vTexts.planHumidityTitle, style: Theme.of(pContext).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(vTexts.planHumidityHint(vValue.round().toString())),
        ValueSlider(
          valueText: '${vValue.round()} %',
          value: vValue,
          min: humidityAlertMin,
          max: humidityAlertMax,
          minText: '${humidityAlertMin.round()} %',
          maxText: '${humidityAlertMax.round()} %',
          divisions: (humidityAlertMax - humidityAlertMin).round(),
          onChanged: (pNew) => setState(() => _dragging = pNew),
          onChangeEnd: (pNew) async {
            await widget.plan.setHumidityAlertAt(pNew);
            if (mounted) {
              setState(() => _dragging = null);
            }
          },
        ),
      ],
    );
  }
}
