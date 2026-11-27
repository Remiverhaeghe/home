import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../background/background_control.dart';
import '../ble/tp357_link.dart';
import '../l10n/gen/app_localizations.dart';
import '../logic/pending_readings.dart';
import '../logic/reading.dart';
import '../logic/tp357.dart';
import '../state/sensors_controller.dart';
import '../storage/background_files.dart';
import 'diagnostic_screen.dart';
import 'theme.dart';

/// Capteurs TP357 à portée : on en choisit un, et ses mesures en direct s'ajoutent à ses relevés
/// tant que l'écran reste ouvert.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    required this.link,
    required this.controller,
    this.background,
    this.files,
  });

  final Tp357Link link;
  final SensorsController controller;

  /// Relevé en arrière-plan : l'interrupteur n'apparaît que si le service et ses fichiers sont fournis.
  final BackgroundControl? background;
  final BackgroundFiles? files;

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
  var _followedInBackground = <FollowedDevice>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadFollowed());
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

  Future<void> _loadFollowed() async {
    final vFiles = widget.files;
    if (vFiles == null) {
      return;
    }
    final vFollowed = await vFiles.loadFollowed();
    if (mounted) {
      setState(() => _followedInBackground = vFollowed);
    }
  }

  /// Ajoute ou retire le capteur de ceux que le service relève, et démarre ou arrête le service.
  Future<void> _setBackground(Tp357Device pDevice, {required bool pOn}) async {
    final vFiles = widget.files!;
    final vBackground = widget.background!;
    final vTexts = AppLocalizations.of(context);
    final vNext = [
      for (final vDevice in _followedInBackground)
        if (vDevice.id != pDevice.id) vDevice,
      if (pOn) FollowedDevice(id: pDevice.id, name: pDevice.name),
    ];
    if (pOn) {
      final vStarted = await vBackground.start(
        pTitle: vTexts.backgroundNotificationTitle,
        pText: vTexts.backgroundNotificationText,
      );
      if (!vStarted) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(vTexts.backgroundDenied)));
        }
        return;
      }
    }
    await vFiles.saveFollowed(vNext);
    if (vNext.isEmpty) {
      await vBackground.stop();
    }
    if (mounted) {
      setState(() => _followedInBackground = vNext);
    }
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
            Text(
              vTexts.bluetoothError,
              style: TextStyle(color: Theme.of(pContext).colorScheme.error),
            ),
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
                    if (widget.background != null && widget.files != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(vTexts.backgroundSwitch),
                        subtitle: Text(vTexts.backgroundHelp),
                        value: _followedInBackground.any((pDevice) => pDevice.id == vFollowed.id),
                        onChanged: (pOn) => _setBackground(vFollowed, pOn: pOn),
                      ),
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
