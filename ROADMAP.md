# Feuille de route

Tout doit marcher avec le téléphone seul : pas de NAS, pas de serveur, pas de compte.

- [x] Lot 1 : import d'un fichier d'échange et carte par capteur
- [x] Lot 2 : lecture en direct du TP357 en Bluetooth, diagnostic des trames d'historique
- [ ] Lot 3 : relevé de l'historique du capteur (dates décodées d'après les trames du diagnostic), puis courbes par jour
- [x] Lot 3 bis : climatisations Daikin BRP069, état, commandes, lien avec le capteur de la pièce
- [x] Lot 4 : relevé des capteurs en arrière-plan, courbes par jour
- [ ] Lot 4 ter : historique du capteur (dates décodées d'après les trames du diagnostic)
- [x] Lot 5 : pilotage (température souhaitée par pièce et profil, planning, fenêtre ouverte, vacances, alertes affichées)
- [x] Lot 5 bis : règles de seuil ajoutées et supprimées à l'écran
- [x] Lot 5 ter : plan appliqué en arrière-plan appli fermée, alertes dans la notification du service
- [x] Lot 5 quater : notifications d'alerte avec son et bannière
- [ ] Lot iOS : clés `Info.plist` (Bluetooth, réseau local, HTTP vers les clims), CI macOS sans signature, relevé limité à l'appli ouverte, installation sans compte payant
- [ ] Lot 4 bis : modules BRP072C à clé (HTTPS), si c'est ton module

## Appareils à ajouter

À chaque fois : un écran de commande, un état lu sur le réseau de la maison, et le lien avec la pièce.

- [x] Velux à radio simple : relais Wi-Fi en parallèle des contacts de la télécommande (une passerelle KLF 200 ne sert qu'aux modèles io-homecontrol)
- [x] Porte de garage : relais Wi-Fi sur le contact sec du moteur, confirmation obligatoire à chaque commande (docs/relais.md)
- [x] Poêle à pellets Ecoforest : état, marche et arrêt, consigne de température par le réseau de la maison (docs/poele-pellets.md)
- [ ] Poêle à pellets : réglage de la puissance et libellés des étapes d'allumage et d'alarme, à relever sur le vrai poêle
- [ ] Prises de courant connectées : marche/arrêt et consommation, marque à choisir
- [x] Export du fichier d'échange pour Atelier, enregistré depuis le téléphone

## Écran mural

Home sur un écran dans la pièce principale, avec une vue 3D de la maison et la gestion de tout.

- [x] Mode écran mural : paysage, plein écran, écran allumé, grosses commandes lisibles à deux mètres
- [ ] Vue 3D de la maison : plan repris d'Atelier, pièces colorées selon la température et l'humidité, toucher une pièce pour régler clim, fenêtres, poêle et prises
- [ ] La tablette murale, toujours allumée, sert de centrale : relevés et automatismes tournent dessus, sans NAS
- [x] Lieu de la maison saisi à la main et emplacement des capteurs (pièce, niveau, extérieur), liste groupée par niveau
- [x] Sauvegarde et restauration de toute la configuration en un fichier
- [x] Thème clair et taille du texte au choix
- [ ] Unités (°F, 12 h) : les textes écrivent « °C » en dur dans une centaine d'endroits ; à faire d'un bloc avec un formateur unique
- [x] Deux capteurs sur les mêmes courbes, notes datées avec effet avant et après
- [ ] Bilan mensuel en PDF : demande une bibliothèque PDF à ajouter et à vérifier en CI
