import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ble/tp357_link.dart';
import '../l10n/gen/app_localizations.dart';
import '../logic/reading.dart';
import '../logic/tp357.dart';
import '../state/sensors_controller.dart';
import 'diagnostic_screen.dart';
import 'theme.dart';

/// Capteurs TP357 à portée : on en choisit un, et ses mesures en direct s'ajoutent à ses relevés
/// tant que l'écran reste ouvert.
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, required this.link, required this.controller});

  final Tp357Link link;
  final SensorsController controller;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _devices = <Tp357Device>[];
  StreamSubscription<Tp357Device>? _scan;
  StreamSubscription<TempHumidity>? _live;
  Tp357Device? _followed;
  TempHumidity? _current;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scan = widget.link.scan().listen(
      (pDevice) => setState(() => _devices.add(pDevice)),
      onError: (Object _) => setState(() => _failed = true),
    );
  }

  @override
  void dispose() {
    unawaited(_scan?.cancel());
    unawaited(_live?.cancel());
    super.dispose();
  }

  void _follow(Tp357Device pDevice) {
    unawaited(_live?.cancel());
    setState(() {
      _followed = pDevice;
      _current = null;
      _failed = false;
    });
    _live = widget.link.live(pDevice.id).listen((pValue) {
      setState(() => _current = pValue);
      unawaited(
        widget.controller.addLiveReading(
          pDevice.name,
          Reading(at: DateTime.now(), temp: pValue.temp, humidity: pValue.humidity),
        ),
      );
    }, onError: (Object _) => setState(() => _failed = true));
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vColors = HomeColors.of(pContext);
    final vTheme = Theme.of(pContext).textTheme;
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());
    final vFollowed = _followed;
    final vCurrent = _current;

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.liveTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_failed) ...[
            Text(vTexts.bluetoothError, style: TextStyle(color: Theme.of(pContext).colorScheme.error)),
            const SizedBox(height: 16),
          ],
          if (vFollowed != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vTexts.liveFollowing(vFollowed.name), style: vTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (vCurrent == null)
                      Text(vTexts.liveWaiting)
                    else
                      Row(
                        children: [
                          Text(
                            vTexts.temperatureValue(vNumber.format(vCurrent.temp)),
                            style: vTheme.headlineMedium?.copyWith(color: vColors.temperature),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            vTexts.humidityValue(vNumber.format(vCurrent.humidity)),
                            style: vTheme.headlineMedium?.copyWith(color: vColors.humidity),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(vTexts.liveKeptNote, style: vTheme.bodySmall),
                    if (hasTp357History(vFollowed.name))
                      TextButton(
                        onPressed: () => Navigator.push<void>(
                          pContext,
                          MaterialPageRoute(
                            builder: (_) => DiagnosticScreen(link: widget.link, device: vFollowed),
                          ),
                        ),
                        child: Text(vTexts.diagnosticOpen),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_devices.isEmpty && !_failed)
            Text(vTexts.liveSearching)
          else if (_devices.isEmpty)
            Text(vTexts.liveNone),
          for (final vDevice in _devices)
            ListTile(
              title: Text(vDevice.name),
              trailing: vDevice.id == vFollowed?.id
                  ? const Icon(Icons.bluetooth_connected)
                  : TextButton(onPressed: () => _follow(vDevice), child: Text(vTexts.liveFollow)),
            ),
        ],
      ),
    );
  }
}
