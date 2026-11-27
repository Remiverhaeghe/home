# Climatisations Daikin

Home parle aux climatisations par le Wi-Fi de la maison, sans passer par Internet ni par le compte Daikin Onecta. Le format vient d'outils libres écrits à partir des modules BRP069 (daimik/Daikin-BRP069C4x-Local-API), pas d'une notice du fabricant. Il se vérifie sur l'appareil.

## Modules pris en charge

Les modules qui répondent en HTTP simple sur le port 80, sans clé : BRP069 et les BRP072 sans clé. Les modules BRP072C à clé (HTTPS et jeton client dans l'en-tête `X-Daikin-uuid`) ne sont pas pris en charge : leur enregistrement n'a pas été vérifié, voir la feuille de route.

Les micrologiciels 2.8.0 et plus remplacent cette API par une API JSON (`/dsiot/multireq`) et peuvent retirer l'ancienne. Ne pas mettre à jour le module tant que Home sert de commande.

## Requêtes

Réponses en paires `clé=valeur` séparées par des virgules, qui commencent par `ret=OK`.

| Requête | Usage |
|---|---|
| `GET /common/basic_info` | nom du module (encodé comme une adresse web) et adresse MAC |
| `GET /aircon/get_control_info` | marche (`pow`), mode (`mode`), consigne (`stemp`), humidité visée (`shum`), ventilation (`f_rate`, `f_dir`) |
| `GET /aircon/get_sensor_info` | température intérieure (`htemp`), extérieure (`otemp`), humidité intérieure (`hhum`, `-` sans capteur) |
| `GET /aircon/set_control_info?pow=…&mode=…&stemp=…&shum=…&f_rate=…&f_dir=…` | commande : les six paramètres sont obligatoires, même inchangés |

Modes : 0, 1 et 7 automatique, 2 sec, 3 froid, 4 chaud, 6 ventilation. Home envoie 0 pour l'automatique.

## Recherche sur le réseau

Home envoie `DAIKIN_UDP/common/basic_info` en diffusion UDP sur le port 30050 et garde les adresses privées qui répondent pendant quatre secondes. Si rien ne répond (certains routeurs bloquent la diffusion), l'ajout par adresse marche toujours : l'adresse est affichée dans la liste des appareils de la box.

## Ce que Home commande

Marche/arrêt, automatique, froid, chaud, consigne au demi-degré entre 10 et 32 °C. Sec et ventilation s'affichent mais ne se commandent pas : dans ces modes la consigne vaut `M` ou `--`, et ce qu'il faut renvoyer n'est pas documenté.

## Sécurité

- Seules les adresses privées (10.x, 172.16 à 172.31, 192.168.x) sont acceptées, à l'ajout comme avant chaque requête.
- Le module n'a pas d'authentification : n'importe qui sur le Wi-Fi de la maison peut le commander, avec ou sans Home.

## Ce qui reste à vérifier sur les appareils

- Le code `0` pour l'automatique, et la consigne que l'appareil accepte dans ce mode.
- Le comportement du passage de sec ou ventilation vers froid, chaud ou automatique (Home envoie 22 °C).
- Le nombre de connexions simultanées (environ 4 d'après les outils existants) : Home lit les appareils l'un après l'autre.
- Le modèle exact de tes modules : l'étiquette du module ou l'appli Onecta le donne.
