# Architecture

Home est une appli Flutter pour Android. Les règles sont en Dart pur, l'état et les fichiers sont séparés de l'affichage, et tout ce qui touche le réseau ou le Bluetooth passe par une interface que les tests remplacent par une fausse.

## Couches

| Dossier | Rôle | Dépend de |
|---|---|---|
| `lib/logic/` | Règles pures, sans Flutter : décodage des trames TP357, confort et moisissure, plan de chauffe, alertes, heures de marche, sauvegarde, format d'échange | rien d'autre que Dart |
| `lib/state/` | Un contrôleur par domaine (capteurs, clims, plan, poêle, relais, météo, maison, notes, apparence), `ChangeNotifier` | `logic`, `storage`, `net` |
| `lib/storage/` | Une paire par fichier de données : version en mémoire pour les tests, version fichier qui écrit un `.tmp` puis le renomme | `logic` |
| `lib/net/` | Climatisations, poêle, relais, météo : HTTP sur réseau privé, une classe de lien par appareil | `logic` |
| `lib/ble/` | Lien Bluetooth du TP357, derrière une interface | `logic` |
| `lib/background/` | Service de premier plan : relevé des capteurs, plan de chauffe, poêle, alertes | `logic`, `storage`, `net`, `ble` |
| `lib/ui/` | Écrans et sections, sans règle métier | `state`, `logic` |
| `lib/l10n/` | Tous les textes (`app_fr.arb`), aucun texte en dur dans un widget | |

## Données

Tout reste sur le téléphone, dans des fichiers JSON du dossier de l'appli. Les capteurs sont rangés dans le format d'échange lu aussi par Atelier (`docs/echange-climat.md`). La liste des fichiers qui entrent dans la sauvegarde est `backupFileNames` dans `lib/logic/backup.dart`.

Deux processus Dart écrivent : l'appli et le service d'arrière-plan. Ils ne se partagent pas la mémoire. Le service ajoute des lignes à `releves_en_attente.jsonl` que l'appli reprend, et les fichiers de données s'écrivent de façon atomique (un `.tmp` renommé).

## Tests

- `test/logic/` : règles, sans Flutter, couverture de 95 % au moins sur `lib/logic/` contrôlée par la CI.
- `test/state/` et `test/storage/` : contrôleurs avec les fausses liaisons et les fichiers dans un dossier temporaire.
- `test/ui/` : écrans avec les contrôleurs en mémoire.
- `test/captures/` : écrans sur une maison fictive, d'où viennent les captures du README (workflow `captures.yml`).

## Pour ajouter un appareil ou une règle

1. La règle ou le décodage va dans `lib/logic/`, avec ses tests.
2. Le lien réseau ou Bluetooth va dans `lib/net/` ou `lib/ble/`, derrière une interface, avec une fausse dans `test/support/`.
3. Le fichier de données reçoit sa paire de stockage, et son nom entre dans `backupFileNames` s'il doit être sauvegardé.
4. Les textes vont dans `lib/l10n/app_fr.arb`.
