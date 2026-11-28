# Changelog

## Non publié

### Corrigé

- Alerte « capteur muet » : seuls les capteurs suivis en arrière-plan peuvent être signalés muets ; les autres ne donnent un relevé que quand l'appli est ouverte.
- Climatisations et relais : sous Android 17, l'accès au réseau local est maintenant déclaré et demandé avant la première connexion ; sans lui, le système bloque les appareils de la maison

### Ajouté

- Notes de version : l'écran « À propos » montre les nouveautés de la dernière version (le CHANGELOG, livré avec l'appli), repliées par défaut.
- Menu « Plus d'options » dans l'écran des capteurs : les appareils, la maison, les données (export, import CSV, sauvegarde) et l'appli y sont rangés par famille ; la barre ne garde que l'actualisation et le Bluetooth.
- La recherche des climatisations ne dépend plus de la diffusion UDP : elle diffuse aussi sur le réseau du téléphone, puis interroge chaque adresse du même réseau pour trouver les modules que la box ne laisse pas répondre.
- `docs/architecture.md` : couches du code, données, tests et marche à suivre pour ajouter un appareil.
- Audit des permissions et du réseau : `docs/securite.md` liste chaque permission Android, ce qui sort du téléphone et où vivent les identifiants.
- Bilan du chauffage (bouton de l'écran Pilotage) : heures de marche de chaque clim, avec la semaine d'avant, énergie et coût estimés avec la puissance et le prix du kWh que tu donnes, total sur 30 jours avec le poêle, budget mensuel (dans les clous, proche, dépassé) et repère courant d'un degré de consigne en moins (environ 7 %). Heures des clims dans `marche-clims.json`, ajouté à la sauvegarde.
- Poêle : stock de pellets (sacs comptés, diminués de la consommation estimée, autonomie et alerte de stock bas), arrêt programmé du soir appliqué dans la demi-heure qui suit son heure (appli ou service d'arrière-plan), et message quand le poêle s'éteint sans ordre de Home.
- Le service d'arrière-plan tient aussi le journal des heures de marche du poêle et des clims appli fermée.
- Bilan des pièces en PDF (bouton de l'écran des pièces) : mesures du moment, extrêmes sur 14 jours et courbe de température par pièce, quatre pièces par page. PDF écrit sans dépendance ; l'enregistrement passe par le sélecteur de fichier.
- Résumé du matin (interrupteur dans l'écran Pilotage) : à partir de 8 h, le service d'arrière-plan envoie une notification discrète avec la pièce la plus fraîche, la plus humide et le nombre de pièces hors plage d'humidité, une fois par jour.
- Bilan du poêle : prix du sac à saisir, coût estimé sur 7 et 30 jours, et comparaison des heures de marche avec la semaine d'avant (« Marche et pellets »).
- Seuil d'alerte d'humidité réglable dans l'écran Pilotage (de 55 à 85 %, 70 % au départ), gardé dans `reglages-plan.json` et pris en compte par le service d'arrière-plan.
- Captures d'écran d'une maison fictive générées par la CI (workflow Captures, `test/captures`) : liste des capteurs, courbes d'un capteur, écran des pièces. Aucune donnée réelle.
- Poêle éteint en vacances même appli fermée : le service d'arrière-plan relit le poêle à chaque tour et l'éteint s'il marche pendant l'absence (hors remontée avant le retour).
- Écran « À propos » (bouton i de la liste des capteurs) : version de l'appli et journal local des erreurs (`journal-erreurs.txt`, 300 lignes au plus, adresses réseau masquées), à enregistrer dans un fichier ou à vider. Rien n'est envoyé.
- Poêle à pellets : heures de marche relevées à chaque lecture de l'état (appli ouverte), sur 7 et 30 jours, et pellets estimés avec le débit (kg par heure) et le sac (kg) que l'on donne. Sans débit donné, aucun chiffre n'est avancé. Le journal est dans la sauvegarde.
- Coup de chaud par pièce (écran du plan, bouton « Douche, bain, lessive ») : la clim chauffe à la température choisie pendant la durée choisie (douche 24 °C 45 min, bain 25 °C 90 min, lessive 22 °C 3 h au départ), puis le planning reprend. Réglage dans la sauvegarde.
- Seuil de froid réglable (écran du plan, de 10 à 22 °C par demi-degré) : sous ce seuil la clim peut chauffer en plus du poêle ; le réglage est dans la sauvegarde.
- Mode vacances et poêle : pendant l'absence (hors remontée avant le retour), un poêle à pellets resté allumé est éteint par l'appli ouverte.
- Poêle et clim sans conflit : quand le poêle à pellets marche, le plan n'allume plus la clim en chauffage et l'éteint si elle chauffait, sauf s'il fait moins de 16 °C dans la pièce, où les deux peuvent tourner ensemble.
- Périodes de mesure (fiche d'un capteur) : un trou de deux jours ou plus entre deux relevés ouvre une période, que l'on sépare dans un capteur à part pour la ranger dans la bonne pièce, par exemple après un changement de place.
- Actualiser les capteurs : un bouton et le geste de tirer la liste vers le bas lisent une mesure sur chaque thermo-hygromètre à portée.
- Import d'un export CSV de l'appli ThermoPro (bouton d'historique de la liste des capteurs) : le nom du fichier donne le nom du capteur, les lignes sans mesure sont ignorées et un relevé par tranche de dix minutes est gardé. L'export va dans un capteur existant ou dans un nouveau.
- Les pièces (bouton « Les pièces » de la liste des capteurs) : température et humidité du moment par pièce, pièce la plus fraîche et la plus humide, humidité visée (40 à 60 %, 45 à 70 % pour une cave ou un garage) et conseils : aérer quand l'air du dehors contient moins d'eau, garder fermé sinon, air sec signalé. Les conseils d'aération demandent la météo extérieure.
- Comparer deux capteurs (bouton de la liste des capteurs, dès qu'il y en a deux) : température et humidité moyennes par jour sur les mêmes courbes, une seule échelle, et l'écart moyen sur les jours communs
- Notes datées (détail d'un capteur) : « isolation posée », « fenêtre changée », pour un capteur ou toute la maison, avec l'évolution de la température et de l'humidité sur les deux semaines d'après par rapport aux deux semaines d'avant. Rangées dans `notes.json`, reprises par la sauvegarde
- Affichage (bouton palette de la liste des capteurs) : thème clair, sombre ou celui du téléphone, et quatre tailles de texte, de normale à maximale, appliqués à toute l'appli. Réglages rangés dans `apparence.json`, repris par la sauvegarde. Le thème sombre reste celui de départ
- Sauvegarde (bouton « Sauvegarde » de la liste des capteurs) : un seul fichier contient toutes les données (capteurs et noms, climatisations, pièces, règles, vacances, relais, poêle, maison, météo). La restauration relit chaque fichier tel qu'il a été sauvegardé, garde l'ancien à côté en `.avant`, et n'accepte que les fichiers de Home. Le mot de passe du poêle est dans le fichier : à garder en lieu sûr
- Météo extérieure (écran « La maison ») : récupération par Internet des températures et humidités horaires du lieu de la maison auprès d'Open-Meteo, désactivée au départ ; seules les coordonnées partent. Archive de 400 jours sur le téléphone (`meteo.json`), actualisée au plus une fois par heure, copiable en CSV pour un tableur
- Analyses : écart moyen avec l'extérieur sur les mêmes heures et part des variations du dehors qui passe à l'intérieur sur une journée
- La maison (bouton « La maison » de la liste des capteurs) : lieu saisi à la main (nom, latitude, longitude, sans GPS) pour les analyses avec la météo extérieure, rangé dans `maison.json`
- Emplacement des capteurs : pièce, niveau (sous-sol à combles) ou extérieur, choisi depuis le détail du capteur ; la liste est groupée par niveau, l'extérieur à part
- Analyses dans le détail d'un capteur, sur les trente derniers jours : heures de confort (18 à 24 °C, 40 à 60 %), eau dans l'air en g/m³, risque de moisissure d'après la plus longue période à 70 % d'humidité, capteur figé ou saut de valeur
- Capteurs nommables : un crayon dans le détail d'un capteur donne le nom de l'endroit (« Chambre des enfants »). Le nom s'affiche dans la liste, l'affichage mural et le choix du capteur d'une clim ; l'identifiant d'origine reste celui des pièces et des règles. Noms rangés dans `noms-capteurs.json`, hors du fichier d'échange
- Poêle à pellets Ecoforest (bouton flamme de la liste des capteurs) : température de la pièce, étape du poêle, marche et arrêt, consigne de température par pas de 0,5 °C. Connexion HTTPS locale avec le numéro de série et le mot de passe de l'étiquette, rangés dans `poele.json`. Montage décrit dans `docs/poele-pellets.md`
- Garage et Velux : boutons à relais Wi-Fi Shelly (Plus, Pro, 1, 2.5), un par commande, enregistrés dans `relais.json`. La porte de garage demande confirmation, un double appui en moins de 5 secondes est ignoré, les adresses hors du réseau de la maison sont refusées. Montage décrit dans `docs/relais.md`
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
