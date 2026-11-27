import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/wall_tiles.dart';
import '../state/ac_controller.dart';
import '../state/sensors_controller.dart';
import 'theme.dart';
import 'wall_display.dart';

/// Intervalle entre deux lectures des climatisations tant que l'affichage mural est ouvert.
const wallRefresh = Duration(seconds: 30);

/// Tablette accrochée au mur : l'heure, et une grosse tuile par pièce avec ses commandes.
class WallScreen extends StatefulWidget {
  const WallScreen({
    super.key,
    required this.sensors,
    required this.ac,
    required this.display,
    this.clock = DateTime.now,
  });

  final SensorsController sensors;
  final AcController ac;
  final WallDisplay display;

  /// Heure courante ; remplacée dans les tests.
  final DateTime Function() clock;

  @override
  State<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends State<WallScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(widget.display.enter());
    unawaited(widget.ac.refresh());
    _timer = Timer.periodic(wallRefresh, (_) {
      unawaited(widget.ac.refresh());
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(widget.display.leave());
    super.dispose();
  }

  Future<void> _command(Future<bool> Function() pSend) async {
    final vTexts = AppLocalizations.of(context);
    final vMessenger = ScaffoldMessenger.of(context);
    if (!await pSend()) {
      vMessenger.showSnackBar(SnackBar(content: Text(vTexts.acCommandFailed)));
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vTheme = Theme.of(pContext).textTheme;
    final vLocale = Localizations.localeOf(pContext).toString();
    final vNow = widget.clock();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(DateFormat.Hm(vLocale).format(vNow), style: vTheme.displayMedium),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      DateFormat.MMMMEEEEd(vLocale).format(vNow),
                      style: vTheme.titleLarge,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: vTexts.wallClose,
                    iconSize: 32,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(pContext),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([widget.sensors, widget.ac]),
                  builder: (pContext, _) {
                    final vTiles = buildWallTiles(
                      pSensors: widget.sensors.sensors,
                      pUnits: widget.ac.units,
                      pControls: widget.ac.controls,
                      pNow: widget.clock(),
                    );
                    if (vTiles.isEmpty) {
                      return Center(child: Text(vTexts.wallEmpty, style: vTheme.titleLarge));
                    }

                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 420,
                        mainAxisExtent: 300,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: vTiles.length,
                      itemBuilder: (_, pIndex) => _WallTileCard(
                        tile: vTiles[pIndex],
                        onPower: (pOn) =>
                            _command(() => widget.ac.setPower(vTiles[pIndex].host!, pOn: pOn)),
                        onSetpoint: (pDegrees) =>
                            _command(() => widget.ac.setSetpoint(vTiles[pIndex].host!, pDegrees)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WallTileCard extends StatelessWidget {
  const _WallTileCard({required this.tile, required this.onPower, required this.onSetpoint});

  final WallTile tile;
  final ValueChanged<bool> onPower;
  final ValueChanged<double> onSetpoint;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vTheme = Theme.of(pContext).textTheme;
    final vColors = HomeColors.of(pContext);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());
    final vReading = tile.reading;
    final vControl = tile.control;
    final vSetpoint = vControl?.setpointDegrees;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tile.name, style: vTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            if (vReading == null)
              Text(vTexts.noReading)
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    vTexts.temperatureValue(vNumber.format(vReading.temp)),
                    style: vTheme.displayMedium?.copyWith(color: vColors.temperature),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    vTexts.humidityValue(vNumber.format(vReading.humidity)),
                    style: vTheme.headlineMedium?.copyWith(color: vColors.humidity),
                  ),
                ],
              ),
              ),
            if (tile.stale) Text(vTexts.wallStale, style: TextStyle(color: vColors.warning)),
            const Spacer(),
            switch (tile.ac) {
              WallAc.none => const SizedBox.shrink(),
              WallAc.loading => const LinearProgressIndicator(),
              WallAc.unreachable => Text(
                vTexts.acUnreachable,
                style: TextStyle(color: vColors.warning),
              ),
              WallAc.ready => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 64)),
                    icon: const Icon(Icons.power_settings_new),
                    label: Text(vControl!.power ? vTexts.wallTurnOff : vTexts.wallTurnOn),
                    onPressed: () => onPower(!vControl.power),
                  ),
                  const SizedBox(width: 16),
                  if (vSetpoint != null) ...[
                    IconButton.filledTonal(
                      tooltip: vTexts.acLower,
                      iconSize: 32,
                      constraints: const BoxConstraints.tightFor(width: 64, height: 64),
                      icon: const Icon(Icons.remove),
                      onPressed: () => onSetpoint(vSetpoint - 0.5),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        vTexts.temperatureValue(vNumber.format(vSetpoint)),
                        style: vTheme.headlineSmall?.copyWith(color: vColors.temperature),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: vTexts.acRaise,
                      iconSize: 32,
                      constraints: const BoxConstraints.tightFor(width: 64, height: 64),
                      icon: const Icon(Icons.add),
                      onPressed: () => onSetpoint(vSetpoint + 0.5),
                    ),
                  ],
                ],
              ),
              ),
            },
          ],
        ),
      ),
    );
  }
}
