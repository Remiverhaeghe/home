/// Une version du CHANGELOG : son titre et ses rubriques, chacune avec ses lignes.
class ReleaseNotes {
  const ReleaseNotes({required this.title, required this.sections});

  final String title;

  /// Rubrique (Ajouté, Corrigé…) vers ses lignes, dans l'ordre du fichier.
  final Map<String, List<String>> sections;

  bool get isEmpty => sections.values.every((pLines) => pLines.isEmpty);
}

/// Première version décrite dans un CHANGELOG au format « ## Version », « ### Rubrique »,
/// « - ligne » ; le balisage simple (code, gras) est retiré pour l'affichage. Sans version, les
/// notes sont vides.
ReleaseNotes latestReleaseNotes(String pChangelog) {
  var vTitle = '';
  var vSection = '';
  final vSections = <String, List<String>>{};
  var vInside = false;
  for (final vRaw in pChangelog.split('\n')) {
    final vLine = vRaw.trimRight();
    if (vLine.startsWith('## ')) {
      if (vInside) {
        break;
      }
      vInside = true;
      vTitle = vLine.substring(3).trim();
    } else if (!vInside) {
      continue;
    } else if (vLine.startsWith('### ')) {
      vSection = vLine.substring(4).trim();
      vSections.putIfAbsent(vSection, () => []);
    } else if (vLine.startsWith('- ') && vSection.isNotEmpty) {
      vSections[vSection]!.add(_plain(vLine.substring(2)));
    }
  }

  return ReleaseNotes(title: vTitle, sections: vSections);
}

String _plain(String pText) => pText.replaceAll('`', '').replaceAll('**', '').trim();
