import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/ac_units.dart';
import '../logic/automations.dart';
import '../logic/rule_form.dart';
import '../state/ac_controller.dart';
import '../state/plan_controller.dart';

String _metricName(AppLocalizations pTexts, AutoMetric pMetric) =>
    pMetric == AutoMetric.humidity ? pTexts.ruleHumidity : pTexts.ruleTemperature;

String _sideName(AppLocalizations pTexts, AutoSide pSide) =>
    pSide == AutoSide.above ? pTexts.ruleAbove : pTexts.ruleBelow;

String _actionName(AppLocalizations pTexts, AutoActionKind pAction) => switch (pAction) {
  AutoActionKind.powerOff => pTexts.ruleActionOff,
  AutoActionKind.cool => pTexts.ruleActionCool,
  AutoActionKind.heat => pTexts.ruleActionHeat,
  AutoActionKind.auto => pTexts.ruleActionAuto,
};

/// Règles de seuil : quand l'humidité ou la température du capteur passe un seuil, la clim reçoit
/// une action.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, required this.plan, required this.ac});

  final PlanController plan;
  final AcController ac;

  Future<void> _add(BuildContext pContext) async {
    final vRule = await showDialog<AutoRule>(
      context: pContext,
      builder: (_) => _RuleDialog(units: ac.units, existing: plan.rules),
    );
    if (vRule != null) {
      await plan.setRules([...plan.rules, vRule]);
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vNumber = NumberFormat('0.#', Localizations.localeOf(pContext).toString());

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.rulesTitle)),
      floatingActionButton: ac.units.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(pContext),
              icon: const Icon(Icons.add),
              label: Text(vTexts.rulesAdd),
            ),
      body: ListenableBuilder(
        listenable: plan,
        builder: (pContext, _) {
          if (ac.units.isEmpty) {
            return Padding(padding: const EdgeInsets.all(16), child: Text(vTexts.planNoUnits));
          }
          if (plan.rules.isEmpty) {
            return Padding(padding: const EdgeInsets.all(16), child: Text(vTexts.rulesEmpty));
          }

          return ListView(
            children: [
              for (final vRule in plan.rules)
                ListTile(
                  title: Text(vRule.name),
                  subtitle: Text(
                    vTexts.ruleSummary(
                      ac.units.where((pUnit) => pUnit.host == vRule.acHost).firstOrNull?.name ??
                          vRule.acHost,
                      _metricName(vTexts, vRule.metric),
                      _sideName(vTexts, vRule.side),
                      vNumber.format(vRule.threshold),
                      _actionName(vTexts, vRule.action),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: vTexts.ruleRemove,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => plan.setRules([
                      for (final vOther in plan.rules)
                        if (vOther != vRule) vOther,
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({required this.units, required this.existing});

  final List<AcUnit> units;
  final List<AutoRule> existing;

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _name = TextEditingController();
  final _threshold = TextEditingController();
  final _setpoint = TextEditingController();
  late String _host = widget.units.first.host;
  var _metric = AutoMetric.humidity;
  var _side = AutoSide.above;
  var _action = AutoActionKind.powerOff;
  RuleProblem? _problem;

  @override
  void dispose() {
    _name.dispose();
    _threshold.dispose();
    _setpoint.dispose();
    super.dispose();
  }

  void _save() {
    final vBuilt = buildRule(
      pName: _name.text,
      pAcHost: _host,
      pMetric: _metric,
      pSide: _side,
      pThreshold: _threshold.text,
      pAction: _action,
      pSetpoint: _setpoint.text,
      pExisting: widget.existing,
    );
    if (vBuilt.rule != null) {
      Navigator.pop(context, vBuilt.rule);
    } else {
      setState(() => _problem = vBuilt.problem);
    }
  }

  String? _problemText(AppLocalizations pTexts) => switch (_problem) {
    null => null,
    RuleProblem.noThreshold => pTexts.ruleProblemThreshold,
    RuleProblem.thresholdOutOfRange => pTexts.ruleProblemRange,
    RuleProblem.badSetpoint => pTexts.ruleProblemSetpoint,
  };

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return AlertDialog(
      title: Text(vTexts.rulesAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: vTexts.ruleNameLabel),
            ),
            if (widget.units.length > 1)
              DropdownButton<String>(
                value: _host,
                isExpanded: true,
                items: [
                  for (final vUnit in widget.units)
                    DropdownMenuItem(value: vUnit.host, child: Text(vUnit.name)),
                ],
                onChanged: (pHost) => setState(() => _host = pHost ?? _host),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final vMetric in AutoMetric.values)
                  ChoiceChip(
                    label: Text(_metricName(vTexts, vMetric)),
                    selected: _metric == vMetric,
                    onSelected: (_) => setState(() => _metric = vMetric),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final vSide in AutoSide.values)
                  ChoiceChip(
                    label: Text(_sideName(vTexts, vSide)),
                    selected: _side == vSide,
                    onSelected: (_) => setState(() => _side = vSide),
                  ),
              ],
            ),
            TextField(
              controller: _threshold,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(labelText: vTexts.ruleThresholdLabel),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final vAction in AutoActionKind.values)
                  ChoiceChip(
                    label: Text(_actionName(vTexts, vAction)),
                    selected: _action == vAction,
                    onSelected: (_) => setState(() => _action = vAction),
                  ),
              ],
            ),
            if (_action != AutoActionKind.powerOff)
              TextField(
                controller: _setpoint,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: vTexts.ruleSetpointLabel),
              ),
            if (_problemText(vTexts) case final String vMessage)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(vMessage, style: TextStyle(color: Theme.of(pContext).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.scheduleCancel)),
        FilledButton(onPressed: _save, child: Text(vTexts.scheduleSave)),
      ],
    );
  }
}
