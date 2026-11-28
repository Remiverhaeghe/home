/// Bilan des pièces en PDF : un petit écrivain de PDF sans dépendance (texte, traits, courbes) et
/// la mise en page du bilan. Une page A4 porte quatre pièces, avec la courbe de température des
/// quatorze derniers jours.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'climate_stats.dart';
import 'house.dart';
import 'reading.dart';
import 'rooms.dart';

/// Nombre de jours montrés sur la courbe et dans les extrêmes.
const reportDays = 14;

/// Une pièce du bilan : mesures du moment, extrêmes sur [reportDays] jours et moyenne par jour.
class RoomReport {
  const RoomReport({
    required this.room,
    required this.floor,
    required this.temp,
    required this.humidity,
    required this.minTemp,
    required this.maxTemp,
    required this.minHumidity,
    required this.maxHumidity,
    required this.days,
  });

  final String room;
  final int? floor;
  final double temp;
  final double humidity;
  final double? minTemp;
  final double? maxTemp;
  final double? minHumidity;
  final double? maxHumidity;
  final List<DayAverage> days;
}

/// Bilans des pièces rangées, de la plus froide à la plus chaude. Les extrêmes et la courbe
/// regroupent les relevés de tous les capteurs de la pièce.
List<RoomReport> buildRoomReports(List<Sensor> pSensors, House pHouse, DateTime pNow) {
  final vFrom = DateTime(pNow.year, pNow.month, pNow.day - (reportDays - 1));
  final rReports = <RoomReport>[];
  for (final vRoom in roomStatuses(pSensors, pHouse)) {
    final vReadings = [
      for (final vSensor in pSensors)
        if (vRoom.sensors.contains(vSensor.name))
          for (final vReading in vSensor.readings)
            if (!vReading.at.isBefore(vFrom)) vReading,
    ];
    double? vMin(Iterable<double> pValues) =>
        pValues.isEmpty ? null : pValues.reduce((pA, pB) => pA < pB ? pA : pB);
    double? vMax(Iterable<double> pValues) =>
        pValues.isEmpty ? null : pValues.reduce((pA, pB) => pA > pB ? pA : pB);
    rReports.add(
      RoomReport(
        room: vRoom.room,
        floor: vRoom.floor,
        temp: vRoom.temp,
        humidity: vRoom.humidity,
        minTemp: vMin(vReadings.map((pR) => pR.temp)),
        maxTemp: vMax(vReadings.map((pR) => pR.temp)),
        minHumidity: vMin(vReadings.map((pR) => pR.humidity)),
        maxHumidity: vMax(vReadings.map((pR) => pR.humidity)),
        days: dailyAverages(vReadings),
      ),
    );
  }

  return rReports;
}

const _pageWidth = 595.0;
const _pageHeight = 842.0;
const _margin = 50.0;
const _blockHeight = 170.0;
const _roomsPerPage = 4;

String _number(double pValue) => pValue.toStringAsFixed(1).replaceAll('.', ',');

/// Caractères hors du jeu Latin-1 de la police standard, ramenés à un équivalent simple.
String _latin1Safe(String pText) {
  const vMap = {'’': "'", '‘': "'", '–': '-', '—': '-', '…': '...', '«': '"', '»': '"'};
  final vBuffer = StringBuffer();
  for (final vRune in pText.runes) {
    final vChar = String.fromCharCode(vRune);
    vBuffer.write(vRune < 256 ? vChar : (vMap[vChar] ?? '?'));
  }

  return vBuffer.toString();
}

String _escape(String pText) =>
    _latin1Safe(pText).replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

/// Contenu d'une page : opérateurs PDF accumulés.
class _PageContent {
  final _ops = StringBuffer();

  /// Texte à la position [pX], [pY] (origine en bas à gauche), en police normale ou grasse.
  void text(String pText, double pX, double pY, {double pSize = 10, bool pBold = false}) {
    _ops.writeln(
      'BT /${pBold ? 'F2' : 'F1'} $pSize Tf ${_f(pX)} ${_f(pY)} Td (${_escape(pText)}) Tj ET',
    );
  }

  void rect(double pX, double pY, double pW, double pH) =>
      _ops.writeln('0.75 G ${_f(pX)} ${_f(pY)} ${_f(pW)} ${_f(pH)} re S');

  void polyline(List<(double, double)> pPoints) {
    if (pPoints.length < 2) {
      return;
    }
    _ops.writeln('0.85 0.45 0.05 RG 1.5 w ${_f(pPoints.first.$1)} ${_f(pPoints.first.$2)} m');
    for (final (vX, vY) in pPoints.skip(1)) {
      _ops.writeln('${_f(vX)} ${_f(vY)} l');
    }
    _ops.writeln('S 0 G 1 w');
  }

  String get operators => _ops.toString();
}

String _f(double pValue) => pValue.toStringAsFixed(2);

void _drawRoom(_PageContent pPage, RoomReport pRoom, double pTop) {
  final vWidth = _pageWidth - 2 * _margin;
  pPage.text(pRoom.room, _margin, pTop - 14, pSize: 13, pBold: true);
  pPage.text(
    'Maintenant : ${_number(pRoom.temp)} °C, humidité ${pRoom.humidity.round()} %',
    _margin,
    pTop - 30,
  );
  final vMin = pRoom.minTemp;
  final vMax = pRoom.maxTemp;
  if (vMin == null || vMax == null) {
    pPage.text('Pas de relevé sur les $reportDays derniers jours.', _margin, pTop - 46);

    return;
  }
  pPage.text(
    '$reportDays derniers jours : de ${_number(vMin)} à ${_number(vMax)} °C, '
    'humidité de ${pRoom.minHumidity!.round()} à ${pRoom.maxHumidity!.round()} %',
    _margin,
    pTop - 46,
  );
  final vBoxTop = pTop - 56;
  const vBoxHeight = 90.0;
  final vBoxBottom = vBoxTop - vBoxHeight;
  pPage.rect(_margin, vBoxBottom, vWidth, vBoxHeight);
  final vDays = pRoom.days.length > reportDays
      ? pRoom.days.sublist(pRoom.days.length - reportDays)
      : pRoom.days;
  final vLow = vDays.map((pD) => pD.temp).reduce((pA, pB) => pA < pB ? pA : pB);
  final vHigh = vDays.map((pD) => pD.temp).reduce((pA, pB) => pA > pB ? pA : pB);
  final vSpan = vHigh - vLow < 1 ? 1.0 : vHigh - vLow;
  final vStepX = vDays.length > 1 ? (vWidth - 20) / (vDays.length - 1) : 0.0;
  pPage.polyline([
    for (final (vIndex, vDay) in vDays.indexed)
      (
        _margin + 10 + vIndex * vStepX,
        vBoxBottom + 8 + (vDay.temp - vLow) / vSpan * (vBoxHeight - 16),
      ),
  ]);
  pPage.text('${_number(vHigh)} °C', _margin + 4, vBoxTop - 10, pSize: 7);
  pPage.text('${_number(vLow)} °C', _margin + 4, vBoxBottom + 3, pSize: 7);
  pPage.text('Température moyenne par jour', _margin + vWidth - 130, vBoxBottom - 10, pSize: 7);
}

/// PDF du bilan : titre et date sur la première page, quatre pièces par page.
Uint8List buildReportPdf(List<RoomReport> pRooms, DateTime pNow) {
  final vPages = <_PageContent>[];
  for (var vStart = 0; vStart == 0 || vStart < pRooms.length; vStart += _roomsPerPage) {
    final vPage = _PageContent();
    var vTop = _pageHeight - _margin;
    if (vStart == 0) {
      vPage.text('Bilan de la maison', _margin, vTop - 18, pSize: 20, pBold: true);
      final vDate =
          '${pNow.day.toString().padLeft(2, '0')}/${pNow.month.toString().padLeft(2, '0')}/'
          '${pNow.year}';
      vPage.text('Établi le $vDate', _margin, vTop - 36);
      vTop -= 60;
    }
    for (final vRoom in pRooms.skip(vStart).take(_roomsPerPage)) {
      _drawRoom(vPage, vRoom, vTop);
      vTop -= _blockHeight;
    }
    vPages.add(vPage);
  }

  // Objets : 1 catalogue, 2 pages, 3 et 4 polices, puis (page, contenu) pour chaque page
  final vObjects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [${[for (var vI = 0; vI < vPages.length; vI++) '${5 + vI * 2} 0 R'].join(' ')}] /Count ${vPages.length} >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>',
  ];
  for (final (vIndex, vPage) in vPages.indexed) {
    final vContentNumber = 6 + vIndex * 2;
    final vLength = latin1.encode(vPage.operators).length;
    vObjects
      ..add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $_pageWidth $_pageHeight] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents $vContentNumber 0 R >>',
      )
      ..add('<< /Length $vLength >>\nstream\n${vPage.operators}endstream');
  }

  final vOut = BytesBuilder();
  final vOffsets = <int>[];
  void vWrite(String pText) => vOut.add(latin1.encode(pText));
  vWrite('%PDF-1.4\n');
  for (final (vIndex, vBody) in vObjects.indexed) {
    vOffsets.add(vOut.length);
    vWrite('${vIndex + 1} 0 obj\n$vBody\nendobj\n');
  }
  final vXref = vOut.length;
  vWrite('xref\n0 ${vObjects.length + 1}\n0000000000 65535 f \n');
  for (final vOffset in vOffsets) {
    vWrite('${vOffset.toString().padLeft(10, '0')} 00000 n \n');
  }
  vWrite(
    'trailer\n<< /Size ${vObjects.length + 1} /Root 1 0 R >>\nstartxref\n$vXref\n%%EOF\n',
  );

  return vOut.toBytes();
}
