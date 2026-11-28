import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/scenarios.dart';
import '../state/pellet_controller.dart';
import '../state/plan_controller.dart';

/// Choix du jour de retour, remplaçable dans les tests.
typedef ReturnDayPicker = Future<DateTime?> Function(BuildContext pContext);

Future<DateTime?> pickReturnDay(BuildContext pContext) {
  final vTomorrow = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));

  return showDatePicker(
    context: pContext,
    helpText: AppLocalizations.of(pContext).planScenarioReturnDay,
    firstDate: vTomorrow,
    lastDate: vTomorrow.add(const Duration(days: 365)),
  );
}

/// Trois gestes pour le quotidien : partir (hors gel, poêle arrêté), revenir, et basculer le
/// télétravail d'aujourd'hui.
class ScenariosSection extends StatelessWidget {
  const ScenariosSection({
    super.key,
    required this.plan,
    required this.clock,
    this.pellet,
    this.pickDay = pickReturnDay,
  });

  final PlanController plan;
  final DateTime Function() clock;
  final PelletController? pellet;
  final ReturnDayPicker pickDay;

  Future<void> _leave(BuildContext pContext) async {
    final vDay = await pickDay(pContext);
    if (vDay == null) {
      return;
    }
    final vAbsence = departure(clock(), vDay);
    if (vAbsence == null) {
      return;
    }
    await plan.setVacation(vAbsence);
    if (pellet?.stove != null) {
      await pellet!.setPower(pOn: false);
    }
    await plan.tick(clock());
  }

  Future<void> _back() async {
    await plan.setVacation(null);
    await plan.tick(clock());
  }

  Future<void> _toggleNight() async {
    if (isNightOn(plan.boosts, clock())) {
      await plan.stopNight(clock());
    } else {
      await plan.startNight(clock());
    }
    await plan.tick(clock());
  }

  Future<void> _toggleRemote() async {
    await plan.setCalendar(toggleRemoteToday(plan.calendar, clock()));
    await plan.tick(clock());
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vAway = plan.vacation?.isActiveAt(clock()) ?? false;
    final vRemote = isRemoteToday(plan.calendar, clock());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(vTexts.planScenariosTitle, style: Theme.of(pContext).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (vAway)
              FilledButton.tonal(
                key: const Key('scenario-back'),
                onPressed: _back,
                child: Text(vTexts.planScenarioBack),
              )
            else
              FilledButton.tonal(
                key: const Key('scenario-leave'),
                onPressed: () => _leave(pContext),
                child: Text(vTexts.planScenarioLeave),
              ),
            FilterChip(
              key: const Key('scenario-night'),
              label: Text(vTexts.planScenarioNight),
              selected: isNightOn(plan.boosts, clock()),
              onSelected: (_) => _toggleNight(),
            ),
            FilterChip(
              key: const Key('scenario-remote'),
              label: Text(vTexts.planScenarioRemote),
              selected: vRemote,
              onSelected: (_) => _toggleRemote(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          vAway ? vTexts.planScenarioBackHint : vTexts.planScenarioLeaveHint,
          style: Theme.of(pContext).textTheme.bodySmall,
        ),
      ],
    );
  }
}
