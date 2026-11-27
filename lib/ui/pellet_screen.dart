import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/pellet.dart';
import '../state/pellet_controller.dart';

/// Poêle à pellets : température de la pièce, état, marche ou arrêt, consigne par pas de 0,5 °C.
class PelletScreen extends StatefulWidget {
  const PelletScreen({super.key, required this.controller});

  final PelletController controller;

  @override
  State<PelletScreen> createState() => _PelletScreenState();
}

class _PelletScreenState extends State<PelletScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.refresh();
  }

  static String _degrees(double pValue) => pValue.toStringAsFixed(1).replaceAll('.', ',');

  void _say(String pMessage) {
    final vMessenger = ScaffoldMessenger.of(context);
    vMessenger.hideCurrentSnackBar();
    vMessenger.showSnackBar(SnackBar(content: Text(pMessage)));
  }

  Future<void> _run(Future<PelletResult> pCommand) async {
    final vTexts = AppLocalizations.of(context);
    final vResult = await pCommand;
    if (mounted && vResult != PelletResult.done) {
      _say(vTexts.pelletFailed);
    }
  }

  Future<void> _setup() async {
    final vTexts = AppLocalizations.of(context);
    final vStove = await showDialog<PelletStove>(
      context: context,
      builder: (_) => const _SetupDialog(),
    );
    if (vStove == null) {
      return;
    }
    final vProblem = await widget.controller.setup(vStove);
    if (!mounted) {
      return;
    }
    if (vProblem != null) {
      _say(switch (vProblem) {
        PelletSetupProblem.emptyName => vTexts.pelletProblemName,
        PelletSetupProblem.notPrivate => vTexts.pelletProblemHost,
        PelletSetupProblem.noLogin => vTexts.pelletProblemLogin,
      });

      return;
    }
    await widget.controller.refresh();
  }

  Future<void> _remove() async {
    final vTexts = AppLocalizations.of(context);
    final vName = widget.controller.stove?.name ?? '';
    final vOk = await showDialog<bool>(
      context: context,
      builder: (pDialog) => AlertDialog(
        content: Text(vTexts.pelletRemoveConfirm(vName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(pDialog, false), child: Text(vTexts.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(pDialog, true),
            child: Text(vTexts.pelletRemove),
          ),
        ],
      ),
    );
    if (vOk ?? false) {
      await widget.controller.remove();
    }
  }

  String _phase(AppLocalizations pTexts, PelletState pState) => switch (pState.phase) {
    PelletPhase.off => pTexts.pelletPhaseOff,
    PelletPhase.running => pTexts.pelletPhaseRunning,
    PelletPhase.other => pTexts.pelletPhaseOther(pState.code),
  };

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(
        title: Text(vTexts.pelletTitle),
        actions: [
          ListenableBuilder(
            listenable: widget.controller,
            builder: (_, _) => widget.controller.stove == null
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      IconButton(
                        tooltip: vTexts.pelletRefresh,
                        icon: const Icon(Icons.refresh),
                        onPressed: widget.controller.refresh,
                      ),
                      IconButton(
                        tooltip: vTexts.pelletRemove,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _remove,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (pContext, _) {
          final vStove = widget.controller.stove;
          if (vStove == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(vTexts.pelletEmpty, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _setup, child: Text(vTexts.pelletAdd)),
                  ],
                ),
              ),
            );
          }
          final vState = widget.controller.state;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(vStove.name, style: Theme.of(pContext).textTheme.titleLarge),
              if (widget.controller.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    vTexts.pelletUnreachable,
                    style: TextStyle(color: Theme.of(pContext).colorScheme.error),
                  ),
                ),
              if (vState != null) ...[
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    vTexts.pelletRoom(_degrees(vState.roomC)),
                    style: Theme.of(pContext).textTheme.displayMedium,
                  ),
                ),
                Text(_phase(vTexts, vState)),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(vTexts.pelletPower),
                  value: vState.isOn,
                  onChanged: (pOn) => _run(widget.controller.setPower(pOn: pOn)),
                ),
                ListTile(
                  title: Text(vTexts.pelletTarget),
                  subtitle: Text(vTexts.pelletRoom(_degrees(vState.targetC))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: vTexts.pelletLower,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: vState.targetC <= pelletMinTarget
                            ? null
                            : () => _run(widget.controller.setTarget(vState.targetC - 0.5)),
                      ),
                      IconButton(
                        tooltip: vTexts.pelletRaise,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: vState.targetC >= pelletMaxTarget
                            ? null
                            : () => _run(widget.controller.setTarget(vState.targetC + 0.5)),
                      ),
                    ],
                  ),
                ),
                if (vState.powerLevel != null)
                  ListTile(
                    title: Text(vTexts.pelletLevel),
                    subtitle: Text('${vState.powerLevel}'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Saisie du poêle. Les champs vivent dans cette boîte : ils ne sont détruits qu'avec elle.
class _SetupDialog extends StatefulWidget {
  const _SetupDialog();

  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> {
  final _name = TextEditingController(text: 'Poêle');
  final _host = TextEditingController();
  final _serial = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _serial.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return AlertDialog(
      title: Text(vTexts.pelletAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: vTexts.pelletName),
            ),
            TextField(
              controller: _host,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: vTexts.pelletHost),
            ),
            TextField(
              controller: _serial,
              decoration: InputDecoration(labelText: vTexts.pelletSerial),
            ),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: vTexts.pelletPassword,
                helperText: vTexts.pelletPasswordHelp,
                helperMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(pContext), child: Text(vTexts.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            pContext,
            PelletStove(
              name: _name.text,
              host: _host.text,
              serial: _serial.text,
              password: _password.text,
            ),
          ),
          child: Text(vTexts.save),
        ),
      ],
    );
  }
}
