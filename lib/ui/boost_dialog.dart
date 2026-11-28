import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/boost.dart';
import 'units_scope.dart';
import 'value_slider.dart';

/// Choix de l'utilisateur : lancer un coup de chaud, ou l'arrêter quand [kind] est null.
typedef BoostChoice = ({BoostKind? kind, double temp, int minutes});

String boostKindName(AppLocalizations pTexts, BoostKind pKind) => switch (pKind) {
  BoostKind.shower => pTexts.boostShower,
  BoostKind.bath => pTexts.boostBath,
  BoostKind.laundry => pTexts.boostLaundry,
  BoostKind.night => pTexts.planScenarioNight,
};

/// Coup de chaud d'une pièce : usage, température et durée. Renvoie le choix, ou null si on
/// annule. [active] est le coup de chaud déjà en cours, que l'on peut arrêter.
Future<BoostChoice?> showBoostDialog(
  BuildContext pContext, {
  required String room,
  Boost? active,
}) => showDialog<BoostChoice>(
  context: pContext,
  builder: (_) => _BoostDialog(room: room, active: active),
);

class _BoostDialog extends StatefulWidget {
  const _BoostDialog({required this.room, required this.active});

  final String room;
  final Boost? active;

  @override
  State<_BoostDialog> createState() => _BoostDialogState();
}

class _BoostDialogState extends State<_BoostDialog> {
  var _kind = BoostKind.shower;
  late var _temp = defaultBoost(_kind).temp;
  late var _minutes = defaultBoost(_kind).minutes;

  void _pick(BoostKind pKind) => setState(() {
    _kind = pKind;
    _temp = defaultBoost(pKind).temp;
    _minutes = defaultBoost(pKind).minutes;
  });

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vUnits = UnitsScope.of(pContext);
    final vActive = widget.active;

    return AlertDialog(
      title: Text(vTexts.boostTitle(widget.room)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vActive != null) ...[
              Text(vTexts.boostActive(DateFormat.Hm().format(vActive.until))),
              const SizedBox(height: 8),
            ],
            Text(vTexts.boostHint),
            const SizedBox(height: 12),
            SegmentedButton<BoostKind>(
              segments: [
                for (final vKind in BoostKind.values.where((pKind) => pKind != BoostKind.night))
                  ButtonSegment(value: vKind, label: Text(boostKindName(vTexts, vKind))),
              ],
              selected: {_kind},
              onSelectionChanged: (pSelected) => _pick(pSelected.first),
            ),
            const SizedBox(height: 12),
            ValueSlider(
              title: vTexts.boostTemp,
              valueText: vUnits.temp(_temp),
              value: _temp,
              min: boostMinTemp,
              max: boostMaxTemp,
              minText: vUnits.temp(boostMinTemp),
              maxText: vUnits.temp(boostMaxTemp),
              divisions: ((boostMaxTemp - boostMinTemp) * 2).round(),
              onChanged: (pValue) => setState(() => _temp = pValue),
            ),
            const SizedBox(height: 12),
            ValueSlider(
              title: vTexts.boostDuration,
              valueText: vTexts.boostMinutes(_minutes),
              value: _minutes.toDouble(),
              min: boostMinMinutes.toDouble(),
              max: boostMaxMinutes.toDouble(),
              minText: vTexts.boostMinutes(boostMinMinutes),
              maxText: vTexts.boostMinutes(boostMaxMinutes),
              divisions: (boostMaxMinutes - boostMinMinutes) ~/ 15,
              onChanged: (pValue) => setState(() => _minutes = (pValue / 15).round() * 15),
            ),
          ],
        ),
      ),
      actions: [
        if (vActive != null)
          TextButton(
            onPressed: () => Navigator.pop(pContext, (kind: null, temp: _temp, minutes: _minutes)),
            child: Text(vTexts.boostStop),
          ),
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(pContext, (kind: _kind, temp: _temp, minutes: _minutes)),
          child: Text(vTexts.boostStart),
        ),
      ],
    );
  }
}
