import 'dart:async';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/error_log.dart';

void main() {
  test('la version affichée est celle de pubspec.yaml', () {
    final vLine = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));

    expect(vLine.split(RegExp(r'[:+]'))[1].trim(), appVersion);
  });

  test('les adresses réseau sont masquées et le message tient sur une ligne', () {
    expect(cleanErrorMessage('connexion à 192.168.1.30\nrefusée'), 'connexion à *** refusée');
  });

  test('un long message est coupé', () {
    final vClean = cleanErrorMessage('x' * 500);

    expect(vClean.length, maxMessageLength + 1);
    expect(vClean.endsWith('…'), isTrue);
  });

  test('seules les lignes de la pile venant de l\'appli sont gardées, dans la limite', () {
    final vStack = StackTrace.fromString(
      [
        '#0 a (dart:core/x.dart:1)',
        for (var i = 0; i < 6; i++) '#${i + 1} f$i (package:home/logic/a.dart:$i)',
        '#9 b (package:flutter/y.dart:2)',
      ].join('\n'),
    );

    expect(appFrames(vStack), hasLength(4));
    expect(appFrames(vStack).every((l) => l.contains('package:home/')), isTrue);
    expect(appFrames(null), isEmpty);
  });

  test('une entrée porte la date, le type, le message et la pile', () {
    final vEntry = errorEntry(
      DateTime(2026, 12, 7, 9, 5),
      StateError('panne 10.0.0.1'),
      StackTrace.fromString('#0 f (package:home/logic/a.dart:3)'),
    );

    expect(vEntry.split('\n').first, '2026-12-07 09:05 StateError Bad state: panne ***');
    expect(vEntry, contains('    #0 f (package:home/logic/a.dart:3)'));
  });

  test('le journal ne garde que les dernières lignes', () {
    final vLog = [for (var i = 0; i < 10; i++) 'l$i'].join('\n');

    expect(trimLog(vLog, pMax: 3), 'l7\nl8\nl9');
    expect(trimLog('a\nb', pMax: 3), 'a\nb');
  });

  group('tours manqués en arrière-plan', () {
    test('l\'entrée désigne le capteur par son rang, sans son nom', () {
      final vEntry = backgroundMissEntry(
        DateTime(2026, 12, 7, 9, 5),
        2,
        3,
        TimeoutException('pas de mesure'),
      );

      expect(
        vEntry,
        '2026-12-07 09:05 Relevé en arrière-plan : capteur 2 sans mesure depuis 3 tours '
        '(TimeoutException)',
      );
    });

    test('on écrit au troisième tour manqué, puis une fois par heure', () {
      final vLogged = [
        for (var vMisses = 1; vMisses <= 40; vMisses++)
          if (shouldLogMiss(vMisses)) vMisses,
      ];

      expect(vLogged, [3, 12, 24, 36]);
    });
  });
}
