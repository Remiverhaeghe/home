# Fragments du changelog

Chaque lot ajoute ici un fichier au lieu de modifier `CHANGELOG.md` : deux lots en cours ne se marchent plus dessus.

- Nom : `sujet.added.md` (Ajouté), `sujet.changed.md` (Modifié) ou `sujet.fixed.md` (Corrigé).
- Contenu : la ligne du changelog, sans le tiret.
- Assemblage : `python3 tool/changelog.py` les range dans « Non publié » et supprime les fragments ; `python3 tool/changelog.py 0.2.0` publie la version.
