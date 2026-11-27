import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/relay.dart';
import '../state/relay_controller.dart';

/// Porte de garage et Velux : un gros bouton par commande. La porte demande toujours confirmation.
class RelayScreen extends StatelessWidget {
  const RelayScreen({super.key, required this.controller});

  final RelayController controller;

  static IconData iconOf(RelayKind pKind) => switch (pKind) {
    RelayKind.garage => Icons.garage_outlined,
    RelayKind.velux => Icons.roofing,
    RelayKind.other => Icons.touch_app_outlined,
  };

  Future<void> _press(BuildContext pContext, RelayButton pButton) async {
    final vTexts = AppLocalizations.of(pContext);
    final vMessenger = ScaffoldMessenger.of(pContext);
    if (pButton.needsConfirmation) {
      final vOk = await showDialog<bool>(
        context: pContext,
        builder: (pDialog) => AlertDialog(
          title: Text(vTexts.relayConfirmTitle),
          content: Text(vTexts.relayConfirmBody(pButton.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(pDialog, false), child: Text(vTexts.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(pDialog, true),
              child: Text(vTexts.relayConfirmGo),
            ),
          ],
        ),
      );
      if (!(vOk ?? false)) {
        return;
      }
    }
    final vResult = await controller.press(pButton);
    // Le dernier message remplace le précédent au lieu de faire la queue derrière lui
    vMessenger.hideCurrentSnackBar();
    vMessenger.showSnackBar(
      SnackBar(
        content: Text(switch (vResult) {
          PressResult.sent => vTexts.relaySent,
          PressResult.tooSoon => vTexts.relayTooSoon,
          PressResult.failed => vTexts.relayFailed,
        }),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext pContext, RelayButton pButton) async {
    final vTexts = AppLocalizations.of(pContext);
    final vOk = await showDialog<bool>(
      context: pContext,
      builder: (pDialog) => AlertDialog(
        content: Text(vTexts.relayRemoveConfirm(pButton.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(pDialog, false), child: Text(vTexts.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(pDialog, true),
            child: Text(vTexts.relayRemove),
          ),
        ],
      ),
    );
    if (vOk ?? false) {
      await controller.remove(pButton);
    }
  }

  Future<void> _add(BuildContext pContext) async {
    final vTexts = AppLocalizations.of(pContext);
    final vMessenger = ScaffoldMessenger.of(pContext);
    final vButton = await showDialog<RelayButton>(
      context: pContext,
      builder: (_) => const _AddDialog(),
    );
    if (vButton == null) {
      return;
    }
    final vProblem = await controller.add(vButton);
    if (vProblem != null) {
      vMessenger.showSnackBar(
        SnackBar(
          content: Text(switch (vProblem) {
            RelayAddProblem.emptyName => vTexts.relayProblemName,
            RelayAddProblem.notPrivate => vTexts.relayProblemHost,
          }),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.relayTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(pContext),
        icon: const Icon(Icons.add),
        label: Text(vTexts.relayAdd),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (pContext, _) {
          final vButtons = controller.buttons;
          if (vButtons.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(vTexts.relayEmpty, textAlign: TextAlign.center),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: vButtons.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, pIndex) {
              final vButton = vButtons[pIndex];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(iconOf(vButton.kind), size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(vButton.name, style: Theme.of(pContext).textTheme.titleMedium),
                      ),
                      IconButton(
                        tooltip: vTexts.relayRemove,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmRemove(pContext, vButton),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(96, 56)),
                        onPressed: () => _press(pContext, vButton),
                        child: Text(vTexts.relayPress),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Saisie d'un bouton. Les champs vivent dans cette boîte : ils ne sont détruits qu'avec elle.
class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _channel = TextEditingController(text: '0');
  final _pulse = TextEditingController(text: '1');
  var _kind = RelayKind.garage;
  var _model = RelayModel.shellyGen2;

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _channel.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String _kindLabel(AppLocalizations pTexts, RelayKind pKind) => switch (pKind) {
    RelayKind.garage => pTexts.relayKindGarage,
    RelayKind.velux => pTexts.relayKindVelux,
    RelayKind.other => pTexts.relayKindOther,
  };

  String _modelLabel(AppLocalizations pTexts, RelayModel pModel) => switch (pModel) {
    RelayModel.shellyGen2 => pTexts.relayModelGen2,
    RelayModel.shellyGen1 => pTexts.relayModelGen1,
  };

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return AlertDialog(
      title: Text(vTexts.relayAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: vTexts.relayName),
            ),
            TextField(
              controller: _host,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: vTexts.relayHost),
            ),
            DropdownButtonFormField<RelayKind>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: vTexts.relayKind),
              items: [
                for (final vKind in RelayKind.values)
                  DropdownMenuItem(value: vKind, child: Text(_kindLabel(vTexts, vKind))),
              ],
              onChanged: (pKind) => setState(() => _kind = pKind ?? _kind),
            ),
            DropdownButtonFormField<RelayModel>(
              initialValue: _model,
              decoration: InputDecoration(labelText: vTexts.relayModel),
              items: [
                for (final vModel in RelayModel.values)
                  DropdownMenuItem(value: vModel, child: Text(_modelLabel(vTexts, vModel))),
              ],
              onChanged: (pModel) => setState(() => _model = pModel ?? _model),
            ),
            TextField(
              controller: _channel,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: vTexts.relayChannel),
            ),
            TextField(
              controller: _pulse,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: vTexts.relayPulse),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            pContext,
            RelayButton(
              name: _name.text,
              host: _host.text,
              kind: _kind,
              model: _model,
              channel: int.tryParse(_channel.text.trim()) ?? 0,
              pulseSeconds: int.tryParse(_pulse.text.trim()) ?? 1,
            ),
          ),
          child: Text(vTexts.save),
        ),
      ],
    );
  }
}
