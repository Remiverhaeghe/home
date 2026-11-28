# Sécurité, permissions et réseau

Relevé de ce que l'appli demande et de ce qu'elle envoie, d'après le manifeste Android et le code de `lib/net/`.

## Permissions Android

| Permission | Pourquoi |
|---|---|
| `INTERNET` | Parler aux climatisations, au poêle et aux relais en HTTP sur le réseau de la maison, et lire la météo extérieure si elle est activée |
| `ACCESS_LOCAL_NETWORK` | Accès au réseau local demandé par les versions récentes d'Android |
| `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` (`BLUETOOTH`, `BLUETOOTH_ADMIN` jusqu'à Android 11) | Lire les thermo-hygromètres TP357 |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE` | Relevé des capteurs et plan de chauffe appli fermée, avec sa notification |
| `POST_NOTIFICATIONS` | Alertes (gel, humidité, capteur muet, poêle arrêté) et résumé du matin |

`ACCESS_NETWORK_STATE` est retirée explicitement. Aucune permission de localisation, de contacts, de micro, d'appareil photo ni de stockage large.

## Ce qui sort du téléphone

- Climatisations, poêle, relais : uniquement vers une adresse privée. `isPrivateAddress` refuse toute autre adresse à l'enregistrement et avant chaque requête (`lib/net/daikin_link.dart`). La recherche des clims par diffusion UDP ignore les réponses hors réseau privé.
- Météo extérieure : désactivée au départ. Activée, elle appelle le seul serveur Open-Meteo et ne lui envoie que les coordonnées de la maison (`lib/net/weather_link.dart`).
- Aucun compte, aucun serveur à soi, aucun traceur, aucun envoi automatique du journal d'erreurs.

## Secrets

- Le mot de passe du poêle et les identifiants des relais sont saisis dans l'appli et rangés dans les fichiers de données du téléphone. Ils ne sont jamais dans le dépôt.
- La sauvegarde exportée contient ces identifiants en clair. L'écran Sauvegarde le dit, le fichier est à garder en lieu sûr et à ne pas partager.
- Le journal d'erreurs ne reprend ni adresses, ni identifiants, ni relevés.

## Dépendances

Les dépendances directes sont celles de `pubspec.yaml`. Dependabot propose les mises à jour et la CI contrôle les secrets du dépôt.
