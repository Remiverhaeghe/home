import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/notes.dart';
import '../logic/reading.dart';
import '../state/notes_controller.dart';
import 'units_scope.dart';

/// Notes datées d'un capteur (travaux, changement de fenêtre) et ce que les mesures ont fait
/// dans les deux semaines d'après.
class NotesSection extends StatelessWidget {
  const NotesSection({
    super.key,
    required this.controller,
    required this.sensor,
    this.clock = DateTime.now,
  });

  final NotesController controller;
  final Sensor sensor;
  final DateTime Function() clock;

  Future<void> _add(BuildContext pContext) async {
    final vNote = await showDialog<({DateTime day, String text, bool onlyThis})>(
      context: pContext,
      builder: (_) => _NoteDialog(now: clock()),
    );
    if (vNote != null) {
      await controller.add(vNote.day, vNote.text, pSensor: vNote.onlyThis ? sensor.name : null);
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vLocale = Localizations.localeOf(pContext).toString();
    final vDate = DateFormat.yMMMd(vLocale);
    final vNumber = NumberFormat('0.0', vLocale);

    String signed(double pValue) => '${pValue >= 0 ? '+' : ''}${vNumber.format(pValue)}';

    return ListenableBuilder(
      listenable: controller,
      builder: (pContext, _) {
        final vNotes = controller.forSensor(sensor.name);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(vTexts.notesTitle, style: Theme.of(pContext).textTheme.titleMedium),
            if (vNotes.isEmpty) Text(vTexts.notesEmpty),
            for (final vNote in vNotes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(vNote.text),
                subtitle: Builder(
                  builder: (_) {
                    final vEffect = beforeAfter(sensor.readings, vNote.at, pNow: clock());

                    return Text(
                      vEffect == null
                          ? vDate.format(vNote.at)
                          : '${vDate.format(vNote.at)} · ${vTexts.notesEffect(vEffect.days, UnitsScope.of(pContext).delta(vEffect.tempChange), signed(vEffect.humidityChange))}',
                    );
                  },
                ),
                trailing: IconButton(
                  tooltip: vTexts.notesRemove,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => controller.remove(vNote),
                ),
              ),
            TextButton.icon(
              onPressed: () => _add(pContext),
              icon: const Icon(Icons.note_add_outlined),
              label: Text(vTexts.notesAdd),
            ),
          ],
        );
      },
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.now});

  final DateTime now;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _text = TextEditingController();
  late DateTime _day = DateTime(widget.now.year, widget.now.month, widget.now.day);
  var _onlyThis = true;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final vDay = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: widget.now,
    );
    if (vDay != null) {
      setState(() => _day = vDay);
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return AlertDialog(
      title: Text(vTexts.notesAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _text,
              autofocus: true,
              decoration: InputDecoration(labelText: vTexts.notesText, hintText: vTexts.notesHint),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDay,
              icon: const Icon(Icons.event),
              label: Text(
                DateFormat.yMMMd(Localizations.localeOf(pContext).toString()).format(_day),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(vTexts.notesOnlyThis),
              value: _onlyThis,
              onChanged: (pValue) => setState(() => _onlyThis = pValue),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        FilledButton(
          onPressed: () =>
              Navigator.pop(pContext, (day: _day, text: _text.text, onlyThis: _onlyThis)),
          child: Text(vTexts.save),
        ),
      ],
    );
  }
}
