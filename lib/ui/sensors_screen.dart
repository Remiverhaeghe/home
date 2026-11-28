import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../background/background_control.dart';
import '../ble/tp357_link.dart';
import '../l10n/gen/app_localizations.dart';
import '../logic/climate_exchange.dart';
import '../logic/climate_stats.dart';
import '../logic/reading.dart';
import '../state/ac_controller.dart';
import '../state/plan_controller.dart';
import '../logic/house.dart';
import '../state/house_controller.dart';
import '../storage/backup_files.dart';
import '../state/pellet_controller.dart';
import '../state/weather_controller.dart';
import '../state/relay_controller.dart';
import '../state/sensors_controller.dart';
import '../storage/background_files.dart';
import 'ac_screen.dart';
import 'live_screen.dart';
import 'plan_screen.dart';
import 'backup_screen.dart';
import 'house_screen.dart';
import 'pellet_screen.dart';
import 'relay_screen.dart';
import 'sensor_detail_screen.dart';
import 'theme.dart';
import 'wall_display.dart';
import 'wall_screen.dart';

/// Choix d'un fichier d'échange ; renvoie son texte, ou null si l'utilisateur renonce.
typedef TextFilePicker = Future<String?> Function();

Future<String?> pickTextFile() async {
  final vFile = await FilePicker.pickFile();
  final rText = vFile == null ? null : utf8.decode(await vFile.readAsBytes(), allowMalformed: true);

  return rText;
}

/// Enregistrement d'un fichier choisi par l'utilisateur ; renvoie false s'il renonce.
typedef FileSaver = Future<bool> Function(String pFileName, Uint8List pBytes);

Future<bool> saveFileDialog(String pFileName, Uint8List pBytes) async {
  final vSaved = await FilePicker.saveFile(fileName: pFileName, bytes: pBytes);

  return vSaved != null;
}

/// Écran unique du premier lot : un capteur par carte, avec le dernier relevé.
class SensorsScreen extends StatelessWidget {
  const SensorsScreen({
    super.key,
    required this.controller,
    this.pickFile = pickTextFile,
    this.saveFile = saveFileDialog,
    this.link,
    this.acController,
    this.planController,
    this.background,
    this.files,
    this.wallDisplay,
    this.relayController,
    this.pelletController,
    this.houseController,
    this.weatherController,
    this.backupFiles,
    this.onRestored,
  });

  final SensorsController controller;
  final TextFilePicker pickFile;
  final FileSaver saveFile;

  /// Liaison Bluetooth ; créée à l'ouverture de l'écran des capteurs à portée si absente.
  final Tp357Link? link;

  /// Climatisations ; le bouton qui les ouvre n'apparaît que si elles sont fournies.
  final AcController? acController;

  /// Pilotage ; son bouton n'apparaît que si les climatisations et le pilotage sont fournis.
  final PlanController? planController;

  /// Relevé en arrière-plan, transmis à l'écran des capteurs à portée.
  final BackgroundControl? background;
  final BackgroundFiles? files;

  /// Plein écran, paysage et écran allumé de l'affichage mural ; ceux de l'appareil si absent.
  final WallDisplay? wallDisplay;

  /// Garage et Velux ; le bouton qui les ouvre n'apparaît que s'ils sont fournis.
  final RelayController? relayController;
  final PelletController? pelletController;
  final HouseController? houseController;
  final WeatherController? weatherController;

  /// Sauvegarde et restauration ; le bouton n'apparaît que si les fichiers et la relecture sont fournis.
  final BackupFiles? backupFiles;
  final Future<void> Function()? onRestored;

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

  /// Enregistre tous les capteurs dans un fichier d'échange que l'on ouvre ensuite dans Atelier.
  Future<void> _export(BuildContext pContext) async {
    final vTexts = AppLocalizations.of(pContext);
    final vBytes = Uint8List.fromList(utf8.encode(exchangeJson(controller.sensors)));
    final vSaved = await saveFile('home-climat.json', vBytes);
    if (vSaved && pContext.mounted) {
      ScaffoldMessenger.of(pContext).showSnackBar(SnackBar(content: Text(vTexts.exportDone)));
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);

    return Scaffold(
      appBar: AppBar(
        title: Text(vTexts.sensorsTitle),
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (pContext, _) => IconButton(
              tooltip: vTexts.exportFile,
              icon: const Icon(Icons.ios_share),
              onPressed: controller.sensors.isEmpty ? null : () => _export(pContext),
            ),
          ),
          if (acController != null)
            IconButton(
              tooltip: vTexts.acOpen,
              icon: const Icon(Icons.ac_unit),
              onPressed: () => Navigator.push<void>(
                pContext,
                MaterialPageRoute(
                  builder: (_) => AcScreen(controller: acController!, sensors: controller),
                ),
              ),
            ),
          if (relayController != null)
            IconButton(
              tooltip: vTexts.relayOpen,
              icon: const Icon(Icons.garage_outlined),
              onPressed: () => Navigator.push<void>(
                pContext,
                MaterialPageRoute(builder: (_) => RelayScreen(controller: relayController!)),
              ),
            ),
          if (backupFiles != null && onRestored != null)
            IconButton(
              tooltip: vTexts.backupOpen,
              icon: const Icon(Icons.backup_outlined),
              onPressed: () => Navigator.push<void>(
                pContext,
                MaterialPageRoute(
                  builder: (_) => BackupScreen(
                    files: backupFiles!,
                    pickFile: pickFile,
                    saveFile: saveFile,
                    onRestored: onRestored!,
                  ),
                ),
              ),
            ),
          if (houseController != null)
            IconButton(
              tooltip: vTexts.houseOpen,
              icon: const Icon(Icons.home_work_outlined),
              onPressed: () => Navigator.push<void>(
                pContext,
                MaterialPageRoute(
                  builder: (_) =>
                      HouseScreen(controller: houseController!, weather: weatherController),
                ),
              ),
            ),
          if (pelletController != null)
            IconButton(
              tooltip: vTexts.pelletOpen,
              icon: const Icon(Icons.local_fire_department_outlined),
              onPressed: () => Navigator.push<void>(
                pContext,
                MaterialPageRoute(builder: (_) => PelletScreen(controller: pelletController!)),
              ),
            ),
          if (acController != null)
            IconButton(
              tooltip: vTexts.wallOpen,
              icon: const Icon(Icons.tablet_android),
              onPressed: () => Navigator.push<void>(
                pContext,
                MaterialPageRoute(
                  builder: (_) => WallScreen(
                    sensors: controller,
                    ac: acController!,
                    display: wallDisplay ?? PlatformWallDisplay(),
                  ),
                ),
              ),
            ),
          if (acController != null && planController != null)
            IconButton(
              tooltip: vTexts.planOpen,
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.push<void>(
                pContext,
                MaterialPageRoute(
                  builder: (_) =>
                      PlanScreen(plan: planController!, ac: acController!, sensors: controller),
                ),
              ),
            ),
          IconButton(
            tooltip: vTexts.liveOpen,
            icon: const Icon(Icons.bluetooth_searching),
            onPressed: () => Navigator.push<void>(
              pContext,
              MaterialPageRoute(
                builder: (_) => LiveScreen(
                  link: link ?? BleTp357Link(),
                  controller: controller,
                  background: background,
                  files: files,
                ),
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
        listenable: Listenable.merge([controller, ?houseController]),
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
          final vHouse = houseController?.house ?? const House();
          final vGroups = groupSensors(vSensors, vHouse);
          final vTitled = vHouse.places.isNotEmpty;
          final vItems = <Widget>[
            for (final vGroup in vGroups) ...[
              if (vTitled)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _groupTitle(vTexts, vGroup),
                    style: Theme.of(pContext).textTheme.titleSmall,
                  ),
                ),
              for (final vSensor in vGroup.sensors)
                SensorCard(
                  sensor: vSensor,
                  place: _placeSummary(vTexts, vHouse.placeOf(vSensor.name)),
                  onTap: () => Navigator.push<void>(
                    pContext,
                    MaterialPageRoute(
                      builder: (_) => SensorDetailScreen(
                        sensor: vSensor,
                        onRename: (pLabel) => controller.rename(vSensor.name, pLabel),
                        outdoor: weatherController?.readings ?? const [],
                        onEditPlace: houseController == null
                            ? null
                            : () async {
                                final vPlace = await editPlace(
                                  pContext,
                                  houseController!.house.placeOf(vSensor.name),
                                );
                                if (vPlace != null) {
                                  await houseController!.setPlace(vSensor.name, vPlace);
                                }
                              },
                      ),
                    ),
                  ),
                ),
            ],
          ];

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: vItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, pIndex) => vItems[pIndex],
          );
        },
      ),
    );
  }
}

String _groupTitle(AppLocalizations pTexts, SensorGroup pGroup) {
  if (pGroup.outdoor) {
    return pTexts.groupOutdoor;
  }

  return pGroup.floor == null ? pTexts.groupUnplaced : floorName(pTexts, pGroup.floor!);
}

/// « Chambre · Premier étage », ou rien quand l'emplacement est vide.
String? _placeSummary(AppLocalizations pTexts, SensorPlace pPlace) {
  if (pPlace.isEmpty) {
    return null;
  }
  final vRoom = pPlace.room.trim();
  final vFloor = pPlace.outdoor
      ? pTexts.groupOutdoor
      : pPlace.floor == null
      ? ''
      : floorName(pTexts, pPlace.floor!);
  if (vRoom.isEmpty || vFloor.isEmpty) {
    return vRoom.isEmpty ? vFloor : vRoom;
  }

  return pTexts.placeSummary(vRoom, vFloor);
}

/// Carte d'un capteur : température, humidité, point de rosée et niveau de l'air.
class SensorCard extends StatelessWidget {
  const SensorCard({super.key, required this.sensor, this.onTap, this.place});

  final Sensor sensor;

  /// Où se trouve le capteur, sous son nom ; rien quand il n'est pas rangé.
  final String? place;

  /// Ouvre le détail du capteur.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vColors = HomeColors.of(pContext);
    final vTheme = Theme.of(pContext).textTheme;
    final vLast = sensor.last;
    final vLocale = Localizations.localeOf(pContext).toString();
    final vNumber = NumberFormat('0.0', vLocale);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: vLast == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sensor.title, style: vTheme.titleMedium),
                    if (place != null) Text(place!, style: vTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(vTexts.noReading),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sensor.title, style: vTheme.titleMedium),
                    if (place != null) Text(place!, style: vTheme.bodySmall),
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
                    Text(
                      vTexts.dewPointValue(vNumber.format(dewPoint(vLast.temp, vLast.humidity))),
                    ),
                    Text(
                      vTexts.lastReading(DateFormat.yMMMd(vLocale).add_Hm().format(vLast.at)),
                      style: vTheme.bodySmall,
                    ),
                  ],
                ),
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
