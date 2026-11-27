# Décisions

## 2026-11-27 : les capteurs sont rangés au format d'échange d'Atelier

Contexte : Atelier lit déjà un fichier d'échange JSON (version 1) pour les relevés de plusieurs capteurs, et Home doit pouvoir lui en fournir.
Décision : Home garde ses capteurs dans ce même format (`capteurs.json`), sans base de données propre.
Écarté : SQLite, plus rapide sur de gros historiques mais qui oblige à écrire un export vers Atelier. À revoir si un capteur dépasse quelques dizaines de milliers de relevés.

## 2026-11-27 : Home ne commande pas les modes sec et ventilation

Contexte : dans ces modes l'appareil n'a pas de consigne (`stemp` vaut `M` ou `--`) et `set_control_info` exige les six paramètres, ce que les outils existants ne documentent pas.
Décision : Home commande marche/arrêt, auto, froid, chaud et la consigne ; sec et ventilation s'affichent mais se règlent à la télécommande, jusqu'à vérification sur l'appareil.
Écarté : envoyer `M` ou `--` en retour, au risque d'une réponse `PARAM NG` ou d'un réglage inattendu.

## 2026-11-27 : un seul thème, sombre

Contexte : l'appli se regarde surtout le soir, sur un téléphone posé ou un écran mural.
Décision : une palette ardoise unique, sans bascule clair/sombre.
Écarté : suivre le réglage du téléphone, qui double les couleurs à entretenir pour un gain faible.

## 2026-11-27 : le service Bluetooth du TP357 est lu sur le capteur

Contexte : les outils libres qui parlent au TP357 donnent les caractéristiques (`…2b10`, `…2b11`) mais pas le service qui les contient.
Décision : Home découvre les services du capteur et prend celui qui porte la caractéristique, au lieu d'écrire un identifiant de service deviné.
Écarté : fixer un identifiant de service tiré d'un autre modèle ThermoPro, faux si le micrologiciel diffère.

## 2026-11-27 : le lot 2 ne décode pas les dates de l'historique

Contexte : les trames d'historique ne portent pas de date lisible dans les outils existants, et je n'ai pas le capteur sous la main pour trancher.
Décision : le lot 2 lit seulement la mesure en direct et affiche les trames brutes de l'historique ; les dates se décodent au lot 3 avec une capture réelle.
Écarté : deviner un pas de temps fixe, qui placerait des relevés faux dans les courbes.

## 2026-11-27 : réseau local seulement, pour les climatisations

Contexte : les relevés de la maison sont des données privées, mais les climatisations Daikin se pilotent par le Wi-Fi.
Décision : l'appli déclare la permission réseau pour parler aux modules en HTTP sur le réseau de la maison. Le code vérifie chaque adresse (`isPrivateAddress`) avant toute requête : rien ne part vers Internet.
Écarté : le compte Daikin Onecta, qui passerait par les serveurs du fabricant. À reconsidérer si un module ne propose pas d'API locale.

## 2026-11-27 : tout tourne sur le téléphone

Contexte : pas de NAS pour le moment, et les relevés de la maison sont privés.
Décision : aucune partie serveur. Les capteurs se liront en Bluetooth depuis le téléphone, l'historique reste dans `capteurs.json`, et l'échange avec Atelier passe par un fichier partagé depuis le téléphone.
Écarté : un service sur le NAS qui collecterait les relevés en continu. À reconsidérer si un NAS arrive, avec le même fichier d'échange comme format.
