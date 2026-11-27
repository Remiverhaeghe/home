# Feuille de route

Tout doit marcher avec le téléphone seul : pas de NAS, pas de serveur, pas de compte.

- [x] Lot 1 : import d'un fichier d'échange et carte par capteur
- [x] Lot 2 : lecture en direct du TP357 en Bluetooth, diagnostic des trames d'historique
- [ ] Lot 3 : relevé de l'historique du capteur (dates décodées d'après les trames du diagnostic), puis courbes par jour
- [x] Lot 3 bis : climatisations Daikin BRP069, état, commandes, lien avec le capteur de la pièce
- [x] Lot 4 : relevé des capteurs en arrière-plan, courbes par jour
- [ ] Lot 4 ter : historique du capteur (dates décodées d'après les trames du diagnostic)
- [ ] Lot 5 : automatismes (couper ou régler la clim selon l'humidité et la température du capteur), seuils par pièce et notification, mode vacances (règles de confort suspendues, maison tenue hors gel)
- [ ] Lot iOS : clés `Info.plist` (Bluetooth, réseau local, HTTP vers les clims), CI macOS sans signature, relevé limité à l'appli ouverte, installation sans compte payant
- [ ] Lot 4 bis : modules BRP072C à clé (HTTPS), si c'est ton module

## Appareils à ajouter

À chaque fois : un écran de commande, un état lu sur le réseau de la maison, et le lien avec la pièce.

- [ ] Velux : par une passerelle KLF 200 (les télécommandes seules ne suffisent pas)
- [ ] Porte de garage : relais Wi-Fi sur le contact sec du moteur, confirmation obligatoire à chaque commande
- [ ] Poêle à pellets Ecoforest : état et commande par le réseau de la maison, si le modèle a le module réseau
- [ ] Prises de courant connectées : marche/arrêt et consommation, marque à choisir
- [ ] Export du fichier d'échange pour Atelier, partagé depuis le téléphone

## Écran mural

Home sur un écran dans la pièce principale, avec une vue 3D de la maison et la gestion de tout.

- [ ] Mode écran mural : paysage, plein écran, écran allumé, grosses commandes lisibles à deux mètres
- [ ] Vue 3D de la maison : plan repris d'Atelier, pièces colorées selon la température et l'humidité, toucher une pièce pour régler clim, fenêtres, poêle et prises
- [ ] La tablette murale, toujours allumée, sert de centrale : relevés et automatismes tournent dessus, sans NAS
