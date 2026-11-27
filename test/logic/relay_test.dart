import 'package:flutter_test/flutter_test.dart';
import 'package:home/logic/relay.dart';

void main() {
  group('adresse de l\'impulsion', () {
    test('Shelly Plus ou Pro : Switch.Set avec retombée automatique', () {
      final vUri = relayRequest(
        const RelayButton(name: 'Garage', host: '192.168.1.40', channel: 1, pulseSeconds: 2),
      );

      expect(vUri.toString(), 'http://192.168.1.40/rpc/Switch.Set?id=1&on=true&toggle_after=2');
    });

    test('Shelly 1 ou 2.5 : relais avec minuterie', () {
      final vUri = relayRequest(
        const RelayButton(
          name: 'Velux',
          host: '10.0.0.7',
          model: RelayModel.shellyGen1,
          channel: 2,
        ),
      );

      expect(vUri.toString(), 'http://10.0.0.7/relay/2?turn=on&timer=1');
    });

    test('l\'impulsion est bornée entre 1 et 10 secondes', () {
      expect(
        relayRequest(const RelayButton(name: 'A', host: '192.168.1.5', pulseSeconds: 99)).query,
        contains('toggle_after=10'),
      );
      expect(
        relayRequest(const RelayButton(name: 'A', host: '192.168.1.5', pulseSeconds: 0)).query,
        contains('toggle_after=1'),
      );
    });

    test('une adresse hors de la maison est refusée', () {
      expect(
        () => relayRequest(const RelayButton(name: 'A', host: '8.8.8.8')),
        throwsFormatException,
      );
    });
  });

  test('seule la porte de garage demande confirmation', () {
    expect(
      const RelayButton(name: 'G', host: 'h', kind: RelayKind.garage).needsConfirmation,
      isTrue,
    );
    expect(
      const RelayButton(name: 'V', host: 'h', kind: RelayKind.velux).needsConfirmation,
      isFalse,
    );
    expect(const RelayButton(name: 'A', host: 'h').needsConfirmation, isFalse);
  });

  group('fichier relais.json', () {
    test('ce qui est écrit se relit à l\'identique', () {
      const vButtons = [
        RelayButton(
          name: 'Garage',
          host: '192.168.1.40',
          kind: RelayKind.garage,
          model: RelayModel.shellyGen1,
          channel: 1,
          pulseSeconds: 3,
        ),
        RelayButton(name: 'Velux salon', host: '192.168.1.41', kind: RelayKind.velux),
      ];

      final vBack = parseRelays(relaysJson(vButtons));

      expect(vBack.map((pButton) => pButton.name), ['Garage', 'Velux salon']);
      expect(vBack[0].kind, RelayKind.garage);
      expect(vBack[0].model, RelayModel.shellyGen1);
      expect(vBack[0].channel, 1);
      expect(vBack[0].pulseSeconds, 3);
      expect(vBack[1].model, RelayModel.shellyGen2);
    });

    test('un fichier illisible, d\'une autre version ou sans liste donne une liste vide', () {
      expect(parseRelays('pas du json'), isEmpty);
      expect(parseRelays('{"version": 9, "buttons": []}'), isEmpty);
      expect(parseRelays('[]'), isEmpty);
      expect(parseRelays('{"version": 1}'), isEmpty);
    });

    test('les entrées incomplètes sont ignorées et les valeurs absurdes corrigées', () {
      final vButtons = parseRelays(
        '{"version": 1, "buttons": ['
        '{"name": "", "host": "192.168.1.9"},'
        '{"name": "Sans adresse"},'
        '42,'
        '{"name": "Bizarre", "host": "192.168.1.9", "kind": "x", "model": "y",'
        ' "channel": -3, "pulse": 500}'
        ']}',
      );

      expect(vButtons, hasLength(1));
      expect(vButtons.single.kind, RelayKind.other);
      expect(vButtons.single.model, RelayModel.shellyGen2);
      expect(vButtons.single.channel, 0);
      expect(vButtons.single.pulseSeconds, maxPulseSeconds);
    });
  });
}
