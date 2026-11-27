import 'package:flutter/foundation.dart';

import '../logic/house.dart';
import '../storage/house_store.dart';

/// Ce qui empêche d'enregistrer le lieu.
enum LocationProblem { emptyLabel, badCoordinates }

/// Lieu de la maison et emplacement des capteurs.
class HouseController extends ChangeNotifier {
  HouseController(this._store);

  final HouseStore _store;
  var _house = const House();

  House get house => _house;

  Future<void> load() async {
    _house = await _store.load();
    notifyListeners();
  }

  /// Enregistre le lieu. Renvoie le motif du refus, null si c'est fait.
  Future<LocationProblem?> setLocation(String pLabel, double? pLatitude, double? pLongitude) async {
    if (pLabel.trim().isEmpty) {
      return LocationProblem.emptyLabel;
    }
    if (pLatitude == null || pLongitude == null || !isValidCoordinates(pLatitude, pLongitude)) {
      return LocationProblem.badCoordinates;
    }
    _house = _house.withLocation(
      HouseLocation(label: pLabel.trim(), latitude: pLatitude, longitude: pLongitude),
    );
    await _store.save(_house);
    notifyListeners();

    return null;
  }

  Future<void> clearLocation() async {
    _house = _house.withLocation(null);
    await _store.save(_house);
    notifyListeners();
  }

  Future<void> setPlace(String pSensorName, SensorPlace pPlace) async {
    _house = _house.withPlace(pSensorName, pPlace);
    await _store.save(_house);
    notifyListeners();
  }
}
