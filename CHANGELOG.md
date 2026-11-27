# Changelog

## Non publié

### Ajouté

- Affichage mural (bouton « Affichage mural » de la liste des capteurs) : paysage, plein écran, écran allumé, heure et date, une grosse tuile par pièce avec température, humidité, relevé ancien signalé, et boutons d'allumage et de consigne par pas de 0,5 °C ; les climatisations sont relues toutes les 30 secondes
- Notifications d'alerte avec son et bannière (gel, humidité haute, capteur muet), une par alerte, appli ouverte ou fermée ; l'accord est demandé au démarrage
- APK de publication signée à chaque construction, et préversion `build-N` publiée à chaque fusion sur main pour l'installer et la mettre à jour avec Obtainium (si les secrets de signature existent)
- Export des capteurs en fichier d'échange (`home-climat.json`), à enregistrer depuis le téléphone puis à ouvrir dans Atelier, écran « Capteurs de la maison »
- Plan appliqué en arrière-plan, appli fermée : le service relève les capteurs puis commande les climatisations selon les profils, le planning, les règles et le mode vacances, à partir des relevés en attente
- Alertes de gel, d'humidité et de capteur muet affichées dans la notification du service
- Quand l'appli est ouverte, c'est elle qui applique le plan : le service s'efface tant qu'elle s'est signalée depuis moins de 7 minutes
- Pilotage de la maison : température souhaitée par pièce et par profil (confort, nuit, éco, absent), planning de la semaine éditable par pièce, plan appliqué toutes les 5 minutes appli ouverte
- Détection d'une fenêtre ouverte (chute de 1,5 °C en 10 minutes) : la clim se met au repos 30 minutes
- Règles de seuil sur l'humidité et la température du capteur, avec un délai minimal entre deux commandes ; écran pour les ajouter et les supprimer (seuil contrôlé, nom proposé, consigne facultative)
- Température extérieure lue sur la clim : pas de chauffage l'été, pas de froid l'hiver
- Mode vacances : maison tenue hors gel pendant l'absence, remontée en température la veille du retour
- Alertes de gel, d'humidité et de capteur muet
- Pièces, règles et vacances gardées dans `pieces.json`, `automatismes.json` et `vacances.json`
- Relevé des capteurs en arrière-plan toutes les 5 minutes (service de premier plan Android, connexion courte à chaque capteur suivi) ; les relevés passent par un fichier partagé et sont rangés dans l'appli à l'ouverture et au retour
- Interrupteur « Relever en arrière-plan » sur chaque capteur trouvé, avec demande de l'accord pour les notifications
- Détail d'un capteur : courbes de température et d'humidité par jour sur quatorze jours, minimum et maximum
- Climatisations Daikin (modules BRP069) : ajout par adresse ou par recherche sur le réseau de la maison, état, marche/arrêt, mode auto, froid ou chaud, consigne au demi-degré
- Lien entre une climatisation et le capteur de la même pièce : la dernière mesure du capteur s'affiche sur la carte
- Permission réseau limitée au réseau local : le code refuse toute adresse qui n'est pas d'un réseau privé
- Lecture en direct des ThermoPro TP357 en Bluetooth (écran « Capteurs à portée ») : une mesure par minute au plus est gardée dans les relevés du capteur
- Écran de diagnostic de l'historique : demande 24 heures, 7 jours ou 1 an au capteur, affiche et copie les trames brutes
- Fichiers Android versionnés (permissions Bluetooth sans localisation sur Android 12 et plus, aucune permission réseau) et construction d'une APK de débogage en CI
- Squelette Flutter : thème sombre (ambre pour la température, bleu pour l'humidité), textes en français, CI (formatage, analyse, tests, couverture des règles, recherche de secrets)
- Lecture et écriture du fichier d'échange JSON des capteurs, le même que lit Atelier
- Écran des capteurs : une carte par capteur avec température, humidité, point de rosée, niveau de l'air et date du dernier relevé
- Import d'un fichier d'échange : les nouveaux relevés s'ajoutent, ceux de même date sont remplacés
- Capteurs gardés dans `capteurs.json` sur le téléphone, écrit sans risque de fichier à moitié écrit
