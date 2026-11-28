import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/heating_costs.dart';
import '../state/ac_controller.dart';
import '../state/pellet_controller.dart';

/// Bilan du chauffage : heures de marche de chaque clim et du poêle, énergie et coût estimés avec
/// ce que l'utilisateur a donné (puissance, prix du kWh, prix du sac), et suivi du budget mensuel.
class HeatingReportScreen extends StatelessWidget {
  const HeatingReportScreen({super.key, required this.ac, this.pellet, this.clock = DateTime.now});

  final AcController ac;
  final PelletController? pellet;
  final DateTime Function() clock;

  /// Coût du poêle sur [pDays] jours, null sans poêle, sans débit ou sans prix du sac.
  double? _stoveCost(int pDays, DateTime pNow) {
    final vRuns = pellet?.runs;

    return vRuns?.costFor(vRuns.kgFor(vRuns.hoursOver(pDays, pNow)));
  }

  Future<void> _edit(BuildContext pContext) async {
    final vChoice = await showDialog<_HeatingChoice>(
      context: pContext,
      builder: (_) => _HeatingDialog(ac: ac),
    );
    if (vChoice != null) {
      await ac.setHeating(
        pKwByHost: vChoice.kwByHost,
        pPricePerKwh: vChoice.price,
        pMonthlyBudget: vChoice.budget,
      );
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vLocale = Localizations.localeOf(pContext).toString();
    final vHours = NumberFormat('0.0', vLocale);
    final vMoney = NumberFormat('0.00', vLocale);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.heatingTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([ac, ?pellet]),
        builder: (pContext, _) {
          final vNow = clock();
          final vRuns = ac.runs;
          final vHosts = [for (final vUnit in ac.units) vUnit.host];
          final vClimMonth = vHosts.isEmpty ? 0.0 : vRuns.totalCost(vHosts, 30, vNow);
          final vStoveConfigured = pellet?.stove != null;
          final vStoveMonth = vStoveConfigured ? _stoveCost(30, vNow) : 0.0;
          final vTotal = vClimMonth == null || vStoveMonth == null
              ? null
              : vClimMonth + vStoveMonth;
          final vBudget = vRuns.monthlyBudget;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (ac.units.isEmpty && !vStoveConfigured)
                Text(vTexts.heatingEmpty)
              else ...[
                for (final vUnit in ac.units) ...[
                  Builder(
                    builder: (pContext) {
                      final vLog = vRuns.logOf(vUnit.host);
                      final vWeek = vLog.hoursOver(7, vNow);
                      final vBefore = vLog.hoursPreviousWeek(vNow);
                      final vKwh = vRuns.kwhOver(vUnit.host, 7, vNow);
                      final vCost = vRuns.costOf(vKwh);

                      return Card(
                        child: ListTile(
                          title: Text(vUnit.name),
                          subtitle: Text(
                            [
                              vTexts.heatingHours(vHours.format(vWeek), vHours.format(vBefore)),
                              if (vKwh != null) vTexts.heatingKwh(vHours.format(vKwh)),
                              if (vCost != null) vTexts.heatingCost(vMoney.format(vCost)),
                            ].join('\n'),
                          ),
                          isThreeLine: vKwh != null,
                        ),
                      );
                    },
                  ),
                ],
                if (vStoveConfigured)
                  Card(
                    child: ListTile(
                      title: Text(pellet!.stove!.name),
                      subtitle: Text(_stoveText(vTexts, vHours, vMoney, vNow)),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(vTexts.heatingMonthTitle, style: Theme.of(pContext).textTheme.titleMedium),
                const SizedBox(height: 4),
                if (vTotal == null)
                  Text(vTexts.heatingMissing)
                else ...[
                  Text(vTexts.heatingMonthTotal(vMoney.format(vTotal))),
                  if (vBudget != null)
                    Text(switch (budgetState(vTotal, vBudget)) {
                      BudgetState.ok => vTexts.heatingBudgetOk(vMoney.format(vBudget)),
                      BudgetState.near => vTexts.heatingBudgetNear(vMoney.format(vBudget)),
                      BudgetState.over => vTexts.heatingBudgetOver(vMoney.format(vBudget)),
                    }),
                  Text(
                    vTexts.heatingDegree(vMoney.format(degreeSaving(vTotal))),
                    style: Theme.of(pContext).textTheme.bodySmall,
                  ),
                ],
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => _edit(pContext), child: Text(vTexts.heatingSet)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _stoveText(
    AppLocalizations pTexts,
    NumberFormat pHours,
    NumberFormat pMoney,
    DateTime pNow,
  ) {
    final vRuns = pellet!.runs;
    final vWeek = vRuns.hoursOver(7, pNow);
    final vCost = _stoveCost(7, pNow);

    return [
      pTexts.heatingHours(pHours.format(vWeek), pHours.format(vRuns.hoursPreviousWeek(pNow))),
      if (vCost != null) pTexts.heatingCost(pMoney.format(vCost)),
    ].join('\n');
  }
}

/// Ce que l'utilisateur a saisi dans la boîte des réglages de coût.
typedef _HeatingChoice = ({Map<String, double> kwByHost, double? price, double? budget});

/// Saisie de la puissance de chaque clim, du prix du kWh et du budget mensuel. Les champs vivent
/// dans cette boîte.
class _HeatingDialog extends StatefulWidget {
  const _HeatingDialog({required this.ac});

  final AcController ac;

  @override
  State<_HeatingDialog> createState() => _HeatingDialogState();
}

class _HeatingDialogState extends State<_HeatingDialog> {
  late final _price = TextEditingController(text: _text(widget.ac.runs.pricePerKwh));
  late final _budget = TextEditingController(text: _text(widget.ac.runs.monthlyBudget));
  late final _kw = {
    for (final vUnit in widget.ac.units)
      vUnit.host: TextEditingController(text: _text(widget.ac.runs.kwByHost[vUnit.host])),
  };

  static String _text(double? pValue) => pValue == null ? '' : '$pValue'.replaceAll('.', ',');

  static double? _parse(String pText) {
    final vValue = double.tryParse(pText.trim().replaceAll(',', '.'));

    return vValue != null && vValue > 0 ? vValue : null;
  }

  @override
  void dispose() {
    _price.dispose();
    _budget.dispose();
    for (final vController in _kw.values) {
      vController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    const vKeyboard = TextInputType.numberWithOptions(decimal: true);

    return AlertDialog(
      title: Text(vTexts.heatingSet),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _price,
              keyboardType: vKeyboard,
              decoration: InputDecoration(labelText: vTexts.heatingPrice),
            ),
            TextField(
              controller: _budget,
              keyboardType: vKeyboard,
              decoration: InputDecoration(labelText: vTexts.heatingBudget),
            ),
            for (final vUnit in widget.ac.units)
              TextField(
                controller: _kw[vUnit.host],
                keyboardType: vKeyboard,
                decoration: InputDecoration(
                  labelText: vTexts.heatingKw(vUnit.name),
                  helperText: vTexts.heatingKwHelp,
                  helperMaxLines: 3,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop<_HeatingChoice>(pContext, (
            kwByHost: {
              for (final vEntry in _kw.entries)
                if (_parse(vEntry.value.text) != null) vEntry.key: _parse(vEntry.value.text)!,
            },
            price: _parse(_price.text),
            budget: _parse(_budget.text),
          )),
          child: Text(vTexts.save),
        ),
      ],
    );
  }
}
