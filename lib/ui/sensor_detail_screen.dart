import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/climate_stats.dart';
import '../logic/reading.dart';
import 'analysis_section.dart';
import 'day_chart.dart';
import 'theme.dart';

/// Détail d'un capteur : courbes des quatorze derniers jours, minimum et maximum.
class SensorDetailScreen extends StatefulWidget {
  const SensorDetailScreen({
    super.key,
    required this.sensor,
    this.onRename,
    this.onEditPlace,
    this.outdoor = const [],
  });

  final Sensor sensor;

  /// Range le nom donné au capteur ; sans lui, le nom ne se change pas ici.
  final Future<void> Function(String pLabel)? onRename;

  /// Ouvre la saisie de l'emplacement ; sans lui, le bouton n'apparaît pas.
  final Future<void> Function()? onEditPlace;

  /// Relevés extérieurs pour comparer ; vides sans météo.
  final List<Reading> outdoor;

  /// Nombre de jours montrés sur les courbes.
  static const shownDays = 14;

  @override
  State<SensorDetailScreen> createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen> {
  late var _title = widget.sensor.title;

  Sensor get sensor => widget.sensor;

  Future<void> _rename() async {
    final vLabel = await showDialog<String>(
      context: context,
      builder: (_) =>
          _RenameDialog(current: _title == sensor.name ? '' : _title, device: sensor.name),
    );
    if (vLabel == null) {
      return;
    }
    await widget.onRename?.call(vLabel);
    if (mounted) {
      setState(() => _title = vLabel.trim().isEmpty ? sensor.name : vLabel.trim());
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vTheme = Theme.of(pContext).textTheme;
    final vColors = HomeColors.of(pContext);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());
    final vAll = dailyAverages(sensor.readings);
    final vDays = vAll.length > SensorDetailScreen.shownDays
        ? vAll.sublist(vAll.length - SensorDetailScreen.shownDays)
        : vAll;
    final vTemps = vDays.map((pDay) => pDay.temp);
    final vHumidities = vDays.map((pDay) => pDay.humidity);

    return Scaffold(
      appBar: AppBar(
        title: Text(vTexts.detailTitle(_title)),
        actions: [
          if (widget.onEditPlace != null)
            IconButton(
              tooltip: vTexts.placeEdit,
              icon: const Icon(Icons.place_outlined),
              onPressed: widget.onEditPlace,
            ),
          if (widget.onRename != null)
            IconButton(
              tooltip: vTexts.detailRename,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _rename,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(vTexts.detailReadings(sensor.readings.length), style: vTheme.bodySmall),
          AnalysisSection(readings: sensor.readings, outdoor: widget.outdoor),
          const SizedBox(height: 16),
          Text(vTexts.detailChartTitle, style: vTheme.titleMedium),
          const SizedBox(height: 12),
          if (vDays.length < 2)
            Text(vTexts.detailNotEnough)
          else ...[
            DayChart(days: vDays, semanticLabel: vTexts.detailChartLabel(vDays.length)),
            const SizedBox(height: 16),
            Text(
              vTexts.detailTemperature,
              style: vTheme.titleSmall?.copyWith(color: vColors.temperature),
            ),
            Text(
              vTexts.detailRange(
                vTexts.temperatureValue(
                  vNumber.format(vTemps.reduce((pA, pB) => pA < pB ? pA : pB)),
                ),
                vTexts.temperatureValue(
                  vNumber.format(vTemps.reduce((pA, pB) => pA > pB ? pA : pB)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vTexts.detailHumidity,
              style: vTheme.titleSmall?.copyWith(color: vColors.humidity),
            ),
            Text(
              vTexts.detailRange(
                vTexts.humidityValue(
                  vNumber.format(vHumidities.reduce((pA, pB) => pA < pB ? pA : pB)),
                ),
                vTexts.humidityValue(
                  vNumber.format(vHumidities.reduce((pA, pB) => pA > pB ? pA : pB)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Saisie du nom. Le champ vit dans cette boîte : il n'est détruit qu'avec elle.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current, required this.device});

  final String current;
  final String device;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _field = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return AlertDialog(
      title: Text(vTexts.detailRename),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(
          hintText: vTexts.detailRenameHint,
          helperText: vTexts.detailRenameDevice(widget.device),
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(pContext, _field.text),
          child: Text(vTexts.save),
        ),
      ],
    );
  }
}
