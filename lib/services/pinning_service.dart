import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';  // для Dart implementation

const _kEd25519PublicKeyB64 = 'MCowBQYDK2VwAyEAixC+QsgLKtfAUHCrpTqqlmxChRjQpe5MMPdzHtZves8=';

const _kStorageApiUrl = 'pinned_api_url';
const _kStorageApiFingerprint = 'pinned_api_fingerprint';

const _kGithubPagesConfigUrl = 'https://zynqff.github.io/ss-config/config.json';
const _kGithubPagesSigUrl = 'https://zynqff.github.io/ss-config/config.sig';

class PinningService {
  PinningService._();
  static final instance = PinningService._();

  final _storage = const FlutterSecureStorage();

  String? _trustedFingerprint;
  String? _trustedApiUrl;

  String? get trustedApiUrl => _trustedApiUrl;
  String? get trustedFingerprint => _trustedFingerprint;

  Future<void> init() async {
    _trustedApiUrl = await _storage.read(key: _kStorageApiUrl);
    _trustedFingerprint = await _storage.read(key: _kStorageApiFingerprint);
    debugPrint('[Pinning] init: url=$_trustedApiUrl fp=$_trustedFingerprint');
  }

  Future<Map<String, dynamic>?> fetchAndVerifyConfig() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      final results = await Future.wait([
        dio.get<String>(_kGithubPagesConfigUrl,
            options: Options(responseType: ResponseType.plain)),
        dio.get<String>(_kGithubPagesSigUrl,
            options: Options(responseType: ResponseType.plain)),
      ]);

      final configRaw = results[0].data ?? '';
      final sigB64 = (results[1].data ?? '').trim();

      final verified = await _verifySignature(configRaw, sigB64);
      if (!verified) {
        debugPrint('[Pinning] ❌ Подпись config.json не прошла!');
        return null;
      }

      final json = jsonDecode(configRaw) as Map<String, dynamic>;

      final apiUrl = json['api_url'] as String?;
      final apiFingerprint = json['api_fingerprint'] as String?;

      if (apiUrl == null || apiUrl.isEmpty) {
        debugPrint('[Pinning] ❌ api_url отсутствует в конфиге');
        return null;
      }
      if (apiFingerprint == null || apiFingerprint.isEmpty) {
        debugPrint('[Pinning] ❌ api_fingerprint отсутствует в конфиге');
        return null;
      }

      await Future.wait([
        _storage.write(key: _kStorageApiUrl, value: apiUrl),
        _storage.write(key: _kStorageApiFingerprint, value: apiFingerprint.toUpperCase()),
      ]);

      _trustedApiUrl = apiUrl;
      _trustedFingerprint = apiFingerprint.toUpperCase();

      debugPrint('[Pinning] ✅ Конфиг верифицирован. url=$apiUrl fp=$apiFingerprint');
      return json;
    } catch (e) {
      debugPrint('[Pinning] Ошибка загрузки конфига: $e');
      return null;
    }
  }

  void applyToDio(Dio dio) {
    (dio.httpClientAdapter as IOHttpClientAdapter).validateCertificate =
        (X509Certificate? cert, String host, int port) {
      if (cert == null) {
        debugPrint('[Pinning] ❌ Сертификат null для $host:$port');
        return false;
      }

      final fp = _trustedFingerprint;
      if (fp == null) {
        debugPrint('[Pinning] ❌ Fingerprint не загружен, блокируем $host');
        return false;
      }

      final spkiHash = _spkiSha256(cert.der);
      final match = spkiHash.toUpperCase() == fp;

      if (!match) {
        debugPrint('[Pinning] ❌ Fingerprint не совпал для $host');
        debugPrint('[Pinning]   ожидали: $fp');
        debugPrint('[Pinning]   получили: ${spkiHash.toUpperCase()}');
      }

      return match;
    };
  }

  Future<bool> _verifySignature(String configJson, String sigBase64) async {
    try {
      final pubKeyDer = base64.decode(_kEd25519PublicKeyB64);
      final sigBytes = base64.decode(sigBase64);
      final msgBytes = utf8.encode(configJson);

      // Извлекаем raw 32-байтный ключ из PKIX DER
      final rawKey = pubKeyDer.length == 44 ? pubKeyDer.sublist(12) : pubKeyDer;

      final publicKey = SimplePublicKey(rawKey, type: KeyPairType.ed25519);
      final signature = Signature(sigBytes, publicKey: publicKey);

      final verified = await DartEd25519().verifySignature(
        signature,
        msgBytes,
        publicKey: publicKey,
      );

      return verified;
    } catch (e) {
      debugPrint('[Pinning] Ошибка верификации подписи: $e');
      return false;
    }
  }

  String _spkiSha256(Uint8List certDer) {
    try {
      final spki = _extractSpki(certDer);
      final bytes = sha256.convert(spki).bytes;
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      debugPrint('[Pinning] Ошибка извлечения SPKI: $e');
      final bytes = sha256.convert(certDer).bytes;
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
  }

  Uint8List _extractSpki(Uint8List der) {
    var offset = 0;
    offset = _enterSequence(der, offset);
    offset = _enterSequence(der, offset);

    if (der[offset] == 0xa0) {
      offset += 2 + der[offset + 1];
    }

    for (var i = 0; i < 5; i++) {
      offset = _skipElement(der, offset);
    }

    final spkiStart = offset;
    final spkiLen = _elementLength(der, offset);
    return der.sublist(spkiStart, spkiStart + spkiLen);
  }

  int _enterSequence(Uint8List der, int offset) {
    assert(der[offset] == 0x30, 'Ожидали SEQUENCE (0x30)');
    offset++;
    if (der[offset] & 0x80 != 0) {
      final lenBytes = der[offset] & 0x7f;
      offset += 1 + lenBytes;
    } else {
      offset++;
    }
    return offset;
  }

  int _skipElement(Uint8List der, int offset) {
    return offset + _elementLength(der, offset);
  }

  int _elementLength(Uint8List der, int offset) {
    var len = 1;
    if (der[offset + 1] & 0x80 != 0) {
      final lenBytes = der[offset + 1] & 0x7f;
      len += 1 + lenBytes;
      var value = 0;
      for (var i = 0; i < lenBytes; i++) {
        value = (value << 8) | der[offset + 2 + i];
      }
      len += value;
    } else {
      len += 1 + der[offset + 1];
    }
    return len;
  }
}
