import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart' show CryptoUtils, X509Utils;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:uuid/uuid.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecretStore implements SecretStore {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

String randomSecret() {
  final random = Random.secure();
  return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
}

bool secretEquals(String a, String b) {
  final x = sha256.convert(utf8.encode(a)).bytes;
  final y = sha256.convert(utf8.encode(b)).bytes;
  var difference = 0;
  for (var i = 0; i < x.length; i++) {
    difference |= x[i] ^ y[i];
  }
  return difference == 0;
}

class DeviceIdentity {
  final SecretStore secrets;
  late final String id;
  String? certificatePem;
  String? privateKeyPem;
  DeviceIdentity(this.secrets);
  Future<void> initialize() async {
    var stored = await secrets.read('device_id');
    if (stored == null) {
      stored = const Uuid().v4();
      await secrets.write('device_id', stored);
    }
    id = stored;
  }

  Future<void> ensureCertificate() async {
    final stored = await secrets.read('tls_identity');
    final Map<String, dynamic> bundle;
    if (stored != null) {
      bundle = jsonDecode(stored) as Map<String, dynamic>;
    } else {
      bundle = await Isolate.run(() {
        final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
        final privateKey = pair.privateKey as RSAPrivateKey;
        final publicKey = pair.publicKey as RSAPublicKey;
        final csr = X509Utils.generateRsaCsrPem(
          {'CN': 'Idea Inbox'},
          privateKey,
          publicKey,
        );
        return <String, String>{
          'key': CryptoUtils.encodeRSAPrivateKeyToPem(privateKey),
          'cert': X509Utils.generateSelfSignedCertificate(
            privateKey,
            csr,
            3650,
          ),
        };
      });
      await secrets.write('tls_identity', jsonEncode(bundle));
    }
    certificatePem = bundle['cert'] as String;
    privateKeyPem = bundle['key'] as String;
  }

  String get fingerprint {
    final der = base64Decode(
      certificatePem!
          .split(RegExp(r'\r?\n'))
          .where((line) => !line.startsWith('---'))
          .join()
          .trim(),
    );
    return sha256.convert(der).toString();
  }

  SecurityContext get serverContext => SecurityContext()
    ..useCertificateChainBytes(utf8.encode(certificatePem!))
    ..usePrivateKeyBytes(utf8.encode(privateKeyPem!));
}
