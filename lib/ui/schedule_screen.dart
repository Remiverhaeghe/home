import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/ac_units.dart';
import '../logic/comfort.dart';
import '../logic/house_calendar.dart';
import '../state/plan_controller.dart';

/// Choix de l'heure de début d'une plage, null si l'utilisateur renonce.
typedef TimeChooser = Future<TimeOfDay?> Function(BuildContext pContext, TimeOfDay pInitial);

Future<TimeOfDay?> chooseTime(BuildContext pContext, TimeOfDay pInitial) =>
    showTimePicker(context: pContext, initialTime: pInitial);

String profileLabel(AppLocalizations pTexts, ProfileKind pProfile) => switch (pProfile) {
  ProfileKind.comfort => pTexts.planProfileComfort,
  ProfileKind.night => pTexts.planProfileNight,
  ProfileKind.eco => pTexts.planProfileEco,
  ProfileKind.away => pTexts.planProfileAway,
};

/// Planning de la semaine d'une pièce : à quelle heure, quels jours, quel profil.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({
    super.key,
    required this.plan,
    required this.unit,
    this.chooseStart = chooseTime,
  });

  final PlanController plan;
  final AcUnit unit;
  final TimeChooser chooseStart;

  List<ScheduleSlot> get _slots {
    final vSlots = [...(plan.roomOf(unit.host)?.schedule ?? const <ScheduleSlot>[])];
    vSlots.sort((pA, pB) => pA.minute.compareTo(pB.minute));

    return vSlots;
  }

  String _days(Set<int> pDays, String pLocale, AppLocalizations pTexts) {
    final vFormat = DateFormat.E(pLocale);
    final vRemote = pDays.contains(remoteDayKey);
    final vWeek = pDays.where((pDay) => pDay <= 7).toList()..sort();
    final vParts = [
      if (vWeek.length == 7)
        pTexts.scheduleEveryDay
      else
        // Le 1er janvier 2024 est un lundi : le jour n du planning est le n-ième de ce mois
        ...vWeek.map((pDay) => vFormat.format(DateTime(2024, 1, pDay))),
      if (vRemote) pTexts.scheduleRemoteDay,
    ];

    return vParts.join(' ');
  }

  Future<void> _add(BuildContext pContext) async {
    final vTexts = AppLocalizations.of(pContext);
    final vTime = await chooseStart(pContext, const TimeOfDay(hour: 7, minute: 0));
    if (vTime == null || !pContext.mounted) {
      return;
    }
    final vChoice = await showDialog<({Set<int> days, ProfileKind profile})>(
      context: pContext,
      builder: (_) => _SlotDialog(texts: vTexts),
    );
    if (vChoice == null) {
      return;
    }
    await plan.setSchedule(unit.host, [
      ..._slots,
      ScheduleSlot(
        weekdays: vChoice.days,
        minute: vTime.hour * 60 + vTime.minute,
        profile: vChoice.profile,
      ),
    ]);
  }

  Future<void> _remove(ScheduleSlot pSlot) =>
      plan.setSchedule(unit.host, [..._slots]..remove(pSlot));

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vLocale = Localizations.localeOf(pContext).toString();
    final vMaterial = MaterialLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.scheduleTitle(unit.name))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(pContext),
        icon: const Icon(Icons.add),
        label: Text(vTexts.scheduleAdd),
      ),
      body: ListenableBuilder(
        listenable: plan,
        builder: (pContext, _) {
          final vSlots = _slots;
          if (vSlots.isEmpty) {
            return Padding(padding: const EdgeInsets.all(16), child: Text(vTexts.scheduleEmpty));
          }

          return ListView(
            children: [
              for (final vSlot in vSlots)
                ListTile(
                  title: Text(
                    vTexts.scheduleSlot(
                      vMaterial.formatTimeOfDay(
                        TimeOfDay(hour: vSlot.minute ~/ 60, minute: vSlot.minute % 60),
                        alwaysUse24HourFormat: true,
                      ),
                      profileLabel(vTexts, vSlot.profile),
                    ),
                  ),
                  subtitle: Text(_days(vSlot.weekdays, vLocale, vTexts)),
                  trailing: IconButton(
                    tooltip: vTexts.scheduleRemove,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(vSlot),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SlotDialog extends StatefulWidget {
  const _SlotDialog({required this.texts});

  final AppLocalizations texts;

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  final _days = <int>{1, 2, 3, 4, 5, 6, 7};
  var _profile = ProfileKind.comfort;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = widget.texts;
    final vFormat = DateFormat.E(Localizations.localeOf(pContext).toString());

    return AlertDialog(
      title: Text(vTexts.scheduleAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final vProfile in ProfileKind.values)
                  ChoiceChip(
                    label: Text(profileLabel(vTexts, vProfile)),
                    selected: _profile == vProfile,
                    onSelected: (_) => setState(() => _profile = vProfile),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var vDay = 1; vDay <= 7; vDay++)
                  FilterChip(
                    label: Text(vFormat.format(DateTime(2024, 1, vDay))),
                    selected: _days.contains(vDay),
                    onSelected: (pOn) => setState(() => pOn ? _days.add(vDay) : _days.remove(vDay)),
                  ),
                FilterChip(
                  label: Text(vTexts.scheduleRemoteDay),
                  selected: _days.contains(remoteDayKey),
                  onSelected: (pOn) =>
                      setState(() => pOn ? _days.add(remoteDayKey) : _days.remove(remoteDayKey)),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.scheduleCancel)),
        FilledButton(
          onPressed: _days.isEmpty
              ? null
              : () => Navigator.pop(pContext, (days: {..._days}, profile: _profile)),
          child: Text(vTexts.scheduleSave),
        ),
      ],
    );
  }
}
