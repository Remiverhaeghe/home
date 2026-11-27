/// Trames du thermo-hygromètre ThermoPro TP357, lues en Bluetooth basse consommation. Le format
/// vient des outils libres écrits à partir du capteur (pasky/tp357, tpy357), pas d'une notice du
/// fabricant : il se vérifie sur le capteur avec l'écran de diagnostic.
library;

/// Caractéristique où le capteur envoie ses trames (abonnement aux notifications).
const tp357NotifyCharacteristic = '00010203-0405-0607-0809-0a0b0c0d2b10';

/// Caractéristique où l'on écrit les demandes d'historique.
const tp357WriteCharacteristic = '00010203-0405-0607-0809-0a0b0c0d2b11';

/// Premier octet d'une trame de mesure en direct.
const tp357LiveHeader = 0xC2;

/// Température et humidité d'une trame.
typedef TempHumidity = ({double temp, double humidity});

/// Le TP357S, plus récent, a un autre protocole d'historique : seule sa mesure en direct est lue.
bool isTp357Name(String pName) => pName.toUpperCase().startsWith('TP357');

bool hasTp357History(String pName) => isTp357Name(pName) && !pName.toUpperCase().contains('TP357S');

/// Mesure en direct : température aux octets 3 et 4 (entier signé, petit-boutiste, dixièmes de
/// degré), humidité à l'octet 5. Null pour toute autre trame.
TempHumidity? parseLiveFrame(List<int> pFrame) {
  if (pFrame.length < 6 || pFrame[0] != tp357LiveHeader) {
    return null;
  }
  final vRaw = pFrame[3] | (pFrame[4] << 8);
  final vSigned = vRaw >= 0x8000 ? vRaw - 0x10000 : vRaw;
  final vHumidity = pFrame[5];
  if (vHumidity > 100) {
    return null;
  }

  return (temp: vSigned / 10, humidity: vHumidity.toDouble());
}

/// Durée d'historique demandée au capteur.
enum HistoryPeriod { day, week, year }

/// Octet d'opération de chaque période, repris dans l'en-tête des trames de réponse.
int historyOpcode(HistoryPeriod pPeriod) => switch (pPeriod) {
  HistoryPeriod.day => 0xA7,
  HistoryPeriod.week => 0xA6,
  HistoryPeriod.year => 0xA8,
};

/// Octet de contrôle qui ferme la demande, propre à chaque période.
int _historyCheck(HistoryPeriod pPeriod) => switch (pPeriod) {
  HistoryPeriod.day => 0x7A,
  HistoryPeriod.week => 0x6A,
  HistoryPeriod.year => 0x8A,
};

/// Demande d'historique : opération, `01 00`, octet de contrôle.
List<int> historyRequest(HistoryPeriod pPeriod) => [
  historyOpcode(pPeriod),
  0x01,
  0x00,
  _historyCheck(pPeriod),
];

/// Relevés d'une trame d'historique : en-tête de 4 octets, puis des relevés de 3 octets
/// (température sur deux octets, humidité sur un). Un relevé vide (`FF FF`) vaut null. La date des
/// relevés n'est pas décodée : le capteur ne la donne pas clairement, c'est le lot suivant.
/// Renvoie null si la trame ne répond pas à la période demandée.
List<TempHumidity?>? parseHistoryFrame(List<int> pFrame, HistoryPeriod pPeriod) {
  if (pFrame.length < 4 || pFrame[0] != historyOpcode(pPeriod)) {
    return null;
  }
  final rRecords = <TempHumidity?>[];
  for (var vAt = 4; vAt + 3 <= pFrame.length; vAt += 3) {
    if (pFrame[vAt] == 0xFF && pFrame[vAt + 1] == 0xFF) {
      rRecords.add(null);
      continue;
    }
    final vRaw = pFrame[vAt] | (pFrame[vAt + 1] << 8);
    final vSigned = vRaw >= 0x8000 ? vRaw - 0x10000 : vRaw;
    rRecords.add((temp: vSigned / 10, humidity: pFrame[vAt + 2].toDouble()));
  }

  return rRecords;
}

/// Octets en hexadécimal, séparés par des espaces, pour l'écran de diagnostic.
String hexOf(List<int> pBytes) =>
    pBytes.map((pByte) => pByte.toRadixString(16).padLeft(2, '0')).join(' ');
