import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/climate_stats.dart';
import 'package:home/logic/house.dart';
import 'package:home/logic/pdf_report.dart';
import 'package:home/logic/reading.dart';

final _now = DateTime(2026, 12, 14, 9);

RoomReport _report(String pName, {List<DayAverage>? pDays, double? pMin = 17.2}) => RoomReport(
  room: pName,
  floor: 0,
  temp: 20.5,
  humidity: 52,
  minTemp: pMin,
  maxTemp: pMin == null ? null : 22.1,
  minHumidity: 41,
  maxHumidity: 68,
  days:
      pDays ??
      [
        for (var vDay = 0; vDay < 5; vDay++)
          DayAverage(day: DateTime(2026, 12, 10 + vDay), temp: 18.0 + vDay, humidity: 50),
      ],
);

String _text(Uint8List pBytes) => latin1.decode(pBytes);

void main() {
  group('fichier PDF', () {
    test('il commence et finit comme un PDF, avec le titre, la date et la pièce', () {
      final vText = _text(buildReportPdf([_report('Salon')], _now));

      expect(vText, startsWith('%PDF-1.4'));
      expect(vText.trimRight(), endsWith('%%EOF'));
      expect(vText, contains('(Bilan de la maison)'));
      expect(vText, contains('Établi le 14/12/2026'.replaceFirst('É', '\xC9')));
      expect(vText, contains('(Salon)'));
      expect(vText, contains('Maintenant : 20,5 \xB0C, humidit\xE9 52 %'));
    });

    test('les positions du tableau de références pointent sur les objets', () {
      final vText = _text(buildReportPdf([_report('Salon'), _report('Chambre')], _now));

      final vStart = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(vText)!.group(1)!);
      expect(vText.substring(vStart), startsWith('xref'));
      final vOffsets = RegExp(r'(\d{10}) 00000 n').allMatches(vText).map((m) => int.parse(m[1]!));
      expect(vOffsets, isNotEmpty);
      for (final (vIndex, vOffset) in vOffsets.indexed) {
        expect(vText.substring(vOffset), startsWith('${vIndex + 1} 0 obj'));
      }
    });

    test('la longueur déclarée du contenu est la longueur réelle', () {
      final vText = _text(buildReportPdf([_report('Salon')], _now));

      final vMatch = RegExp(r'/Length (\d+) >>\nstream\n').firstMatch(vText)!;
      final vLength = int.parse(vMatch.group(1)!);
      final vBegin = vMatch.end;
      expect(vText.substring(vBegin + vLength), startsWith('endstream'));
    });

    test('quatre pièces par page, une page de plus au-delà', () {
      expect(
        _text(buildReportPdf([for (var i = 0; i < 4; i++) _report('P$i')], _now)),
        contains('/Count 1'),
      );
      expect(
        _text(buildReportPdf([for (var i = 0; i < 5; i++) _report('P$i')], _now)),
        contains('/Count 2'),
      );
    });

    test('sans pièce, le PDF garde une page avec le titre', () {
      final vText = _text(buildReportPdf(const [], _now));

      expect(vText, contains('/Count 1'));
      expect(vText, contains('(Bilan de la maison)'));
    });

    test('une pièce sans relevé récent le dit, sans courbe', () {
      final vText = _text(buildReportPdf([_report('Cave', pDays: const [], pMin: null)], _now));

      expect(vText, contains('Pas de relev\xE9 sur les 14 derniers jours.'));
    });

    test(
      'parenthèses et antislash du nom sont protégés, les caractères hors Latin-1 remplacés',
      () {
        final vText = _text(buildReportPdf([_report(r'Salle (est) \ coin’s ☃')], _now));

        expect(
          vText,
          contains(
            r'(Salle \(est\) \\ coin'
            "'"
            r's ?)',
          ),
        );
      },
    );

    test('une seule journée de relevés ne fait pas de courbe mais ne plante pas', () {
      final vDays = [DayAverage(day: DateTime(2026, 12, 14), temp: 20, humidity: 50)];

      expect(() => buildReportPdf([_report('Salon', pDays: vDays)], _now), returnsNormally);
    });
  });

  group('bilans des pièces', () {
    Sensor sensor(String pName, List<(DateTime, double, double)> pValues) => Sensor(
      name: pName,
      readings: [
        for (final (vAt, vTemp, vHum) in pValues) Reading(at: vAt, temp: vTemp, humidity: vHum),
      ],
    );

    test(
      'les extrêmes regroupent les capteurs de la pièce et ignorent ce qui date de plus de 14 jours',
      () {
        final vSensors = [
          sensor('A', [
            (DateTime(2026, 11, 1), 5, 90),
            (DateTime(2026, 12, 10), 18, 45),
            (DateTime(2026, 12, 14, 8), 21, 50),
          ]),
          sensor('B', [(DateTime(2026, 12, 12), 23, 61)]),
          sensor('Dehors', [(DateTime(2026, 12, 14), -3, 80)]),
        ];
        const vHouse = House(
          places: {
            'A': SensorPlace(room: 'Salon', floor: 0),
            'B': SensorPlace(room: 'Salon', floor: 0),
            'Dehors': SensorPlace(outdoor: true),
          },
        );

        final vReports = buildRoomReports(vSensors, vHouse, _now);

        expect(vReports, hasLength(1));
        final vSalon = vReports.single;
        expect(vSalon.room, 'Salon');
        expect(vSalon.minTemp, 18);
        expect(vSalon.maxTemp, 23);
        expect(vSalon.minHumidity, 45);
        expect(vSalon.maxHumidity, 61);
        expect(vSalon.days, hasLength(3));
      },
    );

    test('une pièce dont les relevés sont trop anciens garde ses mesures sans extrêmes', () {
      final vSensors = [
        sensor('A', [(DateTime(2026, 11, 1), 15, 60)]),
      ];
      const vHouse = House(places: {'A': SensorPlace(room: 'Cave', floor: -1)});

      final vCave = buildRoomReports(vSensors, vHouse, _now).single;

      expect(vCave.temp, 15);
      expect(vCave.minTemp, isNull);
      expect(vCave.days, isEmpty);
    });
  });
}
