import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/daikin.dart';

DaikinControl _control({bool pPower = false, String pMode = '3', String pSetpoint = '22.0'}) =>
    DaikinControl(
      power: pPower,
      modeCode: pMode,
      setpoint: pSetpoint,
      humidity: '0',
      fanRate: 'A',
      fanDirection: '0',
    );

const _slots = [
  ScheduleSlot(weekdays: {1, 2, 3, 4, 5}, minute: 390, profile: ProfileKind.comfort),
  ScheduleSlot(weekdays: {6, 7}, minute: 480, profile: ProfileKind.comfort),
  ScheduleSlot(weekdays: {1, 2, 3, 4, 5, 6, 7}, minute: 1320, profile: ProfileKind.night),
];

void main() {
  group('températures souhaitées', () {
    test('chaque profil a sa température, modifiable', () {
      const vTargets = RoomTargets(comfort: 22, night: 16, eco: 18.5, away: 14);

      expect(vTargets.of(ProfileKind.comfort), 22);
      expect(vTargets.of(ProfileKind.night), 16);
      expect(vTargets.of(ProfileKind.eco), 18.5);
      expect(vTargets.of(ProfileKind.away), 14);
      expect(const RoomTargets().of(ProfileKind.comfort), 21);
    });
  });

  group('planning', () {
    // 2026-12-07 est un lundi
    test('la plage la plus récente du jour s\'applique', () {
      expect(profileAt(_slots, DateTime(2026, 12, 7, 6, 30)), ProfileKind.comfort);
      expect(profileAt(_slots, DateTime(2026, 12, 7, 14)), ProfileKind.comfort);
      expect(profileAt(_slots, DateTime(2026, 12, 7, 22)), ProfileKind.night);
      expect(profileAt(_slots, DateTime(2026, 12, 7, 23, 59)), ProfileKind.night);
    });

    test('avant la première plage, celle de la veille continue', () {
      expect(profileAt(_slots, DateTime(2026, 12, 7, 6, 29)), ProfileKind.night);
      expect(profileAt(_slots, DateTime(2026, 12, 12, 7, 59)), ProfileKind.night);
    });

    test('le week-end suit ses propres heures', () {
      expect(profileAt(_slots, DateTime(2026, 12, 12, 8)), ProfileKind.comfort);
      expect(profileAt(_slots, DateTime(2026, 12, 13, 9)), ProfileKind.comfort);
    });

    test('la recherche passe sur le mois précédent', () {
      expect(profileAt(_slots, DateTime(2026, 12, 1, 3)), ProfileKind.night);
    });

    test('sans plage, ou sans plage dans la semaine, le profil de repli est rendu', () {
      const vOnlyMonday = [
        ScheduleSlot(weekdays: {1}, minute: 0, profile: ProfileKind.comfort),
      ];

      expect(profileAt(const [], DateTime(2026, 12, 7)), ProfileKind.eco);
      expect(
        profileAt(const [], DateTime(2026, 12, 7), pFallback: ProfileKind.away),
        ProfileKind.away,
      );
      expect(profileAt(vOnlyMonday, DateTime(2026, 12, 9)), ProfileKind.comfort);
      expect(
        profileAt(const [
          ScheduleSlot(weekdays: {}, minute: 0, profile: ProfileKind.night),
        ], DateTime(2026, 12, 9)),
        ProfileKind.eco,
      );
    });
  });

  group('réglage vers la température souhaitée', () {
    test('trop froid : la clim chauffe à la température souhaitée', () {
      final vTarget = comfortControl(pTarget: 21, pTemp: 19, pControl: _control())!;

      expect(vTarget.power, isTrue);
      expect(vTarget.mode, DaikinMode.heat);
      expect(vTarget.setpointDegrees, 21);
    });

    test('trop chaud : la clim refroidit', () {
      final vTarget = comfortControl(
        pTarget: 21,
        pTemp: 23,
        pControl: _control(pPower: true, pMode: '4'),
      )!;

      expect(vTarget.mode, DaikinMode.cool);
      expect(vTarget.setpointDegrees, 21);
    });

    test('dans la marge, une clim éteinte reste éteinte', () {
      expect(comfortControl(pTarget: 21, pTemp: 20.5, pControl: _control()), isNull);
      expect(comfortControl(pTarget: 21, pTemp: 21.5, pControl: _control()), isNull);
      expect(comfortControl(pTarget: 21, pTemp: 20.4, pControl: _control()), isNotNull);
      expect(comfortControl(pTarget: 21, pTemp: 21.6, pControl: _control()), isNotNull);
    });

    test('dehors chaud, pas de chauffage ; dehors froid, pas de froid', () {
      expect(comfortControl(pTarget: 21, pTemp: 19, pControl: _control(), pOutdoor: 20), isNull);
      expect(
        comfortControl(pTarget: 21, pTemp: 19, pControl: _control(), pOutdoor: 19.9),
        isNotNull,
      );
      expect(comfortControl(pTarget: 21, pTemp: 23, pControl: _control(), pOutdoor: 18), isNull);
      expect(
        comfortControl(pTarget: 21, pTemp: 23, pControl: _control(), pOutdoor: 18.1),
        isNotNull,
      );
    });

    test('la clim en chauffe s\'arrête une fois la température atteinte', () {
      final vHeating = _control(pPower: true, pMode: '4', pSetpoint: '21.0');

      expect(comfortControl(pTarget: 21, pTemp: 21, pControl: vHeating)!.power, isFalse);
      expect(comfortControl(pTarget: 21, pTemp: 20.8, pControl: vHeating), isNull);
    });

    test('la clim en froid s\'arrête une fois la température atteinte', () {
      final vCooling = _control(pPower: true, pSetpoint: '21.0');

      expect(comfortControl(pTarget: 21, pTemp: 21, pControl: vCooling)!.power, isFalse);
      expect(comfortControl(pTarget: 21, pTemp: 21.2, pControl: vCooling), isNull);
    });

    test('un autre mode allumé n\'est pas touché dans la marge', () {
      final vAuto = _control(pPower: true, pMode: '0');

      expect(comfortControl(pTarget: 21, pTemp: 21, pControl: vAuto), isNull);
    });

    test('déjà réglée comme voulu, la clim ne reçoit rien', () {
      final vHeating = _control(pPower: true, pMode: '4', pSetpoint: '21.0');

      expect(comfortControl(pTarget: 21, pTemp: 19, pControl: vHeating), isNull);
    });
  });
}
