import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/daikin.dart';
import 'package:home/logic/vacation.dart';

final _vacation = VacationMode(from: DateTime(2026, 12, 18), until: DateTime(2026, 12, 28));

DaikinControl _control({bool pPower = false, String pMode = '4', String pSetpoint = '20.0'}) =>
    DaikinControl(
      power: pPower,
      modeCode: pMode,
      setpoint: pSetpoint,
      humidity: '0',
      fanRate: 'A',
      fanDirection: '0',
    );

void main() {
  group('période', () {
    test('le début est compris, la fin est exclue', () {
      expect(_vacation.isActiveAt(DateTime(2026, 12, 17, 23, 59)), isFalse);
      expect(_vacation.isActiveAt(DateTime(2026, 12, 18)), isTrue);
      expect(_vacation.isActiveAt(DateTime(2026, 12, 27, 23, 59)), isTrue);
      expect(_vacation.isActiveAt(DateTime(2026, 12, 28)), isFalse);
    });

    test('la remontée commence un jour avant le retour, et seulement pendant l\'absence', () {
      expect(_vacation.isPreheatingAt(DateTime(2026, 12, 26, 23, 59)), isFalse);
      expect(_vacation.isPreheatingAt(DateTime(2026, 12, 27)), isTrue);
      expect(_vacation.isPreheatingAt(DateTime(2026, 12, 27, 23, 59)), isTrue);
      expect(_vacation.isPreheatingAt(DateTime(2026, 12, 28)), isFalse);
    });

    test('un délai nul supprime la remontée', () {
      final vVacation = VacationMode(
        from: DateTime(2026, 12, 18),
        until: DateTime(2026, 12, 28),
        preheat: Duration.zero,
      );

      expect(vVacation.isPreheatingAt(DateTime(2026, 12, 27, 23, 59)), isFalse);
    });
  });

  group('hors gel', () {
    test('sous le seuil, la clim chauffe à la consigne hors gel', () {
      final vTarget = frostControl(_vacation, 7, _control())!;

      expect(vTarget.power, isTrue);
      expect(vTarget.mode, DaikinMode.heat);
      expect(vTarget.setpointDegrees, defaultFrostSetpoint);
    });

    test('entre le seuil et la consigne, rien ne change (hystérésis)', () {
      expect(frostControl(_vacation, 8, _control(pPower: true)), isNull);
      expect(frostControl(_vacation, 11.9, _control(pPower: true)), isNull);
      expect(frostControl(_vacation, 10, _control()), isNull);
    });

    test('la consigne atteinte, la clim allumée est coupée', () {
      expect(frostControl(_vacation, 12, _control(pPower: true))!.power, isFalse);
    });

    test('une clim déjà éteinte, ou déjà en chauffe hors gel, ne reçoit rien', () {
      final vHeating = _control(pPower: true, pSetpoint: '12.0');

      expect(frostControl(_vacation, 15, _control()), isNull);
      expect(frostControl(_vacation, 7, vHeating), isNull);
    });

    test('des seuils personnalisés sont suivis', () {
      final vVacation = VacationMode(
        from: DateTime(2026, 12, 18),
        until: DateTime(2026, 12, 28),
        frostTemp: 5,
        frostSetpoint: 10,
      );

      expect(frostControl(vVacation, 6, _control()), isNull);
      expect(frostControl(vVacation, 4, _control())!.setpointDegrees, 10);
    });
  });

  group('fichier', () {
    test('écriture puis lecture redonnent le mode vacances', () {
      final vBack = parseVacation(
        vacationJson(
          VacationMode(
            from: DateTime(2026, 12, 18),
            until: DateTime(2026, 12, 28, 18),
            frostTemp: 6,
            frostSetpoint: 11,
            preheat: const Duration(hours: 12),
          ),
        ),
      )!;

      expect(vBack.from, DateTime(2026, 12, 18));
      expect(vBack.until, DateTime(2026, 12, 28, 18));
      expect(vBack.frostTemp, 6);
      expect(vBack.frostSetpoint, 11);
      expect(vBack.preheat, const Duration(hours: 12));
    });

    test('les valeurs absentes ou fausses prennent les valeurs par défaut', () {
      final vBack = parseVacation(
        '{"version": 1, "from": "2026-12-18T00:00:00", "until": "2026-12-28T00:00:00", '
        '"preheatHours": -3}',
      )!;

      expect(vBack.frostTemp, defaultFrostTemp);
      expect(vBack.frostSetpoint, defaultFrostSetpoint);
      expect(vBack.preheat, defaultPreheat);
    });

    test('un fichier illisible, d\'une autre version ou incohérent donne null', () {
      const vDates = '"from": "2026-12-18T00:00:00", "until": "2026-12-28T00:00:00"';

      expect(parseVacation('pas du json'), isNull);
      expect(parseVacation('[]'), isNull);
      expect(parseVacation('{"version": 2, $vDates}'), isNull);
      expect(parseVacation('{"version": 1}'), isNull);
      expect(
        parseVacation(
          '{"version": 1, "from": "2026-12-28T00:00:00", "until": "2026-12-18T00:00:00"}',
        ),
        isNull,
      );
      expect(
        parseVacation('{"version": 1, $vDates, "frostTemp": 12, "frostSetpoint": 12}'),
        isNull,
      );
    });
  });
}
