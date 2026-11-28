import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/daikin.dart';

const _control = 'ret=OK,pow=1,mode=3,adv=,stemp=22.0,shum=0,dt1=25.0,f_rate=A,f_dir=0,alert=255';

void main() {
  group('réponse du module', () {
    test('les paires clé=valeur sont lues, valeur vide et signe égal compris', () {
      final vValues = parseDaikinReply('ret=OK,adv=,name=a=b');

      expect(vValues['adv'], '');
      expect(vValues['name'], 'a=b');
    });

    test('une réponse refusée ou illisible lève une exception avec le motif', () {
      expect(
        () => parseDaikinReply('ret=PARAM NG'),
        throwsA(isA<DaikinException>().having((pE) => pE.reason, 'motif', 'PARAM NG')),
      );
      expect(
        () => parseDaikinReply('n importe quoi'),
        throwsA(isA<DaikinException>().having((pE) => pE.reason, 'motif', 'réponse illisible')),
      );
    });
  });

  group('réglages', () {
    test('get_control_info est lu', () {
      final vControl = DaikinControl.parse(_control);

      expect(vControl.power, isTrue);
      expect(vControl.mode, DaikinMode.cool);
      expect(vControl.setpointDegrees, 22);
      expect(vControl.fanRate, 'A');
      expect(vControl.fanDirection, '0');
    });

    test('un réglage manquant est refusé', () {
      expect(() => DaikinControl.parse('ret=OK,pow=1,mode=3'), throwsA(isA<DaikinException>()));
      for (final vMissing in ['pow', 'mode', 'stemp', 'shum', 'f_rate', 'f_dir']) {
        final vReply = _control
            .split(',')
            .where((pPart) => !pPart.startsWith('$vMissing='))
            .join(',');

        expect(
          () => DaikinControl.parse(vReply),
          throwsA(isA<DaikinException>()),
          reason: vMissing,
        );
      }
    });

    test('les codes de mode sont reconnus, 0, 1 et 7 sont l\'automatique', () {
      expect(daikinModeOf('0'), DaikinMode.auto);
      expect(daikinModeOf('1'), DaikinMode.auto);
      expect(daikinModeOf('7'), DaikinMode.auto);
      expect(daikinModeOf('2'), DaikinMode.dry);
      expect(daikinModeOf('3'), DaikinMode.cool);
      expect(daikinModeOf('4'), DaikinMode.heat);
      expect(daikinModeOf('6'), DaikinMode.fan);
      expect(daikinModeOf('9'), isNull);
    });

    test('la requête d\'envoi contient les six paramètres, dans l\'ordre', () {
      expect(
        DaikinControl.parse(_control).toQuery(),
        'pow=1&mode=3&stemp=22.0&shum=0&f_rate=A&f_dir=0',
      );
      expect(
        DaikinControl.parse(_control).copyWith(power: false).toQuery(),
        'pow=0&mode=3&stemp=22.0&shum=0&f_rate=A&f_dir=0',
      );
    });

    test('passer en chaud change le code et garde la consigne', () {
      final vNew = DaikinControl.parse(_control).withMode(DaikinMode.heat)!;

      expect(vNew.modeCode, '4');
      expect(vNew.setpoint, '22.0');
    });

    test('passer en automatique envoie le code 0', () {
      expect(DaikinControl.parse(_control).withMode(DaikinMode.auto)!.modeCode, '0');
    });

    test('depuis le mode sec, la consigne par défaut est envoyée', () {
      final vDry = DaikinControl.parse(
        _control.replaceAll('mode=3', 'mode=2').replaceAll('stemp=22.0', 'stemp=M'),
      );

      final vNew = vDry.withMode(DaikinMode.cool)!;

      expect(vNew.setpoint, '22.0');
      expect(vNew.modeCode, '3');
    });

    test('sec et ventilation ne sont pas commandés', () {
      expect(DaikinControl.parse(_control).withMode(DaikinMode.dry), isNull);
      expect(DaikinControl.parse(_control).withMode(DaikinMode.fan), isNull);
    });

    test('la consigne est ramenée au demi-degré et à la plage acceptée', () {
      final vControl = DaikinControl.parse(_control);

      expect(vControl.withSetpoint(21.7)!.setpoint, '21.5');
      expect(vControl.withSetpoint(21.8)!.setpoint, '22.0');
      expect(vControl.withSetpoint(5)!.setpoint, '10.0');
      expect(vControl.withSetpoint(40)!.setpoint, '32.0');
    });

    test('sans consigne (sec), elle ne se change pas', () {
      final vDry = DaikinControl.parse(_control.replaceAll('stemp=22.0', 'stemp=M'));

      expect(vDry.setpointDegrees, isNull);
      expect(vDry.withSetpoint(21), isNull);
    });
  });

  group('mesures', () {
    test('températures et humidité sont lues', () {
      final vSensors = DaikinSensors.parse('ret=OK,htemp=23.5,hhum=45,otemp=8.0,err=0');

      expect(vSensors.indoorTemp, 23.5);
      expect(vSensors.indoorHumidity, 45);
      expect(vSensors.outdoorTemp, 8);
    });

    test('un tiret veut dire pas de mesure', () {
      final vSensors = DaikinSensors.parse('ret=OK,htemp=23.5,hhum=-,otemp=-');

      expect(vSensors.indoorHumidity, isNull);
      expect(vSensors.outdoorTemp, isNull);
      expect(vSensors.indoorTemp, 23.5);
    });
  });

  group('identité', () {
    test('le nom encodé comme une adresse web est décodé', () {
      final vInfo = DaikinInfo.parse('ret=OK,name=Salon%20bas,mac=AABBCCDDEEFF');

      expect(vInfo.name, 'Salon bas');
      expect(vInfo.mac, 'AABBCCDDEEFF');
    });

    test('un nom mal encodé est gardé tel quel', () {
      expect(DaikinInfo.parse('ret=OK,name=100%,mac=A').name, '100%');
    });

    test('sans nom, il est vide', () {
      expect(DaikinInfo.parse('ret=OK').name, '');
      expect(DaikinInfo.parse('ret=OK').mac, '');
    });
  });

  group('adresse du réseau de la maison', () {
    test('les trois plages privées sont acceptées', () {
      expect(isPrivateAddress('10.0.0.5'), isTrue);
      expect(isPrivateAddress('172.16.0.1'), isTrue);
      expect(isPrivateAddress('172.31.255.255'), isTrue);
      expect(isPrivateAddress('192.168.1.20'), isTrue);
      expect(isPrivateAddress(' 192.168.1.20 '), isTrue);
    });

    test('Internet, les noms et les adresses mal formées sont refusés', () {
      expect(isPrivateAddress('8.8.8.8'), isFalse);
      expect(isPrivateAddress('172.15.0.1'), isFalse);
      expect(isPrivateAddress('172.32.0.1'), isFalse);
      expect(isPrivateAddress('192.169.1.1'), isFalse);
      expect(isPrivateAddress('example.com'), isFalse);
      expect(isPrivateAddress('192.168.1'), isFalse);
      expect(isPrivateAddress('192.168.1.256'), isFalse);
      expect(isPrivateAddress('192.168.01.1'), isFalse);
      expect(isPrivateAddress('192.168.-1.1'), isFalse);
      expect(isPrivateAddress(''), isFalse);
    });
  });

  group('recherche sur le réseau', () {
    test('le balayage couvre le /24 sans l\'adresse du téléphone', () {
      final vHosts = subnetHosts('192.168.1.42');

      expect(vHosts, hasLength(253));
      expect(vHosts.first, '192.168.1.1');
      expect(vHosts.last, '192.168.1.254');
      expect(vHosts, isNot(contains('192.168.1.42')));
    });

    test('hors réseau privé, rien à balayer ni à diffuser', () {
      expect(subnetHosts('8.8.8.8'), isEmpty);
      expect(subnetHosts('pas une adresse'), isEmpty);
      expect(subnetBroadcast('8.8.8.8'), isNull);
    });

    test('la diffusion vise la dernière adresse du /24', () {
      expect(subnetBroadcast('192.168.1.42'), '192.168.1.255');
      expect(subnetBroadcast('10.0.5.7'), '10.0.5.255');
    });
  });
}
