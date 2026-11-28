import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/release_notes.dart';

const _changelog = '''
# Changelog

## 0.2.0

### Ajouté

- Un menu `Plus` regroupe les écrans.
- Le **bilan** du chauffage.

### Corrigé

- Une alerte en double.

## 0.1.0

### Ajouté

- Première version.
''';

void main() {
  test('seule la première version est lue, avec ses rubriques dans l\'ordre', () {
    final vNotes = latestReleaseNotes(_changelog);

    expect(vNotes.title, '0.2.0');
    expect(vNotes.sections.keys, ['Ajouté', 'Corrigé']);
    expect(vNotes.sections['Corrigé'], ['Une alerte en double.']);
    expect(vNotes.isEmpty, isFalse);
  });

  test('le balisage simple est retiré', () {
    final vLines = latestReleaseNotes(_changelog).sections['Ajouté']!;

    expect(vLines, ['Un menu Plus regroupe les écrans.', 'Le bilan du chauffage.']);
  });

  test('sans version ou sans ligne, les notes sont vides', () {
    expect(latestReleaseNotes('').isEmpty, isTrue);
    expect(latestReleaseNotes('# Changelog\n\nrien').isEmpty, isTrue);
    expect(latestReleaseNotes('## Non publié\n\n### Ajouté\n').isEmpty, isTrue);
  });

  test('une ligne hors rubrique est ignorée', () {
    final vNotes = latestReleaseNotes('## 1.0\n\n- orpheline\n\n### Ajouté\n\n- ok');

    expect(vNotes.sections, {
      'Ajouté': ['ok'],
    });
  });
}
