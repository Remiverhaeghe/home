/// Journal local des erreurs de l'appli : une ligne par erreur, sans donnée de la maison.
library;

/// Version de l'appli affichée dans « À propos » ; la même que celle de `pubspec.yaml`.
const appVersion = '0.1.0';

/// Nombre de lignes gardées dans le journal.
const maxLogLines = 300;

/// Longueur maximale du message d'une erreur dans le journal.
const maxMessageLength = 200;

final _ipv4 = RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}\b');

/// Message nettoyé pour le journal : adresses réseau masquées, une seule ligne, longueur limitée.
/// Les adresses et les noms de la maison n'ont rien à faire dans un fichier que l'on peut partager.
String cleanErrorMessage(String pMessage) {
  final vOneLine = pMessage.replaceAll(_ipv4, '***').replaceAll(RegExp(r'\s+'), ' ').trim();

  return vOneLine.length <= maxMessageLength
      ? vOneLine
      : '${vOneLine.substring(0, maxMessageLength)}…';
}

/// Les premières lignes de la pile qui viennent de l'appli elle-même (`package:home/`).
List<String> appFrames(StackTrace? pStack, {int pMax = 4}) => [
  for (final vLine in (pStack?.toString() ?? '').split('\n'))
    if (vLine.contains('package:home/')) vLine.trim(),
].take(pMax).toList();

/// Une entrée du journal : date, type d'erreur, message nettoyé, puis les lignes de la pile.
String errorEntry(DateTime pAt, Object pError, StackTrace? pStack) {
  final vDate =
      '${pAt.year}-${pAt.month.toString().padLeft(2, '0')}-${pAt.day.toString().padLeft(2, '0')} '
      '${pAt.hour.toString().padLeft(2, '0')}:${pAt.minute.toString().padLeft(2, '0')}';
  final vLines = [
    '$vDate ${pError.runtimeType} ${cleanErrorMessage('$pError')}',
    for (final vFrame in appFrames(pStack)) '    $vFrame',
  ];

  return vLines.join('\n');
}

/// Entrée du journal pour un capteur suivi qui ne donne plus de mesure en arrière-plan. Le capteur
/// n'est désigné que par son rang : son nom reste dans la maison, pas dans un fichier partageable.
String backgroundMissEntry(DateTime pAt, int pRank, int pMisses, Object pError) {
  final vDate =
      '${pAt.year}-${pAt.month.toString().padLeft(2, '0')}-${pAt.day.toString().padLeft(2, '0')} '
      '${pAt.hour.toString().padLeft(2, '0')}:${pAt.minute.toString().padLeft(2, '0')}';

  return '$vDate Relevé en arrière-plan : capteur $pRank sans mesure depuis $pMisses tours '
      '(${pError.runtimeType})';
}

/// Faut-il écrire au journal à ce nombre de tours manqués d'affilée ? Au troisième, puis une fois
/// par heure (12 tours de 5 minutes) : assez pour comprendre, sans noyer les vraies erreurs.
bool shouldLogMiss(int pMisses) => pMisses == 3 || (pMisses > 3 && pMisses % 12 == 0);

/// Ne garde que les [maxLogLines] dernières lignes.
String trimLog(String pLog, {int pMax = maxLogLines}) {
  final vLines = pLog.split('\n');
  if (vLines.length <= pMax) {
    return pLog;
  }

  return vLines.sublist(vLines.length - pMax).join('\n');
}
