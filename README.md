# Home

Application Android qui suit la température et l'humidité de la maison à partir de thermo-hygromètres. Tout reste sur le téléphone : pas de compte, pas de réseau, pas de serveur.

Home sert de tableau de bord. Atelier, de son côté, s'en sert pour savoir quand une pièce est assez sèche pour poser un parquet ou une peinture : les deux applis échangent le même fichier JSON.

## Ce que fait le premier lot

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
| `lib/logic/` | Règles en Dart pur : lecture du fichier d'échange, fusion des relevés, point de rosée |
| `lib/state/` | Capteurs affichés et import |
| `lib/storage/` | Fichier `capteurs.json` sur le téléphone |
| `lib/ui/` | Thème sombre et écran des capteurs |
| `lib/l10n/` | Textes de l'appli |

## Documents

| Fichier | Contenu |
|---|---|
| [docs/echange-climat.md](docs/echange-climat.md) | Format du fichier d'échange avec Atelier |
| [docs/decisions.md](docs/decisions.md) | Choix qui ne se devinent pas à la lecture du code |
| [CHANGELOG.md](CHANGELOG.md) | Historique des versions |

## Licence

[PolyForm Strict 1.0.0](LICENSE)
