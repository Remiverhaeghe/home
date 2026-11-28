import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../logic/advice.dart';
import '../logic/rooms.dart';
import '../state/house_controller.dart';
import '../state/sensors_controller.dart';
import '../state/weather_controller.dart';
import 'house_screen.dart';

/// Les pièces : mesure du moment, humidité visée, pièce la plus fraîche et la plus humide, et
/// conseils d'aération.
class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key, required this.sensors, required this.house, this.weather});

  final SensorsController sensors;
  final HouseController house;
  final WeatherController? weather;

  @override
  Widget build(BuildContext pContext) {
    final vTexts = AppLocalizations.of(pContext);
    final vNumber = NumberFormat('0.0', Localizations.localeOf(pContext).toString());

    return Scaffold(
      appBar: AppBar(title: Text(vTexts.roomsTitle)),
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
                      vTexts.roomsReading(
                        vNumber.format(vRoom.temp),
                        vNumber.format(vRoom.humidity),
                      ),
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
