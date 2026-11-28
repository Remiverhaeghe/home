import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/alert_history.dart';
import '../logic/alerts.dart';
import '../storage/background_files.dart';

/// Les dernières alertes, la plus récente en haut.
class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key, required this.files});

  final BackgroundFiles files;

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  late final Future<List<AlertEntry>> _entries = widget.files.loadAlertHistory();

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vLocale = Localizations.localeOf(pContext).toString();
    final vDate = DateFormat.MMMd(vLocale).add_Hm();

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.alertHistoryTitle)),
      body: FutureBuilder<List<AlertEntry>>(
        future: _entries,
        builder: (pContext, pSnapshot) {
          final vEntries = (pSnapshot.data ?? const <AlertEntry>[]).reversed.toList();
          if (pSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vEntries.isEmpty) {
            return Center(child: Text(vTexts.alertHistoryEmpty));
          }

          return ListView(
            children: [
              for (final vEntry in vEntries)
                ListTile(
                  leading: Icon(
                    vEntry.kind == AlertKind.frost ? Icons.ac_unit : Icons.warning_amber,
                  ),
                  title: Text(vTexts.alertHistoryLine(vEntry.sensorName, vEntry.kind.name)),
                  subtitle: Text(vDate.format(vEntry.at)),
                ),
            ],
          );
        },
      ),
    );
  }
}
