# Home

Application Android qui suit la température et l'humidité de la maison à partir de thermo-hygromètres. Tout reste sur le téléphone : pas de compte, pas de serveur, rien sur Internet. Le seul accès réseau sert à parler aux climatisations Daikin sur le Wi-Fi de la maison.

Home sert de tableau de bord. Atelier, de son côté, s'en sert pour savoir quand une pièce est assez sèche pour poser un parquet ou une peinture : les deux applis échangent le même fichier JSON.

## Ce que fait Home

- Lecture en direct des thermo-hygromètres ThermoPro TP357 en Bluetooth : les mesures s'ajoutent aux relevés tant que l'écran « Capteurs à portée » est ouvert.
- Relevé en arrière-plan : un service Android relève les capteurs suivis toutes les 5 minutes, appli fermée, avec une notification discrète.
- Courbes par jour et extrêmes sur les quatorze derniers jours, en touchant la carte d'un capteur.
- Écran de diagnostic de l'historique du capteur, qui affiche les trames brutes pour vérifier leur décodage (voir [docs/tp357.md](docs/tp357.md)).
- Climatisations Daikin à module BRP069 : état, marche/arrêt, mode (auto, froid, chaud), consigne, et lien avec le capteur de la même pièce (voir [docs/daikin.md](docs/daikin.md)).
- Import d'un fichier d'échange JSON contenant plusieurs capteurs.
- Une carte par capteur : température, humidité, point de rosée, niveau de l'air (sec sous 40 %, humide au-delà de 60 %) et date du dernier relevé.
- Ré-importer un fichier ajoute les nouveaux relevés sans doubler les anciens.

La suite est dans [ROADMAP.md](ROADMAP.md).

## Lancer

Flutter et le SDK Android sont installés comme décrit dans le skill `flutter-mobile-remi`.

```
flutter create --platforms=android --org fr.remiverhaeghe --project-name home .
flutter pub get
flutter gen-l10n
flutter run
```

## Tester

```
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
```

La CI refuse une couverture de `lib/logic` sous 95 %.

## Organisation

| Dossier | Rôle |
|---|---|
| `lib/logic/` | Règles en Dart pur : fichier d'échange, fusion des relevés, point de rosée, trames du TP357 |
| `lib/background/` | Service Android de relevé des capteurs, et son point d'entrée |
| `lib/ble/` | Liaison Bluetooth avec les capteurs, remplacée par une fausse dans les tests |
| `lib/net/` | Liaison HTTP avec les climatisations, remplacée par une fausse dans les tests |
| `lib/state/` | Capteurs affichés et import |
| `lib/storage/` | Fichier `capteurs.json` sur le téléphone |
| `lib/ui/` | Thème sombre et écran des capteurs |
| `lib/l10n/` | Textes de l'appli |

## Documents

| Fichier | Contenu |
|---|---|
| [docs/echange-climat.md](docs/echange-climat.md) | Format du fichier d'échange avec Atelier |
| [docs/tp357.md](docs/tp357.md) | Ce que l'on sait du Bluetooth du TP357 et ce qui reste à vérifier |
| [docs/daikin.md](docs/daikin.md) | API locale des climatisations Daikin, limites et points à vérifier |
| [docs/decisions.md](docs/decisions.md) | Choix qui ne se devinent pas à la lecture du code |
| [CHANGELOG.md](CHANGELOG.md) | Historique des versions |

## Licence

[PolyForm Strict 1.0.0](LICENSE)
