import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/background/widget_writer.dart';
import 'package:home/logic/house.dart';
import 'package:home/logic/reading.dart';
import 'package:home/storage/file_sensor_store.dart';
import 'package:home/storage/house_store.dart';

void main() {
  final vNow = DateTime(2026, 12, 7, 8, 30);
  late Directory vFolder;

  setUp(() => vFolder = Directory.systemTemp.createTempSync('home_widget_test'));
  tearDown(() => vFolder.deleteSync(recursive: true));

  Future<void> seed(Map<String, double> pTemps) async {
    await FileSensorStore(File('${vFolder.path}/capteurs.json')).save([
      for (final vEntry in pTemps.entries)
        Sensor(
          name: vEntry.key,
          readings: [Reading(at: vNow, temp: vEntry.value, humidity: 48.4)],
        ),
    ]);
    await FileHouseStore(File('${vFolder.path}/maison.json')).save(
      House(places: {for (final vName in pTemps.keys) vName: SensorPlace(room: vName, floor: 0)}),
    );
  }

  test('sans pièce qui a un relevé, aucun fichier n\'est écrit', () async {
    expect(await writeHomeWidget(pFolder: vFolder, pNow: vNow), isFalse);
    expect(File('${vFolder.path}/widget.json').existsSync(), isFalse);
  });

  test('le fichier du widget donne les pièces par ordre alphabétique, quatre au plus', () async {
    await seed({'Salon': 20.46, 'Cave': 12, 'Bureau': 19, 'Chambre': 17.5, 'Atelier': 15});

    expect(await writeHomeWidget(pFolder: vFolder, pNow: vNow), isTrue);
    final vJson = jsonDecode(File('${vFolder.path}/widget.json').readAsStringSync()) as Map;
    final vRooms = vJson['pieces'] as List;

    expect(vRooms.map((pRoom) => (pRoom as Map)['nom']), ['Atelier', 'Bureau', 'Cave', 'Chambre']);
    expect((vRooms.first as Map)['temp'], 15.0);
    expect((vRooms.first as Map)['hum'], 48);
    expect(vJson['at'], vNow.toIso8601String());
  });
}
