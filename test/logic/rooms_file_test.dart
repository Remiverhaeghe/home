import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/comfort.dart';
import 'package:home/logic/plan.dart';
import 'package:home/logic/rooms_file.dart';

void main() {
  test('ce qui est écrit se relit à l\'identique', () {
    final vRooms = [
      const Room(
        acHost: '192.168.1.20',
        targets: RoomTargets(comfort: 20.5, night: 16, eco: 18, away: 14),
        schedule: [
          ScheduleSlot(weekdays: {1, 2, 3}, minute: 390, profile: ProfileKind.comfort),
          ScheduleSlot(weekdays: {7}, minute: 1320, profile: ProfileKind.night),
        ],
      ),
    ];

    final vBack = parseRooms(roomsJson(vRooms)).single;

    expect(vBack.acHost, '192.168.1.20');
    expect(vBack.targets.comfort, 20.5);
    expect(vBack.targets.away, 14);
    expect(vBack.schedule.first.weekdays, {1, 2, 3});
    expect(vBack.schedule.last.profile, ProfileKind.night);
    expect(vBack.schedule.last.minute, 1320);
  });

  test('un fichier abîmé, d\'une autre version ou mal formé donne aucune pièce', () {
    expect(parseRooms('pas du json'), isEmpty);
    expect(parseRooms('[]'), isEmpty);
    expect(parseRooms('{"version": 2, "rooms": []}'), isEmpty);
    expect(parseRooms('{"version": 1, "rooms": 3}'), isEmpty);
  });

  test('une pièce illisible est ignorée, les autres restent', () {
    const vJson = '''
{"version": 1, "rooms": [
  3,
  {"acHost": ""},
  {"acHost": "10.0.0.2"}
]}''';

    final vRooms = parseRooms(vJson);

    expect(vRooms.single.acHost, '10.0.0.2');
    expect(vRooms.single.targets.comfort, const RoomTargets().comfort);
    expect(vRooms.single.schedule, isEmpty);
  });

  test('une température absente ou fausse reprend la valeur par défaut', () {
    const vJson = '{"version": 1, "rooms": [{"acHost": "h", "targets": {"comfort": "chaud", "eco": 19}}]}';

    final vTargets = parseRooms(vJson).single.targets;

    expect(vTargets.comfort, const RoomTargets().comfort);
    expect(vTargets.eco, 19);
  });

  test('une plage mal formée est ignorée', () {
    const vJson = '''
{"version": 1, "rooms": [{"acHost": "h", "schedule": [
  4,
  {"weekdays": [1], "minute": 600, "profile": "inconnu"},
  {"weekdays": [1], "minute": 1440, "profile": "eco"},
  {"weekdays": [1], "minute": -1, "profile": "eco"},
  {"weekdays": "lundi", "minute": 600, "profile": "eco"},
  {"weekdays": [0, 8], "minute": 600, "profile": "eco"},
  {"weekdays": [1, 9], "minute": 600, "profile": "away"}
]}]}''';

    final vSlots = parseRooms(vJson).single.schedule;

    expect(vSlots, hasLength(1));
    expect(vSlots.single.weekdays, {1});
    expect(vSlots.single.profile, ProfileKind.away);
  });
}
