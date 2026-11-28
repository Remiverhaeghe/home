import 'dart:convert';

import 'comfort.dart';
import 'house_calendar.dart';
import 'plan.dart';

/// Version du fichier `pieces.json`.
const roomsVersion = 1;

/// Pièces du fichier. Une pièce illisible est ignorée, un fichier abîmé ou d'une autre version
/// donne une liste vide.
List<Room> parseRooms(String pJson) {
  final Object? vRoot;
  try {
    vRoot = jsonDecode(pJson);
  } on FormatException {
    return [];
  }
  if (vRoot is! Map<String, dynamic> || vRoot['version'] != roomsVersion) {
    return [];
  }
  final vList = vRoot['rooms'];
  if (vList is! List) {
    return [];
  }
  final rRooms = <Room>[];
  for (final vEntry in vList) {
    final vRoom = vEntry is Map<String, dynamic> ? _parseRoom(vEntry) : null;
    if (vRoom != null) {
      rRooms.add(vRoom);
    }
  }

  return rRooms;
}

Room? _parseRoom(Map<String, dynamic> pEntry) {
  final vHost = pEntry['acHost'];
  if (vHost is! String || vHost.isEmpty) {
    return null;
  }
  final vTargets = pEntry['targets'];
  const vDefault = RoomTargets();
  final vTargetsMap = vTargets is Map<String, dynamic> ? vTargets : const <String, dynamic>{};
  double target(String pKey, double pFallback) {
    final vValue = vTargetsMap[pKey];

    return vValue is num ? vValue.toDouble() : pFallback;
  }

  final vSlots = <ScheduleSlot>[];
  final vSchedule = pEntry['schedule'];
  if (vSchedule is List) {
    for (final vSlot in vSchedule) {
      final vParsed = vSlot is Map<String, dynamic> ? _parseSlot(vSlot) : null;
      if (vParsed != null) {
        vSlots.add(vParsed);
      }
    }
  }

  return Room(
    acHost: vHost,
    targets: RoomTargets(
      comfort: target('comfort', vDefault.comfort),
      night: target('night', vDefault.night),
      eco: target('eco', vDefault.eco),
      away: target('away', vDefault.away),
    ),
    schedule: vSlots,
  );
}

ScheduleSlot? _parseSlot(Map<String, dynamic> pEntry) {
  final vDays = pEntry['weekdays'];
  final vMinute = pEntry['minute'];
  final vProfile = ProfileKind.values.where((pKind) => pKind.name == pEntry['profile']);
  if (vDays is! List || vMinute is! int || vMinute < 0 || vMinute > 1439 || vProfile.isEmpty) {
    return null;
  }
  final vWeekdays = vDays
      .whereType<int>()
      .where((pDay) => pDay >= 1 && pDay <= remoteDayKey)
      .toSet();
  if (vWeekdays.isEmpty) {
    return null;
  }

  return ScheduleSlot(weekdays: vWeekdays, minute: vMinute, profile: vProfile.first);
}

/// Contenu du fichier `pieces.json`.
String roomsJson(List<Room> pRooms) => const JsonEncoder.withIndent('  ').convert({
  'version': roomsVersion,
  'rooms': [
    for (final vRoom in pRooms)
      {
        'acHost': vRoom.acHost,
        'targets': {
          'comfort': vRoom.targets.comfort,
          'night': vRoom.targets.night,
          'eco': vRoom.targets.eco,
          'away': vRoom.targets.away,
        },
        'schedule': [
          for (final vSlot in vRoom.schedule)
            {
              'weekdays': (vSlot.weekdays.toList()..sort()),
              'minute': vSlot.minute,
              'profile': vSlot.profile.name,
            },
        ],
      },
  ],
});
