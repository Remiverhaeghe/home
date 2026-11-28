import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/holidays.dart';
import '../logic/house_calendar.dart';
import '../state/plan_controller.dart';

/// Calendrier de la maison : jours fériés, télétravail et décisions jour par jour. Les plannings
/// des pièces s'en servent pour choisir leurs plages du jour.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.plan, this.clock = DateTime.now});

  final PlanController plan;
  final DateTime Function() clock;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(widget.clock().year, widget.clock().month);

  void _shift(int pMonths) => setState(() => _month = DateTime(_month.year, _month.month + pMonths));

  String _holidayName(AppLocalizations pTexts, Holiday pHoliday) => switch (pHoliday) {
    Holiday.newYear => pTexts.holidayNewYear,
    Holiday.easterMonday => pTexts.holidayEasterMonday,
    Holiday.labourDay => pTexts.holidayLabourDay,
    Holiday.victoryDay => pTexts.holidayVictoryDay,
    Holiday.ascension => pTexts.holidayAscension,
    Holiday.whitMonday => pTexts.holidayWhitMonday,
    Holiday.bastilleDay => pTexts.holidayBastilleDay,
    Holiday.assumption => pTexts.holidayAssumption,
    Holiday.allSaints => pTexts.holidayAllSaints,
    Holiday.armistice => pTexts.holidayArmistice,
    Holiday.christmas => pTexts.holidayChristmas,
  };

  Future<void> _chooseDay(BuildContext pContext, DateTime pDay) async {
    final vTexts = AppLocalizations.of(pContext);
    final vLocale = Localizations.localeOf(pContext).toString();
    final vHoliday = holidayOn(pDay);
    final vChoice = await showDialog<(DayOverride?,)>(
      context: pContext,
      builder: (pDialog) => SimpleDialog(
        title: Text(DateFormat.MMMMEEEEd(vLocale).format(pDay)),
        children: [
          if (vHoliday != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(vTexts.calendarDayHoliday(_holidayName(vTexts, vHoliday))),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(pDialog, (null,)),
            child: Text(vTexts.calendarDayFollow),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(pDialog, (DayOverride.normal,)),
            child: Text(vTexts.calendarDayNormal),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(pDialog, (DayOverride.remote,)),
            child: Text(vTexts.calendarDayRemote),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(pDialog, (DayOverride.rest,)),
            child: Text(vTexts.calendarDayRest),
          ),
        ],
      ),
    );
    // Fermer la boîte sans choisir ne change rien ; « Selon le calendrier » retire la décision
    if (vChoice == null || !mounted) {
      return;
    }
    final vOverrides = {...widget.plan.calendar.overrides};
    final vDay = DateTime(pDay.year, pDay.month, pDay.day);
    final vPicked = vChoice.$1;
    if (vPicked == null) {
      vOverrides.remove(vDay);
    } else {
      vOverrides[vDay] = vPicked;
    }
    await widget.plan.setCalendar(widget.plan.calendar.copyWith(overrides: vOverrides));
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.calendarTitle)),
      body: ListenableBuilder(
        listenable: widget.plan,
        builder: (pContext, _) {
          final vCalendar = widget.plan.calendar;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MonthHeader(
                month: _month,
                onPrevious: () => _shift(-1),
                onNext: () => _shift(1),
              ),
              const SizedBox(height: 8),
              _MonthGrid(
                month: _month,
                calendar: vCalendar,
                today: widget.clock(),
                onTap: (pDay) => _chooseDay(pContext, pDay),
              ),
              const SizedBox(height: 8),
              _Legend(texts: vTexts),
              const SizedBox(height: 24),
              Text(
                vTexts.calendarHolidaysTitle,
                style: Theme.of(pContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<HolidayRule>(
                segments: [
                  ButtonSegment(
                    value: HolidayRule.none,
                    label: Text(vTexts.calendarHolidaysNone),
                  ),
                  ButtonSegment(
                    value: HolidayRule.saturday,
                    label: Text(vTexts.calendarHolidaysSaturday),
                  ),
                  ButtonSegment(
                    value: HolidayRule.sunday,
                    label: Text(vTexts.calendarHolidaysSunday),
                  ),
                ],
                selected: {vCalendar.holidays},
                onSelectionChanged: (pRule) =>
                    widget.plan.setCalendar(vCalendar.copyWith(holidays: pRule.first)),
              ),
              const SizedBox(height: 24),
              Text(vTexts.calendarRemoteTitle, style: Theme.of(pContext).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(vTexts.calendarRemoteHelp),
              const SizedBox(height: 8),
              _WeekdayChips(
                selected: vCalendar.remoteWeekdays,
                onChanged: (pDays) =>
                    widget.plan.setCalendar(vCalendar.copyWith(remoteWeekdays: pDays)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.onPrevious, required this.onNext});

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vLocale = Localizations.localeOf(pContext).toString();

    return Row(
      children: [
        IconButton(
          tooltip: vTexts.calendarPrevious,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            DateFormat.yMMMM(vLocale).format(month),
            textAlign: TextAlign.center,
            style: Theme.of(pContext).textTheme.titleLarge,
          ),
        ),
        IconButton(
          tooltip: vTexts.calendarNext,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.calendar,
    required this.today,
    required this.onTap,
  });

  final DateTime month;
  final HouseCalendar calendar;
  final DateTime today;
  final void Function(DateTime) onTap;

  @override
  Widget build(BuildContext pContext) {
    final vLocale = Localizations.localeOf(pContext).toString();
    final vWeekday = DateFormat.E(vLocale);
    final vColors = Theme.of(pContext).colorScheme;
    final vOffset = DateTime(month.year, month.month).weekday - 1;
    final vDays = DateUtils.getDaysInMonth(month.year, month.month);
    final vRows = ((vOffset + vDays) / 7).ceil();

    Widget cell(int pIndex) {
      final vNumber = pIndex - vOffset + 1;
      if (vNumber < 1 || vNumber > vDays) {
        return const SizedBox.shrink();
      }
      final vDay = DateTime(month.year, month.month, vNumber);
      final vKind = calendar.kindOf(vDay);
      final vIsToday = DateUtils.isSameDay(vDay, today);
      final vOverridden = calendar.overrides.containsKey(vDay);
      final vBackground = switch (vKind) {
        DayKind.rest => vColors.tertiaryContainer,
        DayKind.remote => vColors.secondaryContainer,
        DayKind.normal => null,
      };

      return Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: vBackground ?? Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: vIsToday ? BorderSide(color: vColors.primary, width: 2) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onTap(vDay),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$vNumber'),
                  if (vOverridden) Icon(Icons.edit, size: 10, color: vColors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (var vIndex = 0; vIndex < 7; vIndex++)
              Expanded(
                child: Center(
                  // Le 1er janvier 2024 est un lundi
                  child: Text(
                    vWeekday.format(DateTime(2024, 1, 1 + vIndex)),
                    style: Theme.of(pContext).textTheme.labelMedium,
                  ),
                ),
              ),
          ],
        ),
        for (var vRow = 0; vRow < vRows; vRow++)
          SizedBox(
            height: 48,
            child: Row(
              children: [
                for (var vCol = 0; vCol < 7; vCol++) Expanded(child: cell(vRow * 7 + vCol)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.texts});

  final AppLocalizations texts;

  @override
  Widget build(BuildContext pContext) {
    final vColors = Theme.of(pContext).colorScheme;
    Widget dot(Color pColor, String pLabel) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: pColor, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(pLabel),
      ],
    );

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        dot(vColors.tertiaryContainer, texts.calendarLegendRest),
        dot(vColors.secondaryContainer, texts.calendarLegendRemote),
      ],
    );
  }
}

class _WeekdayChips extends StatelessWidget {
  const _WeekdayChips({required this.selected, required this.onChanged});

  final Set<int> selected;
  final void Function(Set<int>) onChanged;

  @override
  Widget build(BuildContext pContext) {
    final vFormat = DateFormat.E(Localizations.localeOf(pContext).toString());

    return Wrap(
      spacing: 8,
      children: [
        for (var vDay = 1; vDay <= 7; vDay++)
          FilterChip(
            label: Text(vFormat.format(DateTime(2024, 1, vDay))),
            selected: selected.contains(vDay),
            onSelected: (pOn) => onChanged(pOn ? {...selected, vDay} : ({...selected}..remove(vDay))),
          ),
      ],
    );
  }
}
