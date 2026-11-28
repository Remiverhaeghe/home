import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/reminders.dart';
import '../storage/background_files.dart';

/// Entretiens qui reviennent. Le service d'arrière-plan lit le même fichier et notifie ceux qui
/// sont échus.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.files, this.clock = DateTime.now});

  final BackgroundFiles files;
  final DateTime Function() clock;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder>? _reminders;

  @override
  void initState() {
    super.initState();
    widget.files.loadReminders().then((pReminders) {
      if (mounted) {
        setState(() => _reminders = pReminders);
      }
    });
  }

  Future<void> _store(List<Reminder> pReminders) async {
    setState(() => _reminders = pReminders);
    await widget.files.saveReminders(pReminders);
  }

  Future<void> _add() async {
    final vNew = await showDialog<Reminder>(
      context: context,
      builder: (pContext) => _ReminderDialog(now: widget.clock()),
    );
    if (vNew != null) {
      await _store([...?_reminders, vNew]);
    }
  }

  String _status(AppLocalizations pTexts, Reminder pReminder) {
    final vLeft = pReminder.daysLeft(widget.clock());
    if (vLeft < 0) {
      return pTexts.remindersLate(-vLeft);
    }

    return vLeft == 0 ? pTexts.remindersToday : pTexts.remindersIn(vLeft);
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vReminders = _reminders;

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.remindersTitle)),
      floatingActionButton: FloatingActionButton(
        key: const Key('reminder-add'),
        tooltip: vTexts.remindersAdd,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: vReminders == null
          ? const Center(child: CircularProgressIndicator())
          : vReminders.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: Text(vTexts.remindersEmpty))
          : ListView(
              children: [
                for (var vIndex = 0; vIndex < vReminders.length; vIndex++)
                  ListTile(
                    leading: Icon(
                      vReminders[vIndex].isDue(widget.clock())
                          ? Icons.warning_amber
                          : Icons.check_circle_outline,
                    ),
                    title: Text(vReminders[vIndex].name),
                    subtitle: Text(
                      '${vTexts.remindersEvery(vReminders[vIndex].everyDays)}\n'
                      '${_status(vTexts, vReminders[vIndex])}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      children: [
                        IconButton(
                          key: Key('reminder-done-$vIndex'),
                          tooltip: vTexts.remindersDone,
                          icon: const Icon(Icons.done),
                          onPressed: () => _store([
                            for (var vOther = 0; vOther < vReminders.length; vOther++)
                              vOther == vIndex
                                  ? vReminders[vOther].done(widget.clock())
                                  : vReminders[vOther],
                          ]),
                        ),
                        IconButton(
                          key: Key('reminder-delete-$vIndex'),
                          tooltip: vTexts.remindersDelete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _store([
                            for (var vOther = 0; vOther < vReminders.length; vOther++)
                              if (vOther != vIndex) vReminders[vOther],
                          ]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({required this.now});

  final DateTime now;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  final _name = TextEditingController();
  final _days = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    super.dispose();
  }

  Reminder? _build() {
    final vDays = int.tryParse(_days.text.trim());
    if (_name.text.trim().isEmpty ||
        vDays == null ||
        vDays < reminderDaysMin ||
        vDays > reminderDaysMax) {
      return null;
    }

    return Reminder(name: _name.text.trim(), everyDays: vDays, lastDone: widget.now);
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return AlertDialog(
      title: Text(vTexts.remindersAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('reminder-name'),
            controller: _name,
            decoration: InputDecoration(labelText: vTexts.remindersName),
          ),
          TextField(
            key: const Key('reminder-days'),
            controller: _days,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: vTexts.remindersDays),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        TextButton(
          key: const Key('reminder-save'),
          onPressed: () {
            final vReminder = _build();
            if (vReminder != null) {
              Navigator.pop(pContext, vReminder);
            }
          },
          child: Text(vTexts.save),
        ),
      ],
    );
  }
}
