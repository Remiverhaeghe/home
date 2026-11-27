# Décisions

## 2026-11-27 : les capteurs sont rangés au format d'échange d'Atelier

Contexte : Atelier lit déjà un fichier d'échange JSON (version 1) pour les relevés de plusieurs capteurs, et Home doit pouvoir lui en fournir.
Décision : Home garde ses capteurs dans ce même format (`capteurs.json`), sans base de données propre.
Écarté : SQLite, plus rapide sur de gros historiques mais qui oblige à écrire un export vers Atelier. À revoir si un capteur dépasse quelques dizaines de milliers de relevés.

## 2026-11-27 : un seul thème, sombre

Contexte : l'appli se regarde surtout le soir, sur un téléphone posé ou un écran mural.
Décision : une palette ardoise unique, sans bascule clair/sombre.
Écarté : suivre le réglage du téléphone, qui double les couleurs à entretenir pour un gain faible.

## 2026-11-27 : aucune permission réseau

Contexte : les relevés de la maison sont des données privées.
Décision : l'appli ne déclare pas la permission réseau ; l'import passe par un fichier choisi par l'utilisateur.
