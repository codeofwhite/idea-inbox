import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idea_inbox/security/device_identity.dart';
import 'package:idea_inbox/storage/database.dart';
import 'package:idea_inbox/storage/idea_repository.dart';
import 'package:idea_inbox/sync/client.dart';
import 'package:idea_inbox/sync/pairing.dart';
import 'package:idea_inbox/sync/protocol.dart';
import 'package:idea_inbox/sync/server.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  test(
    'real TLS pairing, two-way sync, lost ack retry, conflicts and revocation',
    () async {
      final desktop = DeviceIdentity(MemorySecrets());
      final phone = DeviceIdentity(MemorySecrets());
      await desktop.initialize();
      await phone.initialize();
      final desktopPairs = PairingStore(desktop.secrets);
      final phonePairs = PairingStore(phone.secrets);
      final desktopDb = AppDatabase(':memory:');
      final phoneDb = AppDatabase(':memory:');
      final desktopRepo = IdeaRepository(desktopDb, desktop.id);
      final phoneRepo = IdeaRepository(phoneDb, phone.id);
      var confirmed = 0;
      final server = SyncServer(
        identity: desktop,
        pairing: desktopPairs,
        repository: desktopRepo,
        confirmPairing: (_) async {
          confirmed++;
          return true;
        },
        onStatus: (_) {},
      );
      final client = SyncClient(phone, phonePairs, phoneRepo);
      try {
        await server.start('127.0.0.1', port: 0);
        final endpoint = server.endpoint!;
        final transport = HttpClient(
          context: SecurityContext(withTrustedRoots: false),
        );
        transport.findProxy = (_) => 'DIRECT';
        transport.badCertificateCallback = (cert, _, _) =>
            sha256.convert(cert.der).toString() == desktop.fingerprint;
        Future<Map<String, dynamic>> request(
          String path,
          Map<String, dynamic> body, {
          bool auth = true,
          int status = 200,
        }) async {
          final req = await transport.postUrl(Uri.parse('$endpoint$path'));
          req.headers.contentType = ContentType.json;
          if (auth) {
            req.headers.set(
              'authorization',
              'Bearer ${phonePairs.peer!.token}',
            );
          }
          req.write(jsonEncode(message({'deviceId': phone.id, ...body})));
          final response = await req.close();
          expect(response.statusCode, status);
          return readMessage(response);
        }

        try {
          await request('/inventory', {}, auth: false, status: 401);
          final offer = server.offer();
          await client.pair(
            PairingOffer.decode(offer.encode(), loopback: true),
          );
          expect(confirmed, 1);
          // The first QR code cannot be reused, even by the same phone.
          await expectLater(client.pair(offer), throwsStateError);
          for (var i = 0; i < 10; i++) {
            phoneRepo.create('离线灵感 $i');
          }
          final first = await client.sync();
          expect(first.sent, 10);
          expect(desktopRepo.ideas.length, 10);
          expect(phoneRepo.pending(desktop.id), 0);
          expect(desktopRepo.pending(phone.id), 0);
          expect((await client.sync()).sent, 0);

          // Simulate a disconnect after /exchange persisted data but before /ack.
          phoneRepo.create('确认丢失时也不能重复');
          final inventory = await request('/inventory', {});
          final ids = parseIds(inventory['ids']);
          await request('/exchange', {
            'known': phoneRepo.ids.toList(),
            'revisions': phoneRepo.revisions
                .where((r) => !ids.contains(r.id))
                .map((r) => r.toJson())
                .toList(),
          });
          expect(desktopRepo.pending(phone.id), 1);
          await client.sync();
          expect(desktopRepo.ideas.length, 11);
          expect(desktopRepo.pending(phone.id), 0);

          final ideaId = phoneRepo.ideas.first.id;
          final onPhone = phoneRepo.ideas.firstWhere((i) => i.id == ideaId);
          final onDesktop = desktopRepo.ideas.firstWhere((i) => i.id == ideaId);
          phoneRepo.update(onPhone, '手机离线修改');
          desktopRepo.update(onDesktop, '电脑离线修改');
          await client.sync();
          expect(
            desktopRepo.ideas.firstWhere((i) => i.id == ideaId).conflicted,
            true,
          );
          final conflict = phoneRepo.ideas.firstWhere((i) => i.id == ideaId);
          phoneRepo.update(conflict, '合并两端内容');
          await client.sync();
          expect(
            desktopRepo.ideas.firstWhere((i) => i.id == ideaId).conflicted,
            false,
          );

          final trusted = phonePairs.peer!;
          await phonePairs.save(
            Peer(
              id: trusted.id,
              endpoint: trusted.endpoint,
              fingerprint: List.filled(64, '0').join(),
              token: trusted.token,
            ),
          );
          await expectLater(client.sync(), throwsA(isA<HandshakeException>()));
          await phonePairs.save(trusted);
          await desktopPairs.revoke();
          await expectLater(client.sync(), throwsStateError);
          expect(desktopRepo.ideas.length, 11);
        } finally {
          transport.close(force: true);
        }
      } finally {
        await server.stop();
        desktopRepo.dispose();
        phoneRepo.dispose();
        desktopDb.close();
        phoneDb.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('pairing rejects external addresses and incompatible payloads', () {
    expect(
      () => checkedEndpoint('http://192.168.1.1:47381'),
      throwsFormatException,
    );
    expect(() => checkedEndpoint('https://example.com'), throwsFormatException);
    expect(() => checkedEndpoint('https://8.8.8.8'), throwsFormatException);
    expect(
      () => checkedEndpoint('https://192.168.1.1/path'),
      throwsFormatException,
    );
    expect(() => PairingOffer.decode('{}'), throwsFormatException);
    expect(checkedEndpoint('https://192.168.1.2:47381').host, '192.168.1.2');
  });
}
