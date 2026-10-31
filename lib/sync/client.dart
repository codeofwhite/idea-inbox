import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../security/device_identity.dart';
import '../storage/idea_repository.dart';
import 'pairing.dart';
import 'protocol.dart';

class SyncResult {
  final int sent, received;
  SyncResult(this.sent, this.received);
}

class SyncClient {
  final DeviceIdentity identity;
  final PairingStore pairing;
  final IdeaRepository repository;
  bool _busy = false;
  SyncClient(this.identity, this.pairing, this.repository);

  Future<Map<String, dynamic>> _post(
    String endpoint,
    String fingerprint,
    String path,
    Map<String, dynamic> fields, {
    String? token,
  }) async {
    final payload = message({'deviceId': identity.id, ...fields});
    ensureMessageSize(payload);
    // No platform roots: every certificate must match the QR fingerprint.
    final client = HttpClient(
      context: SecurityContext(withTrustedRoots: false),
    );
    client.connectionTimeout = const Duration(seconds: 8);
    client.findProxy = (_) => 'DIRECT';
    client.badCertificateCallback = (cert, host, port) =>
        secretEquals(sha256.convert(cert.der).toString(), fingerprint);
    try {
      final request = await client.postUrl(
        Uri.parse(endpoint).replace(path: path),
      );
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      if (token != null) request.headers.set('authorization', 'Bearer $token');
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(
        const Duration(seconds: 90),
      );
      final data = await readMessage(response);
      if (response.statusCode != 200) {
        throw StateError(data['error'] as String? ?? '同步被拒绝');
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> pair(PairingOffer offer) async {
    if (_busy) throw StateError('请等待当前同步或配对完成');
    _busy = true;
    try {
      final data = await _post(offer.endpoint, offer.fingerprint, '/pair', {
        'secret': offer.secret,
      });
      if (data['deviceId'] != offer.deviceId) {
        throw const FormatException('电脑身份与二维码不符');
      }
      final token = data['token'] as String;
      if (token.length < 40 || token.length > 128) {
        throw const FormatException('配对凭证无效');
      }
      await pairing.save(
        Peer(
          id: offer.deviceId,
          endpoint: offer.endpoint,
          fingerprint: offer.fingerprint,
          token: token,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<SyncResult> sync() async {
    final peer = pairing.peer;
    if (peer == null) throw StateError('请先扫描电脑二维码配对');
    if (_busy) throw StateError('正在同步，请稍候');
    _busy = true;
    try {
      Future<Map<String, dynamic>> post(
        String path,
        Map<String, dynamic> body,
      ) async {
        final result = await _post(
          peer.endpoint,
          peer.fingerprint,
          path,
          body,
          token: peer.token,
        );
        if (result['deviceId'] != peer.id || pairing.peer != peer) {
          throw const FormatException('配对身份已变化，已停止同步');
        }
        return result;
      }

      final inventory = await post('/inventory', {});
      final remoteIds = parseIds(inventory['ids']);
      // Snapshot before I/O. Later local edits remain pending until the next sync.
      final local = repository.revisions;
      final outgoing = local.where((r) => !remoteIds.contains(r.id)).toList();
      final result = await post('/exchange', {
        'known': local.map((r) => r.id).toList(),
        'revisions': outgoing.map((r) => r.toJson()).toList(),
      });
      final receivedIds = parseIds(result['received']);
      if (!receivedIds.containsAll(outgoing.map((r) => r.id))) {
        throw const FormatException('电脑未确认收到完整数据');
      }
      final count = repository.ingest(parseRevisions(result['revisions']));
      await post('/ack', {'ids': repository.ids.toList()});
      repository.acknowledge(peer.id, {
        ...remoteIds,
        ...receivedIds,
        ...parseRevisions(result['revisions']).map((r) => r.id),
      });
      return SyncResult(outgoing.length, count);
    } finally {
      _busy = false;
    }
  }
}
