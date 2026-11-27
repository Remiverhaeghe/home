import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/tp357.dart';

void main() {
  group('mesure en direct', () {
    test('température et humidité sont lues dans la trame', () {
      final vValue = parseLiveFrame([0xC2, 0x00, 0x00, 0xEB, 0x00, 0x3D, 0x00]);

      expect(vValue!.temp, 23.5);
      expect(vValue.humidity, 61);
    });

    test('une température négative est lue avec son signe', () {
      final vValue = parseLiveFrame([0xC2, 0, 0, 0xCC, 0xFF, 80]);

      expect(vValue!.temp, -5.2);
      expect(vValue.humidity, 80);
    });

    test('une autre trame, trop courte ou hors norme est ignorée', () {
      expect(parseLiveFrame([0xA7, 0, 0, 0xEB, 0, 61]), isNull);
      expect(parseLiveFrame([0xC2, 0, 0, 0xEB, 0]), isNull);
      expect(parseLiveFrame([]), isNull);
      expect(parseLiveFrame([0xC2, 0, 0, 0xEB, 0, 101]), isNull);
    });

    test('la limite de 100 % est acceptée', () {
      expect(parseLiveFrame([0xC2, 0, 0, 0xEB, 0, 100])!.humidity, 100);
    });
  });

  group('noms de capteurs', () {
    test('un TP357 est reconnu, sans tenir compte des majuscules', () {
      expect(isTp357Name('TP357 (1A2B)'), isTrue);
      expect(isTp357Name('tp357 (1A2B)'), isTrue);
      expect(isTp357Name('TP359 (1A2B)'), isFalse);
      expect(isTp357Name(''), isFalse);
    });

    test('l\'historique n\'est proposé qu\'au TP357 d\'origine', () {
      expect(hasTp357History('TP357 (1A2B)'), isTrue);
      expect(hasTp357History('TP357S (1A2B)'), isFalse);
      expect(hasTp357History('Autre'), isFalse);
    });
  });

  group('demande d\'historique', () {
    test('chaque période a son opération et son octet de contrôle', () {
      expect(historyRequest(HistoryPeriod.day), [0xA7, 0x01, 0x00, 0x7A]);
      expect(historyRequest(HistoryPeriod.week), [0xA6, 0x01, 0x00, 0x6A]);
      expect(historyRequest(HistoryPeriod.year), [0xA8, 0x01, 0x00, 0x8A]);
    });
  });

  group('trame d\'historique', () {
    const vFrame = [
      0xA7, 0x10, 0x00, 0x00, //
      0xEB, 0x00, 0x3D,
      0xFF, 0xFF, 0xFF,
      0xCC, 0xFF, 0x50,
    ];

    test('les relevés sont lus, un relevé vide vaut null', () {
      final vRecords = parseHistoryFrame(vFrame, HistoryPeriod.day)!;

      expect(vRecords, hasLength(3));
      expect(vRecords[0]!.temp, 23.5);
      expect(vRecords[0]!.humidity, 61);
      expect(vRecords[1], isNull);
      expect(vRecords[2]!.temp, -5.2);
      expect(vRecords[2]!.humidity, 80);
    });

    test('une trame d\'une autre période ou trop courte est refusée', () {
      expect(parseHistoryFrame(vFrame, HistoryPeriod.week), isNull);
      expect(parseHistoryFrame([0xA7, 0x10], HistoryPeriod.day), isNull);
    });

    test('un relevé coupé en fin de trame est laissé de côté', () {
      final vRecords = parseHistoryFrame([
        0xA7,
        0,
        0,
        0,
        0xEB,
        0x00,
        0x3D,
        0xEB,
      ], HistoryPeriod.day);

      expect(vRecords, hasLength(1));
    });

    test('une trame sans relevé donne une liste vide', () {
      expect(parseHistoryFrame([0xA8, 0, 0, 0], HistoryPeriod.year), isEmpty);
    });
  });

  test('l\'hexadécimal est sur deux chiffres, séparé par des espaces', () {
    expect(hexOf([0xA7, 0x01, 0x00, 0x7A]), 'a7 01 00 7a');
    expect(hexOf([]), '');
  });
}
