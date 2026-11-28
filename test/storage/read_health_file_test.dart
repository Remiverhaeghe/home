import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/read_health.dart';
import 'package:home/storage/background_files.dart';

void main() {
  test('la santé du relevé passe du service à l\'appli par le fichier', () async {
    final vFolder = Directory.systemTemp.createTempSync('home_health_file');
    addTearDown(() => vFolder.deleteSync(recursive: true));
    final vService = BackgroundFiles(vFolder);
    final vApp = BackgroundFiles(vFolder);

    expect((await vApp.loadHealth()).sensors, isEmpty);

    final vAt = DateTime(2026, 12, 7, 9);
    await vService.saveHealth(const ReadHealth().record('Salon', vAt, pOk: false));

    final vRead = await vApp.loadHealth();
    expect(vRead.of('Salon').streak, 1);
    expect(vRead.of('Salon').lastTry, vAt);
  });
}
