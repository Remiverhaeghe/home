import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ble/tp357_link.dart';
import '../l10n/gen/app_localizations.dart';
import '../logic/climate_exchange.dart';
import '../logic/climate_stats.dart';
import '../logic/reading.dart';
import '../state/sensors_controller.dart';
import 'live_screen.dart';
import 'theme.dart';

/// Choix d'un fichier d'échange ; renvoie son texte, ou null si l'utilisateur renonce.
typedef TextFilePicker = Future<String?> Function();

Future<String?> pickTextFile() async {
  final vFile = await FilePicker.pickFile();
  final rText = vFile == null
      ? null
      : utf8.decode(await vFile.readAsBytes(), allowMalformed: true);

  return rText;
}

/// Écran unique du premier lot : un capteur par carte, avec le dernier relevé.
class SensorsScreen extends StatelessWidget {
  const SensorsScreen({
    super.key,
    required this.controller,
    this.pickFile = pickTextFile,
    this.link,
  });

  final SensorsController controller;
  final TextFilePicker pickFile;

  /// Liaison Bluetooth ; créée à l'ouverture de l'écran des capteurs à portée si absente.
  final Tp357Link? link;

  Future<void> _import(BuildContext pContext) async {
    final vText = await pickFile();
    if (vText == null || !pContext.mounted) {
      return;
    }
    final vCount = await controller.importText(vText);
    if (!pContext.mounted) {
      return;
    }
    final vTexts = AppLocalizations.of(pContext);
    final vMessage = vCount != null
        ? vTexts.importDone(vCount)
        : switch (controller.problem!) {
            ExchangeProblem.notJson => vTexts.importNotJson,
            ExchangeProblem.wrongVersion => vTexts.importWrongVersion,
            ExchangeProblem.noSensors => vTexts.importNoSensors,
          };
    ScaffoldMessenger.of(pContext).showSnackBar(SnackBar(content: Text(vMessage)));
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(
        title: Text(vTexts.sensorsTitle),
        actions: [
          IconButton(
            tooltip: vTexts.liveOpen,
            icon: const Icon(Icons.bluetooth_searching),
            onPressed: () => Navigator.push<void>(
              pContext,
              MaterialPageRoute(
                builder: (_) => LiveScreen(link: link ?? BleTp357Link(), controller: controller),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _import(pContext),
        icon: const Icon(Icons.file_open_outlined),
        label: Text(vTexts.importFile),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (pContext, _) {
          final vSensors = controller.sensors;
          if (vSensors.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(vTexts.sensorsEmpty, textAlign: TextAlign.center),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: vSensors.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, pIndex) => SensorCard(sensor: vSensors[pIndex]),
          );
        },
      ),
    );
  }
}

/// Carte d'un capteur : température, humidité, point de rosée et niveau de l'air.
class SensorCard extends StatelessWidget {
  const SensorCard({super.key, required this.sensor});

  final Sensor sensor;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vColors = HomeColors.of(pContext);
    final vTheme = Theme.of(pContext).textTheme;
    final vLast = sensor.last;
    final vLocale = Localizations.localeOf(pContext).toString();
    final vNumber = NumberFormat('0.0', vLocale);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: vLast == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sensor.name, style: vTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(vTexts.noReading),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sensor.name, style: vTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        vTexts.temperatureValue(vNumber.format(vLast.temp)),
                        style: vTheme.headlineMedium?.copyWith(color: vColors.temperature),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        vTexts.humidityValue(vNumber.format(vLast.humidity)),
                        style: vTheme.headlineMedium?.copyWith(color: vColors.humidity),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _levelLabel(vTexts, humidityLevel(vLast.humidity)),
                    style: TextStyle(
                      color: humidityLevel(vLast.humidity) == HumidityLevel.good
                          ? vColors.good
                          : vColors.warning,
                    ),
                  ),
                  Text(vTexts.dewPointValue(vNumber.format(dewPoint(vLast.temp, vLast.humidity)))),
                  Text(
                    vTexts.lastReading(DateFormat.yMMMd(vLocale).add_Hm().format(vLast.at)),
                    style: vTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }

  static String _levelLabel(AppLocalizations pTexts, HumidityLevel pLevel) => switch (pLevel) {
    HumidityLevel.dry => pTexts.humidityDry,
    HumidityLevel.good => pTexts.humidityGood,
    HumidityLevel.humid => pTexts.humidityHumid,
  };
}
