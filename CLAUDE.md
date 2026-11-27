# Home

Application Android en Flutter qui suit la température et l'humidité de la maison à partir de thermo-hygromètres. Suivre les conventions de Rémi (skills `conventions-remi` et `flutter-mobile-remi`). Toujours répondre en français.

- Règles dans `lib/logic/`, en Dart pur, sans Flutter, testées unitairement et couvertes à 95 % au moins (contrôlé par la CI).
- Aucun texte affiché en dur dans un widget : tout passe par `lib/l10n/app_fr.arb`.
- Données sur le téléphone uniquement, aucune permission réseau. Les capteurs sont rangés au format d'échange JSON décrit dans `docs/echange-climat.md`, le même que lit Atelier.
- Palette sombre unique (`lib/ui/theme.dart`) : ambre pour la température, bleu pour l'humidité.
- Android : `flutter create --platforms=android --org fr.remiverhaeghe --project-name home .` crée le dossier `android/`, qui n'est pas versionné tant qu'il n'a pas de réglage propre.
- Avant de valider : `flutter gen-l10n`, `dart format lib test`, `flutter analyze`, `flutter test`.
- `README.md`, `CHANGELOG.md` et `ROADMAP.md` à jour après chaque lot ; fichiers de moins de 1000 lignes.
