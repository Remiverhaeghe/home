import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/pellet_runs.dart';
import '../state/pellet_controller.dart';

/// Heures de marche du poêle sur 7 et 30 jours, et pellets estimés avec le débit donné.
class PelletUsageSection extends StatelessWidget {
  const PelletUsageSection({super.key, required this.controller, this.clock = DateTime.now});

  final PelletController controller;
  final DateTime Function() clock;

  Future<void> _edit(BuildContext pContext) async {
    final vRuns = controller.runs;
    final vChoice = await showDialog<({double? flow, double bag})>(
      context: pContext,
      builder: (_) => _FlowDialog(flow: vRuns.kgPerHour, bag: vRuns.bagKg),
    );
    if (vChoice != null) {
      await controller.setFlow(pKgPerHour: vChoice.flow, pBagKg: vChoice.bag);
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());

    return ListenableBuilder(
      listenable: controller,
      builder: (pContext, _) {
        final vRuns = controller.runs;
        final vNow = clock();
        final vWeek = vRuns.hoursOver(7, vNow);
        final vMonth = vRuns.hoursOver(30, vNow);
        final vKgWeek = vRuns.kgFor(vWeek);
        final vKgMonth = vRuns.kgFor(vMonth);

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vTexts.pelletUsageTitle, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(vTexts.pelletUsageHours(vNumber.format(vWeek), vNumber.format(vMonth))),
              if (vKgWeek != null && vKgMonth != null)
                Text(
                  vTexts.pelletUsageKg(
                    vNumber.format(vKgWeek),
                    vNumber.format(vKgMonth),
                    vNumber.format(vKgMonth / vRuns.bagKg),
                  ),
                )
              else
                Text(vTexts.pelletUsageNoFlow, style: Theme.of(pContext).textTheme.bodySmall),
              Text(vTexts.pelletUsageNote, style: Theme.of(pContext).textTheme.bodySmall),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _edit(pContext),
                  child: Text(vTexts.pelletUsageSet),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Saisie du débit et du poids d'un sac. Les champs vivent dans cette boîte.
class _FlowDialog extends StatefulWidget {
  const _FlowDialog({required this.flow, required this.bag});

  final double? flow;
  final double bag;

  @override
  State<_FlowDialog> createState() => _FlowDialogState();
}

class _FlowDialogState extends State<_FlowDialog> {
  late final _flow = TextEditingController(text: _text(widget.flow));
  late final _bag = TextEditingController(text: _text(widget.bag));

  static String _text(double? pValue) => pValue == null ? '' : '$pValue'.replaceAll('.', ',');

  static double? _parse(String pText) => double.tryParse(pText.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _flow.dispose();
    _bag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return AlertDialog(
      title: Text(vTexts.pelletUsageSet),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _flow,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: vTexts.pelletUsageFlow,
              helperText: vTexts.pelletUsageFlowHelp,
              helperMaxLines: 3,
            ),
          ),
          TextField(
            controller: _bag,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: vTexts.pelletUsageBag),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        FilledButton(
          onPressed: () {
            final vFlow = _parse(_flow.text);
            final vBag = _parse(_bag.text);
            Navigator.pop(pContext, (
              flow: vFlow != null && vFlow > 0 ? vFlow : null,
              bag: vBag != null && vBag > 0 ? vBag : defaultBagKg,
            ));
          },
          child: Text(vTexts.save),
        ),
      ],
    );
  }
}
