import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/ac_units.dart';
import '../logic/alerts.dart';
import '../logic/comfort.dart';
import '../logic/plan.dart';
import '../logic/vacation.dart';
import '../state/ac_controller.dart';
import '../state/pellet_controller.dart';
import '../state/plan_controller.dart';
import '../state/sensors_controller.dart';
import '../storage/plan_store.dart';
import 'boost_dialog.dart';
import 'heating_report_screen.dart';
import 'rules_screen.dart';
import 'schedule_screen.dart';

/// Choix des jours d'absence : premier et dernier jour, null si l'utilisateur renonce.
typedef DateRangePicker = Future<DateTimeRange?> Function(BuildContext pContext);

Future<DateTimeRange?> pickAbsence(BuildContext pContext) {
  final vToday = DateUtils.dateOnly(DateTime.now());

  return showDateRangePicker(
    context: pContext,
    firstDate: vToday,
    lastDate: vToday.add(const Duration(days: 365)),
  );
}

const _step = 0.5;
const _minTarget = 10.0;
const _maxTarget = 30.0;

/// Températures souhaitées de chaque pièce, mode vacances et alertes en cours.
class PlanScreen extends StatelessWidget {
  const PlanScreen({
    super.key,
    required this.plan,
    required this.ac,
    required this.sensors,
    this.pickRange = pickAbsence,
    this.clock = DateTime.now,
    this.pellet,
  });

  /// Poêle, pour le bilan du chauffage.
  final PelletController? pellet;
  final PlanController plan;
  final AcController ac;
  final SensorsController sensors;
  final DateRangePicker pickRange;
  final DateTime Function() clock;

  String _profileName(AppLocalizations pTexts, ProfileKind pProfile) => switch (pProfile) {
    ProfileKind.comfort => pTexts.planProfileComfort,
    ProfileKind.night => pTexts.planProfileNight,
    ProfileKind.eco => pTexts.planProfileEco,
    ProfileKind.away => pTexts.planProfileAway,
  };

  RoomTargets _withTarget(RoomTargets pTargets, ProfileKind pProfile, double pValue) {
    final vValue = pValue.clamp(_minTarget, _maxTarget).toDouble();

    return RoomTargets(
      comfort: pProfile == ProfileKind.comfort ? vValue : pTargets.comfort,
      night: pProfile == ProfileKind.night ? vValue : pTargets.night,
      eco: pProfile == ProfileKind.eco ? vValue : pTargets.eco,
      away: pProfile == ProfileKind.away ? vValue : pTargets.away,
    );
  }

  Future<void> _change(AcUnit pUnit, ProfileKind pProfile, double pDelta) {
    final vRoom = plan.roomOf(pUnit.host);
    final vTargets = vRoom?.targets ?? const RoomTargets();

    return plan.setRoom(
      Room(
        acHost: pUnit.host,
        targets: _withTarget(vTargets, pProfile, vTargets.of(pProfile) + pDelta),
        schedule: vRoom?.schedule ?? defaultSchedule,
      ),
    );
  }

  Future<void> _setAbsence(BuildContext pContext) async {
    final vRange = await pickRange(pContext);
    if (vRange == null) {
      return;
    }
    // Le dernier jour d'absence est compris : le retour est le lendemain à minuit
    final vReturn = DateUtils.dateOnly(vRange.end).add(const Duration(days: 1));
    await plan.setVacation(VacationMode(from: DateUtils.dateOnly(vRange.start), until: vReturn));
  }

  String _alertText(AppLocalizations pTexts, SensorAlert pAlert, NumberFormat pNumber) {
    final vValue = pNumber.format(pAlert.value ?? 0);

    return switch (pAlert.kind) {
      AlertKind.frost => pTexts.planAlertFrost(pAlert.sensorName, vValue),
      AlertKind.humidity => pTexts.planAlertHumidity(pAlert.sensorName, vValue),
      AlertKind.silent => pTexts.planAlertSilent(pAlert.sensorName),
    };
  }

  /// Ouvre le choix du coup de chaud, l'enregistre puis applique le plan tout de suite.
  Future<void> _boost(BuildContext pContext, AcUnit pUnit) async {
    final vChoice = await showBoostDialog(
      pContext,
      room: pUnit.name,
      active: plan.boostOf(pUnit.host, clock()),
    );
    if (vChoice == null) {
      return;
    }
    final vKind = vChoice.kind;
    if (vKind == null) {
      await plan.stopBoost(pUnit.host);
    } else {
      await plan.startBoost(pUnit.host, vKind, vChoice.temp, vChoice.minutes, clock());
    }
    await ac.refresh();
    await plan.tick(clock());
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vLocale = Localizations.localeOf(pContext).toString();
    final vNumber = NumberFormat('0.0', vLocale);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.planTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([plan, ac, sensors]),
        builder: (pContext, _) {
          final vVacation = plan.vacation;
          final vAlerts = evaluateAlerts(sensors.sensors, clock(), pWatched: plan.watched);
          final vDate = DateFormat.yMMMd(vLocale);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (ac.units.isEmpty)
                Text(vTexts.planNoUnits)
              else ...[
                for (final vUnit in ac.units)
                  _RoomCard(
                    unit: vUnit,
                    targets: plan.roomOf(vUnit.host)?.targets ?? const RoomTargets(),
                    texts: vTexts,
                    number: vNumber,
                    profileName: (pProfile) => _profileName(vTexts, pProfile),
                    onChange: (pProfile, pDelta) => _change(vUnit, pProfile, pDelta),
                    boostUntil: plan.boostOf(vUnit.host, clock())?.until,
                    onBoost: () => _boost(pContext, vUnit),
                    onSchedule: () => Navigator.push<void>(
                      pContext,
                      MaterialPageRoute(
                        builder: (_) => ScheduleScreen(plan: plan, unit: vUnit),
                      ),
                    ),
                  ),
                Text(vTexts.planScheduleNote, style: Theme.of(pContext).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push<void>(
                    pContext,
                    MaterialPageRoute(
                      builder: (_) => RulesScreen(plan: plan, ac: ac),
                    ),
                  ),
                  icon: const Icon(Icons.rule),
                  label: Text(vTexts.rulesOpen),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.bar_chart),
                label: Text(vTexts.heatingOpen),
                onPressed: () => Navigator.push<void>(
                  pContext,
                  MaterialPageRoute(
                    builder: (_) => HeatingReportScreen(ac: ac, pellet: pellet, clock: clock),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _StoveColdSection(plan: plan),
              const SizedBox(height: 24),
              Text(vTexts.planVacationTitle, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (vVacation == null) ...[
                Text(vTexts.planVacationNone),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _setAbsence(pContext),
                    icon: const Icon(Icons.luggage),
                    label: Text(vTexts.planVacationSet),
                  ),
                ),
              ] else ...[
                Text(
                  vTexts.planVacationActive(
                    vDate.format(vVacation.from),
                    vDate.format(vVacation.until.subtract(const Duration(days: 1))),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => plan.setVacation(null),
                    child: Text(vTexts.planVacationStop),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(vTexts.planAlertsTitle, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (vAlerts.isEmpty)
                Text(vTexts.planAlertsNone)
              else
                for (final vAlert in vAlerts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      vAlert.kind == AlertKind.frost ? Icons.ac_unit : Icons.warning_amber,
                    ),
                    title: Text(_alertText(vTexts, vAlert, vNumber)),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
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

/// Seuil de froid : sous cette température, la clim peut chauffer en plus du poêle.
class _StoveColdSection extends StatefulWidget {
  const _StoveColdSection({required this.plan});

  final PlanController plan;

  @override
  State<_StoveColdSection> createState() => _StoveColdSectionState();
}

class _StoveColdSectionState extends State<_StoveColdSection> {
  double? _dragging;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());
    final vValue = _dragging ?? widget.plan.stoveColdBelow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(vTexts.planStoveTitle, style: Theme.of(pContext).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(vTexts.planStoveHint(vNumber.format(vValue))),
        Slider(
          value: vValue,
          min: stoveColdMin,
          max: stoveColdMax,
          divisions: ((stoveColdMax - stoveColdMin) * 2).round(),
          label: '${vNumber.format(vValue)} °C',
          onChanged: (pNew) => setState(() => _dragging = pNew),
          onChangeEnd: (pNew) async {
            await widget.plan.setStoveColdBelow(pNew);
            if (mounted) {
              setState(() => _dragging = null);
            }
          },
        ),
      ],
    );
  }
}
