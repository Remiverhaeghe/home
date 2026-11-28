/// Journal détaillé : ce que fait l'appli, ligne par ligne, quand on l'a activé. Sans nom de pièce
/// ni adresse : les capteurs n'y sont désignés que par leur rang.
library;

import 'error_log.dart';

/// Nombre de lignes gardées dans le journal détaillé.
const maxDetailLines = 600;

/// Une ligne : date et heure à la seconde, sujet, message nettoyé.
String detailEntry(DateTime pAt, String pTopic, String pMessage) {
  String two(int pValue) => pValue.toString().padLeft(2, '0');
  final vDate =
      '${pAt.year}-${two(pAt.month)}-${two(pAt.day)} '
      '${two(pAt.hour)}:${two(pAt.minute)}:${two(pAt.second)}';

  return '$vDate [$pTopic] ${cleanErrorMessage(pMessage)}';
}
