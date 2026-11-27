# Poêle à pellets Ecoforest

Home lit et commande un poêle Ecoforest équipé du module réseau, par le réseau de la maison, sans cloud.

## Ce qui est fait

- Lecture de l'état : température de la pièce, consigne, étape du poêle, niveau de puissance demandé.
- Marche et arrêt.
- Consigne de température de la pièce, de 10 à 30 °C par pas de 0,5 °C.

La puissance ne se règle pas depuis Home : l'ordre correspondant n'est pas documenté.

## Ce qu'il faut

- Le poêle sur le Wi-Fi de la maison, avec une adresse fixe (réservation DHCP sur la box).
- Le numéro de série du poêle et les huit premiers caractères du mot de passe, sur l'étiquette fournie avec le module réseau.

## Comment Home parle au poêle

Requêtes `POST` en HTTPS sur le port 8000, `/recepcion_datos_4.cgi`, avec une authentification Basic (numéro de série et mot de passe). Le corps porte l'opération : `idOperacion=1002` pour l'état, `1013` pour la marche ou l'arrêt (`on_off`), `1019` pour la consigne (`temperatura`). La réponse est une suite de lignes `clé=valeur`.

Le poêle présente un certificat auto-signé. Home l'accepte uniquement pour l'adresse enregistrée, déjà vérifiée comme appartenant au réseau privé ; toute autre adresse est refusée avant l'envoi.

## Étapes du poêle

Le champ `estado` vaut 0 poêle éteint et 7 poêle en marche. Les valeurs intermédiaires (allumage, préchauffage, arrêt, alarme) ne sont pas confirmées : Home affiche « Étape n ». À compléter avec les valeurs relevées sur le vrai poêle.

## Sécurité

- Le numéro de série et le mot de passe sont rangés dans `poele.json`, dans le dossier privé de l'appli, qu'aucune autre appli ne lit sans accès administrateur au téléphone.
- Rien n'est envoyé hors de la maison.
