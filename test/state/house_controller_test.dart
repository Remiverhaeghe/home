import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/house.dart';
import 'package:home/state/house_controller.dart';
import 'package:home/storage/house_store.dart';

void main() {
  late MemoryHouseStore vStore;
  late HouseController vController;

  setUp(() {
    vStore = MemoryHouseStore();
    vController = HouseController(vStore);
  });

  test('le lieu valide est rangé', () async {
    expect(await vController.setLocation(' Lyon ', 45.76, 4.83), isNull);

    expect(vStore.saved.location?.label, 'Lyon');
    expect(vController.house.location?.longitude, 4.83);
  });

  test('un nom vide ou des coordonnées fausses sont refusés', () async {
    expect(await vController.setLocation(' ', 45, 4), LocationProblem.emptyLabel);
    expect(await vController.setLocation('X', null, 4), LocationProblem.badCoordinates);
    expect(await vController.setLocation('X', 45, 400), LocationProblem.badCoordinates);
    expect(vStore.saved.location, isNull);
  });

  test('le lieu s\'efface', () async {
    await vController.setLocation('Lyon', 45, 4);
    await vController.clearLocation();

    expect(vStore.saved.location, isNull);
  });

  test('l\'emplacement d\'un capteur est rangé puis relu', () async {
    await vController.setPlace('A', const SensorPlace(room: 'Cave', floor: -1));
    final vAgain = HouseController(vStore);
    await vAgain.load();

    expect(vAgain.house.placeOf('A').room, 'Cave');
  });
}
