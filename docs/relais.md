# Garage et Velux par relais Wi-Fi

Home n'a pas de retour d'état sur ces équipements : il envoie un appui, comme le ferait la
télécommande ou le bouton mural. Rien ne sort de la maison, l'adresse du boîtier doit être celle
d'un réseau privé.

## Matériel pris en charge

Un boîtier Shelly à contact sec, sur le réseau Wi-Fi de la maison :

| Boîtier | Réglage dans Home | Requête envoyée |
|---|---|---|
| Shelly Plus 1, Plus 2PM, Pro… | Shelly Plus ou Pro | `GET /rpc/Switch.Set?id=<sortie>&on=true&toggle_after=<s>` |
| Shelly 1, 2.5 | Shelly 1 ou 2.5 (ancien) | `GET /relay/<sortie>?turn=on&timer=<s>` |

La sortie retombe toute seule après la durée choisie (1 seconde par défaut, 10 au plus) : un appui,
pas un interrupteur resté collé.

## Branchement

- **Porte de garage** : le contact du relais se met en parallèle du bouton mural du moteur (entrée
  « bouton » ou « pas à pas »), jamais sur le secteur. Le boîtier s'alimente à part. Sans connaître
  la marque du moteur, repérer sur sa carte l'entrée du bouton filaire avant d'acheter.
- **Velux à radio simple** : pas de passerelle possible (elle ne parle qu'aux modèles io-homecontrol).
  Il faut un relais par action (ouvrir, fermer, arrêter) en parallèle des contacts de la
  télécommande, ce qui demande d'ouvrir la télécommande. À faire seulement si l'on est à l'aise
  avec l'électronique ; sinon, garder la télécommande.

Un bouton Home = une sortie d'un boîtier. Une porte, ou un Velux avec ouvrir, fermer et arrêter,
donne donc un à trois boutons.

## Sécurité

- La porte de garage demande toujours confirmation, avec rappel de vérifier qu'il n'y a personne
  dessous.
- Un second appui sur le même bouton dans les 5 secondes est ignoré (double toucher).
- Le boîtier ne doit pas être ouvert sur Internet : pas de redirection de port, pas de cloud inutile.
- Home ne sait pas si la porte est ouverte ou fermée : un appui reste un appui.
