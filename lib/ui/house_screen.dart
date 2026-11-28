import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/house.dart';
import '../state/house_controller.dart';
import '../state/weather_controller.dart';

/// Nom d'un niveau, pour les listes et les titres de groupe.
String floorName(AppLocalizations pTexts, int pFloor) => switch (pFloor) {
  -1 => pTexts.floorBasement,
  0 => pTexts.floorGround,
  1 => pTexts.floorFirst,
  2 => pTexts.floorSecond,
  _ => pTexts.floorAttic,
};

/// La maison : son lieu, saisi à la main (nom et coordonnées), pour les analyses météo à venir.
class HouseScreen extends StatefulWidget {
  const HouseScreen({super.key, required this.controller, this.weather});

  final HouseController controller;

  /// Météo extérieure ; sans lui, la section n'apparaît pas.
  final WeatherController? weather;

  @override
  State<HouseScreen> createState() => _HouseScreenState();
}

class _HouseScreenState extends State<HouseScreen> {
  late final _label = TextEditingController(text: widget.controller.house.location?.label ?? '');
  late final _latitude = TextEditingController(
    text: _number(widget.controller.house.location?.latitude),
  );
  late final _longitude = TextEditingController(
    text: _number(widget.controller.house.location?.longitude),
  );

  static String _number(double? pValue) => pValue == null ? '' : '$pValue'.replaceAll('.', ',');

  static double? _parse(String pText) => double.tryParse(pText.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _label.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vTexts = AppLocalizations.of(context);
    final vMessenger = ScaffoldMessenger.of(context);
    final vProblem = await widget.controller.setLocation(
      _label.text,
      _parse(_latitude.text),
      _parse(_longitude.text),
    );
    vMessenger.hideCurrentSnackBar();
    vMessenger.showSnackBar(
      SnackBar(
        content: Text(switch (vProblem) {
          null => vTexts.houseSaved,
          LocationProblem.emptyLabel => vTexts.houseProblemLabel,
          LocationProblem.badCoordinates => vTexts.houseProblemCoordinates,
        }),
      ),
    );
  }

  Future<void> _clear() async {
    await widget.controller.clearLocation();
    _label.clear();
    _latitude.clear();
    _longitude.clear();
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.houseTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(vTexts.houseHelp),
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            decoration: InputDecoration(labelText: vTexts.houseLabel),
          ),
          TextField(
            controller: _latitude,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(labelText: vTexts.houseLatitude),
          ),
          TextField(
            controller: _longitude,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(labelText: vTexts.houseLongitude),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(onPressed: _save, child: Text(vTexts.save)),
              const SizedBox(width: 12),
              TextButton(onPressed: _clear, child: Text(vTexts.houseClear)),
            ],
          ),
          if (widget.weather != null)
            _WeatherSection(house: widget.controller, weather: widget.weather!),
        ],
      ),
    );
  }
}

/// Météo extérieure : accès à Internet autorisé ou non, récupération et export CSV.
class _WeatherSection extends StatelessWidget {
  const _WeatherSection({required this.house, required this.weather});

  final HouseController house;
  final WeatherController weather;

  Future<void> _refresh(BuildContext pContext) async {
    final vTexts = AppLocalizations.of(pContext);
    final vMessenger = ScaffoldMessenger.of(pContext);
    final vResult = await weather.refresh(house.house.location, pForce: true);
    vMessenger.hideCurrentSnackBar();
    vMessenger.showSnackBar(
      SnackBar(
        content: Text(switch (vResult) {
          WeatherResult.done => vTexts.weatherDone,
          WeatherResult.disabled => vTexts.weatherDisabled,
          WeatherResult.noLocation => vTexts.weatherNoLocation,
          WeatherResult.failed => vTexts.weatherFailed,
        }),
      ),
    );
  }

  Future<void> _copy(BuildContext pContext) async {
    final vTexts = AppLocalizations.of(pContext);
    final vMessenger = ScaffoldMessenger.of(pContext);
    await Clipboard.setData(ClipboardData(text: weather.csv));
    vMessenger.hideCurrentSnackBar();
    vMessenger.showSnackBar(SnackBar(content: Text(vTexts.weatherCopied)));
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return ListenableBuilder(
      listenable: weather,
      builder: (pContext, _) {
        final vReadings = weather.readings;
        final vLast = vReadings.isEmpty ? null : vReadings.last.at;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(vTexts.weatherTitle, style: Theme.of(pContext).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(vTexts.weatherSwitch),
              subtitle: Text(vTexts.weatherSwitchHelp),
              value: weather.enabled,
              onChanged: (pOn) => weather.setEnabled(pEnabled: pOn),
            ),
            if (weather.enabled) ...[
              Text(
                vLast == null
                    ? vTexts.weatherNone
                    : vTexts.weatherStored(
                        vReadings.length,
                        DateFormat.MMMd(
                          Localizations.localeOf(pContext).toString(),
                        ).add_Hm().format(vLast),
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: () => _refresh(pContext),
                    child: Text(vTexts.weatherRefresh),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: vReadings.isEmpty ? null : () => _copy(pContext),
                    child: Text(vTexts.weatherCopy),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Emplacement d'un capteur : pièce, niveau ou dehors.
Future<SensorPlace?> editPlace(BuildContext pContext, SensorPlace pCurrent) =>
    showDialog<SensorPlace>(
      context: pContext,
      builder: (_) => _PlaceDialog(current: pCurrent),
    );

class _PlaceDialog extends StatefulWidget {
  const _PlaceDialog({required this.current});

  final SensorPlace current;

  @override
  State<_PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<_PlaceDialog> {
  late final _room = TextEditingController(text: widget.current.room);
  late final _ceiling = TextEditingController(
    text: widget.current.ceiling == null ? '' : '${widget.current.ceiling}'.replaceAll('.', ','),
  );
  late final _area = TextEditingController(
    text: widget.current.area == null ? '' : '${widget.current.area}'.replaceAll('.', ','),
  );
  late int? _floor = widget.current.floor;
  late bool _outdoor = widget.current.outdoor;

  @override
  void dispose() {
    _room.dispose();
    _ceiling.dispose();
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return AlertDialog(
      title: Text(vTexts.placeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _room,
              decoration: InputDecoration(labelText: vTexts.placeRoom),
            ),
            if (!_outdoor)
              TextField(
                key: const Key('place-ceiling'),
                controller: _ceiling,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: vTexts.placeCeiling,
                  helperText: vTexts.placeCeilingHelp,
                  helperMaxLines: 3,
                ),
              ),
            if (!_outdoor)
              TextField(
                key: const Key('place-area'),
                controller: _area,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: vTexts.placeArea),
              ),
            if (!_outdoor)
              ListenableBuilder(
                listenable: Listenable.merge([_ceiling, _area]),
                builder: (pContext, _) {
                  final vVolume = SensorPlace(
                    ceiling: parseCeiling(_ceiling.text),
                    area: parseArea(_area.text),
                  ).volume;
                  if (vVolume == null) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      vTexts.placeVolume(
                        vVolume.round(),
                        (airEnergyKwh(vVolume, 1) * 1000).round(),
                      ),
                      key: const Key('place-volume'),
                    ),
                  );
                },
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(vTexts.placeOutdoor),
              value: _outdoor,
              onChanged: (pValue) => setState(() => _outdoor = pValue),
            ),
            if (!_outdoor)
              DropdownButton<int?>(
                isExpanded: true,
                value: _floor,
                hint: Text(vTexts.placeFloor),
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(vTexts.placeFloorNone)),
                  for (final vLevel in floorLevels)
                    DropdownMenuItem<int?>(value: vLevel, child: Text(floorName(vTexts, vLevel))),
                ],
                onChanged: (pValue) => setState(() => _floor = pValue),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            pContext,
            SensorPlace(
              room: _room.text,
              floor: _floor,
              outdoor: _outdoor,
              ceiling: _outdoor ? null : parseCeiling(_ceiling.text),
              area: _outdoor ? null : parseArea(_area.text),
            ),
          ),
          child: Text(vTexts.save),
        ),
      ],
    );
  }
}
