import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../state/pellet_controller.dart';

/// Choix d'une heure : null si l'utilisateur renonce.
typedef TimePicker = Future<TimeOfDay?> Function(BuildContext pContext, TimeOfDay pInitial);

Future<TimeOfDay?> pickStopTime(BuildContext pContext, TimeOfDay pInitial) =>
    showTimePicker(context: pContext, initialTime: pInitial);

/// Stock de pellets (sacs restants et autonomie) et arrêt programmé du soir.
class PelletPlanSection extends StatelessWidget {
  const PelletPlanSection({
    super.key,
    required this.controller,
    this.clock = DateTime.now,
    this.pickTime = pickStopTime,
  });

  final PelletController controller;
  final DateTime Function() clock;
  final TimePicker pickTime;

  Future<void> _editStock(BuildContext pContext) async {
    final vChoice = await showDialog<double?>(
      context: pContext,
      builder: (_) => _StockDialog(initial: _text(controller.runs.stockBags)),
    );
    if (vChoice != null) {
      await controller.setStock(vChoice < 0 ? null : vChoice);
    }
  }

  Future<void> _editStop(BuildContext pContext) async {
    final vStop = controller.runs.stopAtMinute;
    final vPicked = await pickTime(
      pContext,
      vStop == null
          ? const TimeOfDay(hour: 23, minute: 0)
          : TimeOfDay(hour: vStop ~/ 60, minute: vStop % 60),
    );
    if (vPicked != null) {
      await controller.setStopAt(vPicked.hour * 60 + vPicked.minute);
    }
  }

  static String _text(double? pValue) => pValue == null ? '' : '$pValue'.replaceAll('.', ',');

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());

    return ListenableBuilder(
      listenable: controller,
      builder: (pContext, _) {
        final vRuns = controller.runs;
        final vNow = clock();
        final vLeft = vRuns.remainingKg(vNow);
        final vDays = vRuns.autonomyDays(vNow);
        final vStop = vRuns.stopAtMinute;
        final vError = TextStyle(color: Theme.of(pContext).colorScheme.error);

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vTexts.pelletStockTitle, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 4),
              if (vRuns.stockBags == null)
                Text(vTexts.pelletStockNone)
              else if (vLeft == null)
                Text(vTexts.pelletStockNoFlow)
              else ...[
                Text(vTexts.pelletStockLeft(vNumber.format(vLeft / vRuns.bagKg))),
                if (vDays != null)
                  Text(
                    vTexts.pelletStockDays(vDays.round().toString()),
                    style: vRuns.isStockLow(vNow) ? vError : null,
                  ),
                if (vRuns.isStockLow(vNow)) Text(vTexts.pelletStockLow, style: vError),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _editStock(pContext),
                  child: Text(vTexts.pelletStockSet),
                ),
              ),
              Text(vTexts.pelletStopTitle, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                vStop == null
                    ? vTexts.pelletStopNone
                    : vTexts.pelletStopAt(
                        '${(vStop ~/ 60).toString().padLeft(2, '0')}:${(vStop % 60).toString().padLeft(2, '0')}',
                      ),
              ),
              Text(vTexts.pelletStopNote, style: Theme.of(pContext).textTheme.bodySmall),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  if (vStop != null)
                    TextButton(
                      onPressed: () => controller.setStopAt(null),
                      child: Text(vTexts.pelletStopClear),
                    ),
                  TextButton(
                    onPressed: () => _editStop(pContext),
                    child: Text(vTexts.pelletStopSet),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Saisie du nombre de sacs ; rend -1 pour effacer le stock, null si rien ne change.
class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.initial});

  final String initial;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return AlertDialog(
      title: Text(vTexts.pelletStockSet),
      content: TextField(
        controller: _text,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: vTexts.pelletStockBags),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(pContext, -1.0),
          child: Text(vTexts.pelletStockClear),
        ),
        FilledButton(
          onPressed: () {
            final vValue = double.tryParse(_text.text.trim().replaceAll(',', '.'));
            Navigator.pop(pContext, vValue != null && vValue >= 0 ? vValue : null);
          },
          child: Text(vTexts.save),
        ),
      ],
    );
  }
}
