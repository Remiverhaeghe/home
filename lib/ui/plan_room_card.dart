import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/ac_units.dart';
import '../logic/comfort.dart';

/// Pas de réglage d'une température souhaitée, en °C.
const _step = 0.5;

/// Carte d'une pièce : ses températures souhaitées par profil, le coup de chaud et le planning.
class RoomCard extends StatelessWidget {
  const RoomCard({
    required this.unit,
    required this.targets,
    required this.texts,
    required this.number,
    required this.profileName,
    required this.onChange,
    required this.onSchedule,
    required this.onBoost,
    required this.boostUntil,
  });

  final AcUnit unit;
  final RoomTargets targets;
  final AppLocalizations texts;
  final NumberFormat number;
  final String Function(ProfileKind) profileName;
  final void Function(ProfileKind, double) onChange;
  final VoidCallback onSchedule;
  final VoidCallback onBoost;

  /// Fin du coup de chaud en cours, null s'il n'y en a pas.
  final DateTime? boostUntil;

  @override
  Widget build(BuildContext pContext) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(unit.name, style: Theme.of(pContext).textTheme.titleMedium),
          for (final vProfile in ProfileKind.values)
            Row(
              children: [
                Expanded(
                  child: Text(
                    texts.planTarget(profileName(vProfile), number.format(targets.of(vProfile))),
                  ),
                ),
                IconButton(
                  tooltip: texts.planLower(profileName(vProfile)),
                  icon: const Icon(Icons.remove),
                  onPressed: () => onChange(vProfile, -_step),
                ),
                IconButton(
                  tooltip: texts.planRaise(profileName(vProfile)),
                  icon: const Icon(Icons.add),
                  onPressed: () => onChange(vProfile, _step),
                ),
              ],
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onBoost,
              icon: const Icon(Icons.hot_tub_outlined),
              label: Text(
                boostUntil == null
                    ? texts.boostOpen
                    : texts.boostActive(DateFormat.Hm().format(boostUntil!)),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onSchedule,
              icon: const Icon(Icons.calendar_month),
              label: Text(texts.scheduleOpen),
            ),
          ),
        ],
      ),
    ),
  );
}
