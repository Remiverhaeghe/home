import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/advice.dart';
import '../logic/pdf_report.dart';
import '../logic/rooms.dart';
import '../state/house_controller.dart';
import '../state/sensors_controller.dart';
import '../state/weather_controller.dart';
import 'house_screen.dart';
import 'units_scope.dart';

/// Les pièces : mesure du moment, humidité visée, pièce la plus fraîche et la plus humide, et
/// conseils d'aération.
class RoomsScreen extends StatelessWidget {
  const RoomsScreen({
    super.key,
    required this.sensors,
    required this.house,
    this.weather,
    this.saveFile,
    this.clock = DateTime.now,
  });

  final SensorsController sensors;
  final HouseController house;
  final WeatherController? weather;

  /// Enregistre le bilan PDF ; sans lui, pas de bouton d'export.
  final Future<bool> Function(String pFileName, Uint8List pBytes)? saveFile;
  final DateTime Function() clock;

  Future<void> _export(BuildContext pContext) async {
    final vTexts = AppLocalizations.of(pContext);
    final vMessenger = ScaffoldMessenger.of(pContext);
    final vNow = clock();
    final vPdf = buildReportPdf(buildRoomReports(sensors.sensors, house.house, vNow), vNow);
    if (await saveFile!('home-bilan.pdf', vPdf)) {
      vMessenger.showSnackBar(SnackBar(content: Text(vTexts.roomsPdfSaved)));
    }
  }

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());
    final vUnits = UnitsScope.of(pContext);

    return Scaffold(
      appBar: AppBar(
        title: Text(vTexts.roomsTitle),
        actions: [
          if (saveFile != null)
            ListenableBuilder(
              listenable: Listenable.merge([sensors, house]),
              builder: (pContext, _) => IconButton(
                tooltip: vTexts.roomsPdfOpen,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: roomStatuses(sensors.sensors, house.house).isEmpty
                    ? null
                    : () => _export(pContext),
              ),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([sensors, house, ?weather]),
        builder: (pContext, _) {
          final vRooms = roomStatuses(sensors.sensors, house.house);
          if (vRooms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(vTexts.roomsEmpty, textAlign: TextAlign.center),
              ),
            );
          }
          final vOutdoor = weather?.readings.isEmpty ?? true ? null : weather!.readings.last;
          final vAdvice = adviceFor(vRooms, vOutdoor);
          final vHumidest = vRooms.length > 1
              ? vRooms.reduce((pA, pB) => pB.humidity > pA.humidity ? pB : pA)
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (vAdvice.isNotEmpty) ...[
                Text(vTexts.adviceTitle, style: Theme.of(pContext).textTheme.titleMedium),
                for (final vItem in vAdvice)
                  Card(
                    child: ListTile(
                      leading: Icon(switch (vItem.kind) {
                        AdviceKind.ventilate => Icons.air,
                        AdviceKind.keepClosed => Icons.sensor_window_outlined,
                        AdviceKind.dryAir => Icons.water_drop_outlined,
                      }),
                      title: Text(switch (vItem.kind) {
                        AdviceKind.ventilate => vTexts.adviceVentilate(vItem.room),
                        AdviceKind.keepClosed => vTexts.adviceKeepClosed(vItem.room),
                        AdviceKind.dryAir => vTexts.adviceDryAir(vItem.room),
                      }),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              for (final (vIndex, vRoom) in vRooms.indexed)
                Card(
                  child: ListTile(
                    title: Text(vRoom.room),
                    subtitle: Text(
                      [
                        if (vRoom.floor != null) floorName(vTexts, vRoom.floor!),
                        if (vRooms.length > 1 && vIndex == 0) vTexts.roomsColdest,
                        if (vRoom == vHumidest) vTexts.roomsHumidest,
                        vTexts.roomsRange(vRoom.range.min.round(), vRoom.range.max.round()),
                      ].join(' · '),
                    ),
                    trailing: Text(
                      vTexts.roomsReading(vUnits.temp(vRoom.temp), vNumber.format(vRoom.humidity)),
                      style: TextStyle(
                        color: vRoom.state == HumidityState.fine
                            ? null
                            : Theme.of(pContext).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
