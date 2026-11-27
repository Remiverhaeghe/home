import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ble/tp357_link.dart';
import '../l10n/gen/app_localizations.dart';
import '../logic/tp357.dart';

/// Trames brutes de l'historique d'un capteur, pour vérifier le décodage avec l'appli du fabricant.
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key, required this.link, required this.device});

  final Tp357Link link;
  final Tp357Device device;

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  /// Au-delà, les trames suivantes ne sont plus affichées (elles restent comptées).
  static const _maxShown = 300;

  final _lines = <String>[];
  var _count = 0;
  var _period = HistoryPeriod.day;
  StreamSubscription<List<int>>? _frames;
  bool _failed = false;

  @override
  void dispose() {
    unawaited(_frames?.cancel());
    super.dispose();
  }

  void _ask() {
    unawaited(_frames?.cancel());
    setState(() {
      _lines.clear();
      _count = 0;
      _failed = false;
    });
    _frames = widget.link.rawHistory(widget.device.id, _period).listen((pFrame) {
      setState(() {
        _count++;
        if (_lines.length < _maxShown) {
          _lines.add(hexOf(pFrame));
        }
      });
    }, onError: (Object _) => setState(() => _failed = true));
  }

  Future<void> _copy(BuildContext pContext) async {
    final vTexts = AppLocalizations.of(pContext);
    await Clipboard.setData(ClipboardData(text: _lines.join('\n')));
    if (pContext.mounted) {
      ScaffoldMessenger.of(pContext).showSnackBar(SnackBar(content: Text(vTexts.diagnosticCopied)));
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.diagnosticTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(vTexts.diagnosticHelp),
          const SizedBox(height: 12),
          SegmentedButton<HistoryPeriod>(
            segments: [
              ButtonSegment(value: HistoryPeriod.day, label: Text(vTexts.diagnosticDay)),
              ButtonSegment(value: HistoryPeriod.week, label: Text(vTexts.diagnosticWeek)),
              ButtonSegment(value: HistoryPeriod.year, label: Text(vTexts.diagnosticYear)),
            ],
            selected: {_period},
            onSelectionChanged: (pSelected) => setState(() => _period = pSelected.first),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _ask, child: Text(vTexts.diagnosticAsk)),
          if (_failed) ...[
            const SizedBox(height: 12),
            Text(vTexts.bluetoothError, style: TextStyle(color: Theme.of(pContext).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Text(vTexts.diagnosticCount(_count)),
          if (_lines.isNotEmpty)
            TextButton(onPressed: () => _copy(pContext), child: Text(vTexts.diagnosticCopy)),
          for (final vLine in _lines)
            Text(vLine, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
      ),
    );
  }
}
