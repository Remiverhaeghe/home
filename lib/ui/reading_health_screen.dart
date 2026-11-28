import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../background/background_control.dart';
import '../l10n/gen/app_localizations.dart';
import '../logic/read_health.dart';
import '../storage/background_files.dart';

/// Santé du relevé en arrière-plan : pour chaque capteur suivi, le dernier relevé, les tours
/// manqués d'affilée et la part de tours réussis, et l'exemption de l'économie de batterie.
class ReadingHealthScreen extends StatefulWidget {
  const ReadingHealthScreen({
    super.key,
    required this.files,
    this.background,
    this.clock = DateTime.now,
  });

  final BackgroundFiles files;
  final BackgroundControl? background;
  final DateTime Function() clock;

  @override
  State<ReadingHealthScreen> createState() => _ReadingHealthScreenState();
}

class _ReadingHealthScreenState extends State<ReadingHealthScreen> {
  late Future<ReadHealth> _health = widget.files.loadHealth();
  late Future<bool>? _battery = widget.background?.isIgnoringBatteryOptimizations();

  void _reload() {
    setState(() {
      _health = widget.files.loadHealth();
      _battery = widget.background?.isIgnoringBatteryOptimizations();
    });
  }

  Future<void> _allow() async {
    await widget.background?.requestIgnoreBatteryOptimizations();
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vLocale = Localizations.localeOf(pContext).toString();
    final vNow = widget.clock();

    return Scaffold(
      appBar: AppBar(
        title: Text(vTexts.readingHealthTitle),
        actions: [
          IconButton(
            tooltip: vTexts.readingHealthRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<ReadHealth>(
        future: _health,
        builder: (pContext, pSnapshot) {
          final vHealth = pSnapshot.data;
          if (vHealth == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_battery != null)
                FutureBuilder<bool>(
                  future: _battery,
                  builder: (pContext, pBattery) {
                    final vIgnoring = pBattery.data;
                    if (vIgnoring == null) {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      child: ListTile(
                        leading: Icon(vIgnoring ? Icons.battery_full : Icons.battery_alert),
                        title: Text(
                          vIgnoring
                              ? vTexts.readingHealthBatteryFree
                              : vTexts.readingHealthBatteryLimited,
                        ),
                        subtitle: vIgnoring ? null : Text(vTexts.readingHealthBatteryHint),
                        trailing: vIgnoring
                            ? null
                            : FilledButton.tonal(
                                key: const Key('battery-allow'),
                                onPressed: _allow,
                                child: Text(vTexts.readingHealthBatteryAllow),
                              ),
                      ),
                    );
                  },
                ),
              if (vHealth.sensors.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(vTexts.readingHealthEmpty),
                )
              else
                for (final vEntry in vHealth.sensors.entries)
                  Card(
                    child: ListTile(
                      title: Text(vEntry.key),
                      subtitle: Text(_lines(vTexts, vLocale, vEntry.value, vNow).join('\n')),
                      isThreeLine: true,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  List<String> _lines(
    AppLocalizations pTexts,
    String pLocale,
    SensorHealth pHealth,
    DateTime pNow,
  ) {
    final vLastOk = pHealth.lastOk;
    final vRate = pHealth.rateOver(7, pNow);
    final vToday = pHealth.today(pNow);

    return [
      vLastOk == null
          ? pTexts.readingHealthNeverOk
          : pTexts.readingHealthLastOk(DateFormat.yMMMd(pLocale).add_Hm().format(vLastOk)),
      if (pHealth.streak > 0) pTexts.readingHealthStreak(pHealth.streak),
      if (vRate != null) pTexts.readingHealthRate((vRate * 100).round()),
      if (vToday.total > 0) pTexts.readingHealthToday(vToday.ok, vToday.missed),
    ];
  }
}
