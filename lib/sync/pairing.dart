import 'dart:convert';
import 'dart:io';

import '../models/idea.dart';
import '../security/device_identity.dart';
import 'protocol.dart';

bool isPrivateAddress(String host, {bool loopback = false}) {
  final address = InternetAddress.tryParse(host);
  if (address == null || address.type != InternetAddressType.IPv4) return false;
  final b = address.rawAddress;
  return b[0] == 10 ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168) ||
      (loopback && address.isLoopback);
}

Uri checkedEndpoint(String raw, {bool loopback = false}) {
  final uri = Uri.parse(raw);
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.port < 1 ||
      uri.port > 65535 ||
      !isPrivateAddress(uri.host, loopback: loopback)) {
    throw const FormatException(
      '请输入局域网 HTTPS 地址，例如 https://192.168.1.10:47381',
    );
  }
  return uri.replace(path: '');
}

class Peer {
  final String id, endpoint, fingerprint, token;
  Peer({
    required this.id,
    required this.endpoint,
    required this.fingerprint,
    required this.token,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'endpoint': endpoint,
    'fingerprint': fingerprint,
    'token': token,
  };
  factory Peer.fromJson(Map<String, dynamic> json) => Peer(
    id: checkedId(json['id']),
    endpoint: json['endpoint'] as String,
    fingerprint: json['fingerprint'] as String,
    token: json['token'] as String,
  );
  Peer at(String endpoint) =>
      Peer(id: id, endpoint: endpoint, fingerprint: fingerprint, token: token);
}

class PairingOffer {
  final String deviceId, endpoint, fingerprint, secret;
  PairingOffer({
    required this.deviceId,
    required this.endpoint,
    required this.fingerprint,
    required this.secret,
  });
  String encode() => jsonEncode(
    message({
      'kind': 'idea-inbox-pair',
      'deviceId': deviceId,
      'endpoint': endpoint,
      'fingerprint': fingerprint,
      'secret': secret,
    }),
  );
  factory PairingOffer.decode(String raw, {bool loopback = false}) {
    if (raw.length > 4096) throw const FormatException('配对码过长');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != protocolVersion ||
        json['kind'] != 'idea-inbox-pair') {
      throw const FormatException('不是兼容的 Idea Inbox 配对码');
    }
    final fingerprint = json['fingerprint'] as String;
    final secret = json['secret'] as String;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint) ||
        !RegExp(r'^[A-Za-z0-9_\-=]{43,44}$').hasMatch(secret)) {
      throw const FormatException('配对码内容无效');
    }
    return PairingOffer(
      deviceId: checkedId(json['deviceId']),
      endpoint: checkedEndpoint(
        json['endpoint'] as String,
        loopback: loopback,
      ).toString(),
      fingerprint: fingerprint,
      secret: secret,
    );
  }
}

class PairingStore {
  final SecretStore secrets;
  Peer? peer;
  PairingStore(this.secrets);
  Future<void> load() async {
    final raw = await secrets.read('paired_peer');
    if (raw != null) {
      peer = Peer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  Future<void> save(Peer value) async {
    await secrets.write('paired_peer', jsonEncode(value.toJson()));
    peer = value;
  }

  Future<void> revoke() async {
    await secrets.delete('paired_peer');
    peer = null;
  }
}
