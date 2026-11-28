"""Assemble les fragments de `changelog.d/` dans CHANGELOG.md.

Un fragment est un fichier `nom.added.md`, `nom.fixed.md` ou `nom.changed.md` dont le texte
est une ligne du changelog (sans le tiret). Sans argument, les fragments vont dans la section
« Non publié » ; avec un numéro de version, cette section devient cette version.

    python3 tool/changelog.py            # fragments vers « Non publié »
    python3 tool/changelog.py 0.2.0      # publie : « Non publié » devient « 0.2.0 (date) »
"""

import datetime
import pathlib
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
RUBRIQUES = {"added": "Ajouté", "changed": "Modifié", "fixed": "Corrigé"}
ORDRE = ["Corrigé", "Modifié", "Ajouté"]
NON_PUBLIE = "## Non publié"


def lire_fragments(pDossier):
    """Lignes à ajouter par rubrique, et fichiers lus (triés pour un résultat stable)."""
    vLignes = {}
    vFichiers = []
    for vFichier in sorted(pDossier.glob("*.md")):
        vRubrique = RUBRIQUES.get(vFichier.suffixes[0].lstrip(".")) if vFichier.suffixes else None
        if vFichier.name == "README.md" or vRubrique is None:
            continue
        vTexte = " ".join(vFichier.read_text(encoding="utf-8").split())
        if vTexte:
            vLignes.setdefault(vRubrique, []).append(vTexte)
        vFichiers.append(vFichier)
    return vLignes, vFichiers


def inserer(pTexte, pLignes):
    """Ajoute les lignes en tête de chaque rubrique de « Non publié », en la créant au besoin."""
    vSortie = pTexte.split("\n")
    if NON_PUBLIE not in vSortie:
        vSortie[2:2] = [NON_PUBLIE, ""]
    for vRubrique in ORDRE:
        vNouvelles = ["- " + vLigne for vLigne in pLignes.get(vRubrique, [])]
        if not vNouvelles:
            continue
        vDebut = vSortie.index(NON_PUBLIE) + 1
        vFin = next((i for i in range(vDebut, len(vSortie)) if vSortie[i].startswith("## ")), len(vSortie))
        vTitre = "### " + vRubrique
        if vTitre in vSortie[vDebut:vFin]:
            vPos = vSortie.index(vTitre, vDebut) + 2
            vSortie[vPos:vPos] = vNouvelles
        else:
            vSortie[vDebut:vDebut] = ["", vTitre, ""] + vNouvelles
    return "\n".join(vSortie)


def publier(pTexte, pVersion, pDate):
    """Renomme « Non publié » en version datée et rouvre une section « Non publié » vide."""
    return pTexte.replace(NON_PUBLIE, NON_PUBLIE + "\n\n## " + pVersion + " (" + pDate + ")", 1)


def main(pArgs):
    vFichierLog = RACINE / "CHANGELOG.md"
    vDossier = RACINE / "changelog.d"
    vLignes, vFichiers = lire_fragments(vDossier)
    vTexte = inserer(vFichierLog.read_text(encoding="utf-8"), vLignes)
    if pArgs:
        vTexte = publier(vTexte, pArgs[0], datetime.date.today().isoformat())
    vFichierLog.write_text(vTexte, encoding="utf-8")
    for vFichier in vFichiers:
        vFichier.unlink()
    print(f"{len(vFichiers)} fragment(s) assemblé(s)")


if __name__ == "__main__":
    main(sys.argv[1:])
