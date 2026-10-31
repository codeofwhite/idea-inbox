import 'dart:async';
import 'dart:io';

import '../models/idea.dart';
import '../security/device_identity.dart';
import '../storage/idea_repository.dart';
import 'pairing.dart';
import 'protocol.dart';

class SyncServer {
  final DeviceIdentity identity;
  final PairingStore pairing;
  final IdeaRepository repository;
  final Future<bool> Function(String deviceId) confirmPairing;
  final void Function(String status) onStatus;
  HttpServer? _server;
  String? _offerSecret;
  DateTime? _offerExpiry;
  bool _pairingBusy = false;
  String? endpoint;
  bool get running => _server != null;
  SyncServer({
    required this.identity,
    required this.pairing,
    required this.repository,
    required this.confirmPairing,
    required this.onStatus,
  });

  Future<void> start(String address, {int port = syncPort}) async {
    if (!isPrivateAddress(address, loopback: true)) {
      throw const FormatException('请选择局域网地址');
    }
    await stop();
    await identity.ensureCertificate();
    final server = await HttpServer.bindSecure(
      InternetAddress(address),
      port,
      identity.serverContext,
      shared: false,
    );
    server.idleTimeout = const Duration(seconds: 40);
    _server = server;
    endpoint = 'https://$address:${server.port}';
    server.listen((request) {
      unawaited(_handle(request));
    }, onError: (Object error) => onStatus(friendlyError(error)));
    onStatus('等待手机连接');
  }

  PairingOffer offer() {
    if (!running) throw StateError('请先开启局域网同步');
    _offerSecret = randomSecret();
    _offerExpiry = DateTime.now().add(const Duration(minutes: 2));
    return PairingOffer(
      deviceId: identity.id,
      endpoint: endpoint!,
      fingerprint: identity.fingerprint,
      secret: _offerSecret!,
    );
  }

  void cancelOffer() {
    _offerSecret = null;
    _offerExpiry = null;
  }

  Future<void> stop() async {
    cancelOffer();
    final server = _server;
    _server = null;
    endpoint = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.method != 'POST') {
        await writeResponse(request.response, {
          'error': '仅支持 POST',
        }, status: 405);
        return;
      }
      final path = request.uri.path;
      if (path == '/pair') {
        await _pair(request);
        return;
      }
      final peer = pairing.peer;
      if (peer == null ||
          !secretEquals(
            request.headers.value('authorization') ?? '',
            'Bearer ${peer.token}',
          )) {
        await writeResponse(request.response, {
          'error': '设备未配对或配对已撤销',
        }, status: 401);
        return;
      }
      final data = await readMessage(request);
      // Permission may have been revoked while the request body was arriving.
      if (pairing.peer != peer) {
        await writeResponse(request.response, {'error': '配对已变更'}, status: 401);
        return;
      }
      if (data['deviceId'] != peer.id) throw const FormatException('设备身份不一致');
      if (path == '/inventory') {
        await writeResponse(request.response, {
          'deviceId': identity.id,
          'ids': repository.ids.toList(),
        });
      } else if (path == '/exchange') {
        final known = parseIds(data['known']);
        final incoming = parseRevisions(data['revisions']);
        final missing = repository.revisions
            .where((r) => !known.contains(r.id))
            .toList();
        // Preflight response size BEFORE committing incoming revisions.
        final outgoing = {
          'deviceId': identity.id,
          'revisions': missing.map((r) => r.toJson()).toList(),
          'received': incoming.map((r) => r.id).toList(),
        };
        // writeResponse can otherwise emit a response the client cannot ingest.
        ensureMessageSize(outgoing);
        final count = repository.ingest(incoming);
        await writeResponse(request.response, outgoing);
        onStatus('已接收 $count 个修订，等待手机确认');
      } else if (path == '/ack') {
        repository.acknowledge(peer.id, parseIds(data['ids']));
        await writeResponse(request.response, {
          'deviceId': identity.id,
          'ok': true,
        });
        onStatus(
          '同步完成 · ${DateTime.now().toLocal().toString().substring(0, 19)}',
        );
      } else {
        await writeResponse(request.response, {'error': '未知接口'}, status: 404);
      }
    } catch (error) {
      try {
        final validation =
            error is FormatException ||
            error is TypeError ||
            error is ArgumentError;
        await writeResponse(request.response, {
          'error': validation ? '同步数据无效或超过版本限制' : '电脑保存失败，请查看电脑端状态',
        }, status: validation ? 400 : 500);
      } catch (_) {
        // The remote socket may already be closed; the persisted data is retained.
      }
      onStatus('同步失败：${friendlyError(error)}');
    }
  }

  Future<void> _pair(HttpRequest request) async {
    if (_pairingBusy) {
      await writeResponse(request.response, {
        'error': '已有配对请求，请稍后',
      }, status: 409);
      return;
    }
    _pairingBusy = true;
    try {
      final data = await readMessage(request);
      final offered = _offerSecret;
      if (offered == null ||
          _offerExpiry == null ||
          DateTime.now().isAfter(_offerExpiry!) ||
          !secretEquals(data['secret'] as String? ?? '', offered)) {
        await writeResponse(request.response, {
          'error': '配对码已失效，请在电脑重新生成',
        }, status: 403);
        return;
      }
      final mobileId = checkedId(data['deviceId']);
      cancelOffer(); // Single-use, including when the user rejects the request.
      final accepted = await confirmPairing(
        mobileId,
      ).timeout(const Duration(seconds: 60), onTimeout: () => false);
      if (!accepted || !running) {
        await writeResponse(request.response, {
          'error': '电脑未批准配对',
        }, status: 403);
        return;
      }
      final token = randomSecret();
      await pairing.save(
        Peer(id: mobileId, endpoint: '', fingerprint: '', token: token),
      );
      await writeResponse(request.response, {
        'deviceId': identity.id,
        'token': token,
      });
      onStatus('配对成功，可在手机点击同步');
    } finally {
      _pairingBusy = false;
    }
  }
}
