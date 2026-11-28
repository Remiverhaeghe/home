import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/relay.dart';
import '../logic/scenarios.dart';
import '../state/relay_controller.dart';
import '../storage/background_files.dart';

/// Scénario Aération : envoie l'impulsion à chaque Velux, puis rappelle au bout de
/// [airingMinutes] minutes de refermer ou de renvoyer l'impulsion. Un second appui annule le rappel.
class AiringChip extends StatefulWidget {
  const AiringChip({super.key, required this.relays, required this.files, required this.clock});

  final RelayController relays;
  final BackgroundFiles files;
  final DateTime Function() clock;

  @override
  State<AiringChip> createState() => _AiringChipState();
}

class _AiringChipState extends State<AiringChip> {
  DateTime? _until;

  @override
  void initState() {
    super.initState();
    widget.files.airingUntil().then((pUntil) {
      if (mounted) {
        setState(() => _until = pUntil);
      }
    });
  }

  Future<void> _toggle() async {
    if (_until != null) {
      setState(() => _until = null);
      await widget.files.setAiringUntil(null);

      return;
    }
    for (final vButton in widget.relays.buttons.where(
      (pButton) => pButton.kind == RelayKind.velux,
    )) {
      await widget.relays.press(vButton);
    }
    final vUntil = widget.clock().add(const Duration(minutes: airingMinutes));
    if (mounted) {
      setState(() => _until = vUntil);
    }
    await widget.files.setAiringUntil(vUntil);
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    if (!widget.relays.buttons.any((pButton) => pButton.kind == RelayKind.velux)) {
      return const SizedBox.shrink();
    }

    return FilterChip(
      key: const Key('scenario-airing'),
      label: Text(vTexts.planScenarioAiring(airingMinutes)),
      selected: _until != null,
      onSelected: (_) => _toggle(),
    );
  }
}
