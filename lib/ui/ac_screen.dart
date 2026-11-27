import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/ac_units.dart';
import '../logic/daikin.dart';
import '../state/ac_controller.dart';
import '../state/sensors_controller.dart';
import 'theme.dart';

/// Climatisations Daikin de la maison : état, commandes, et lien avec le capteur de la pièce.
class AcScreen extends StatefulWidget {
  const AcScreen({super.key, required this.controller, required this.sensors});

  final AcController controller;
  final SensorsController sensors;

  @override
  State<AcScreen> createState() => _AcScreenState();
}

class _AcScreenState extends State<AcScreen> {
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refresh());
  }

  void _say(String pMessage) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pMessage)));

  String _problemText(AppLocalizations pTexts, AddProblem pProblem) => switch (pProblem) {
    AddProblem.notPrivate => pTexts.acAddProblemNotPrivate,
    AddProblem.alreadyKnown => pTexts.acAddProblemKnown,
    AddProblem.unreachable => pTexts.acAddProblemUnreachable,
  };

  Future<void> _add(String pHost, {String? pName}) async {
    final vTexts = AppLocalizations.of(context);
    final vProblem = await widget.controller.add(pHost, pName: pName);
    if (vProblem != null && mounted) {
      _say(_problemText(vTexts, vProblem));
    }
  }

  Future<void> _askAddress() async {
    final vTexts = AppLocalizations.of(context);
    final vHost = TextEditingController();
    final vName = TextEditingController();
    final vOk = await showDialog<bool>(
      context: context,
      builder: (pDialog) => AlertDialog(
        title: Text(vTexts.acAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: vHost,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: vTexts.acAddressLabel),
            ),
            TextField(controller: vName, decoration: InputDecoration(labelText: vTexts.acNameLabel)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(pDialog, false), child: Text(vTexts.cancel)),
          FilledButton(onPressed: () => Navigator.pop(pDialog, true), child: Text(vTexts.save)),
        ],
      ),
    );
    final vHostText = vHost.text;
    final vNameText = vName.text;
    vHost.dispose();
    vName.dispose();
    if (vOk ?? false) {
      await _add(vHostText, pName: vNameText);
    }
  }

  Future<void> _search() async {
    final vTexts = AppLocalizations.of(context);
    setState(() => _searching = true);
    final vKnown = widget.controller.units.map((pUnit) => pUnit.host).toSet();
    List<String> vFound;
    try {
      vFound = (await widget.controller.discover().toList()).where((pHost) => !vKnown.contains(pHost)).toList();
    } on Object {
      vFound = [];
    }
    if (!mounted) {
      return;
    }
    setState(() => _searching = false);
    if (vFound.isEmpty) {
      _say(vTexts.acFoundNone);
      return;
    }
    final vChosen = await showDialog<String>(
      context: context,
      builder: (pDialog) => SimpleDialog(
        title: Text(vTexts.acSearch),
        children: [
          for (final vHost in vFound)
            SimpleDialogOption(onPressed: () => Navigator.pop(pDialog, vHost), child: Text(vHost)),
        ],
      ),
    );
    if (vChosen != null) {
      await _add(vChosen);
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(
        title: Text(vTexts.acTitle),
        actions: [
          IconButton(
            tooltip: vTexts.acRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(widget.controller.refresh()),
          ),
          IconButton(
            tooltip: vTexts.acSearch,
            icon: const Icon(Icons.wifi_find),
            onPressed: _searching ? null : _search,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _askAddress,
        icon: const Icon(Icons.add),
        label: Text(vTexts.acAdd),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.controller, widget.sensors]),
        builder: (pContext, _) {
          final vUnits = widget.controller.units;
          if (_searching) {
            return Center(child: Text(vTexts.acSearching));
          }
          if (vUnits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(vTexts.acEmpty, textAlign: TextAlign.center),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: vUnits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, pIndex) => AcCard(
              unit: vUnits[pIndex],
              controller: widget.controller,
              sensors: widget.sensors,
            ),
          );
        },
      ),
    );
  }
}

/// Carte d'une climatisation.
class AcCard extends StatelessWidget {
  const AcCard({super.key, required this.unit, required this.controller, required this.sensors});

  final AcUnit unit;
  final AcController controller;
  final SensorsController sensors;

  Future<void> _command(BuildContext pContext, Future<bool> Function() pSend) async {
    final vTexts = AppLocalizations.of(pContext);
    final vOk = await pSend();
    if (!vOk && pContext.mounted) {
      ScaffoldMessenger.of(
        pContext,
      ).showSnackBar(SnackBar(content: Text(vTexts.acCommandFailed)));
    }
  }

  Future<void> _confirmRemove(BuildContext pContext) async {
    final vTexts = AppLocalizations.of(pContext);
    final vOk = await showDialog<bool>(
      context: pContext,
      builder: (pDialog) => AlertDialog(
        content: Text(vTexts.acRemoveConfirm(unit.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(pDialog, false), child: Text(vTexts.cancel)),
          FilledButton(onPressed: () => Navigator.pop(pDialog, true), child: Text(vTexts.acRemove)),
        ],
      ),
    );
    if (vOk ?? false) {
      await controller.remove(unit.host);
    }
  }

  static String _modeLabel(AppLocalizations pTexts, DaikinMode pMode) => switch (pMode) {
    DaikinMode.auto => pTexts.acModeAuto,
    DaikinMode.cool => pTexts.acModeCool,
    DaikinMode.heat => pTexts.acModeHeat,
    DaikinMode.dry => pTexts.acModeDry,
    DaikinMode.fan => pTexts.acModeFan,
  };

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vTheme = Theme.of(pContext).textTheme;
    final vColors = HomeColors.of(pContext);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());
    final vStatus = controller.statusOf(unit.host);
    final vState = vStatus?.state;
    final vControl = vState?.control;
    final vSensorNames = sensors.sensors.map((pSensor) => pSensor.name).toList();
    final vLinked = sensors.sensors.where((pSensor) => pSensor.name == unit.sensorName).firstOrNull;
    final vReading = vLinked?.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(unit.name, style: vTheme.titleMedium)),
                IconButton(
                  tooltip: vTexts.acRemove,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmRemove(pContext),
                ),
              ],
            ),
            if (vStatus == null)
              const LinearProgressIndicator()
            else if (vControl == null)
              Text(vTexts.acUnreachable, style: TextStyle(color: vColors.warning))
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(vTexts.acPower),
                value: vControl.power,
                onChanged: (pOn) =>
                    _command(pContext, () => controller.setPower(unit.host, pOn: pOn)),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final vMode in [DaikinMode.auto, DaikinMode.cool, DaikinMode.heat])
                    ChoiceChip(
                      label: Text(_modeLabel(vTexts, vMode)),
                      selected: vControl.mode == vMode,
                      onSelected: (_) =>
                          _command(pContext, () => controller.setMode(unit.host, vMode)),
                    ),
                  if (vControl.mode == DaikinMode.dry || vControl.mode == DaikinMode.fan)
                    ChoiceChip(
                      label: Text(_modeLabel(vTexts, vControl.mode!)),
                      selected: true,
                      onSelected: null,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (vControl.setpointDegrees == null)
                Text(vTexts.acNoSetpoint)
              else
                Row(
                  children: [
                    IconButton(
                      tooltip: vTexts.acLower,
                      icon: const Icon(Icons.remove),
                      onPressed: () => _command(
                        pContext,
                        () => controller.setSetpoint(unit.host, vControl.setpointDegrees! - 0.5),
                      ),
                    ),
                    Text(
                      vTexts.acSetpoint(vNumber.format(vControl.setpointDegrees!)),
                      style: vTheme.titleMedium?.copyWith(color: vColors.temperature),
                    ),
                    IconButton(
                      tooltip: vTexts.acRaise,
                      icon: const Icon(Icons.add),
                      onPressed: () => _command(
                        pContext,
                        () => controller.setSetpoint(unit.host, vControl.setpointDegrees! + 0.5),
                      ),
                    ),
                  ],
                ),
              if (vState!.sensors.indoorTemp != null)
                Text(vTexts.acIndoor(vNumber.format(vState.sensors.indoorTemp!))),
              if (vState.sensors.outdoorTemp != null)
                Text(vTexts.acOutdoor(vNumber.format(vState.sensors.outdoorTemp!))),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(vTexts.acSensor),
                const SizedBox(width: 12),
                DropdownButton<String?>(
                  value: vLinked?.name,
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(vTexts.acSensorNone)),
                    for (final vName in vSensorNames)
                      DropdownMenuItem<String?>(value: vName, child: Text(vName)),
                  ],
                  onChanged: (pName) => unawaited(controller.linkSensor(unit.host, pName)),
                ),
              ],
            ),
            if (vReading != null)
              Text(
                vTexts.acSensorReading(vNumber.format(vReading.temp), vNumber.format(vReading.humidity)),
                style: vTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
