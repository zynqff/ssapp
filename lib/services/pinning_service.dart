import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Захардкоженный Ed25519 публичный ключ (base64 DER/PKIX).
// Генерация:
//   openssl genpkey -algorithm ed25519 -out private.pem
//   openssl pkey -in private.pem -pubout -outform DER | base64
// Приватный ключ → GitHub Secret CONFIG_PRIVATE_KEY
// ─────────────────────────────────────────────────────────────────────────────
const _kEd25519PublicKeyB64 = 'СЮДА_ВСТАВЬ_СВОЙ_BASE64_ПУБЛИЧНЫЙ_КЛЮЧ';

// Ключи SecureStorage
const _kStorageApiUrl         = 'pinned_api_url';
const _kStorageApiFingerprint = 'pinned_api_fingerprint';

// Fallback на случай если SecureStorage пуст (первый запуск без сети).
// После первой успешной загрузки конфига этот URL больше не используется.
const _kGithubPagesConfigUrl =
    'https://zynqff.github.io/ss-config/config.json';
const _kGithubPagesSigUrl =
    'https://zynqff.github.io/ss-config/config.sig';

class PinningService {
  PinningService._();
  static final instance = PinningService._();

  final _storage = const FlutterSecureStorage();

  /// Текущий доверенный fingerprint (SHA-256 SPKI, hex верхний регистр).
  /// Загружается из SecureStorage при старте, обновляется после верификации конфига.
  String? _trustedFingerprint;
  String? _trustedApiUrl;

  String? get trustedApiUrl         => _trustedApiUrl;
  String? get trustedFingerprint    => _trustedFingerprint;

  // ── Инициализация при старте ───────────────────────────────────────────────

  /// Загружает сохранённые url + fingerprint из SecureStorage.
  /// Вызывать в main() до первого запроса к бэкенду.
  Future<void> init() async {
    _trustedApiUrl         = await _storage.read(key: _kStorageApiUrl);
    _trustedFingerprint    = await _storage.read(key: _kStorageApiFingerprint);
    debugPrint('[Pinning] init: url=$_trustedApiUrl fp=$_trustedFingerprint');
  }

  // ── Загрузка и верификация конфига с GitHub Pages ─────────────────────────

  /// Скачивает config.json + config.sig, проверяет Ed25519 подпись,
  /// сохраняет api_url и api_fingerprint в SecureStorage.
  /// Возвращает распарсенный конфиг или null если верификация провалилась.
  Future<Map<String, dynamic>?> fetchAndVerifyConfig() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      // Скачиваем конфиг и подпись параллельно
      final results = await Future.wait([
        dio.get<String>(_kGithubPagesConfigUrl,
            options: Options(responseType: ResponseType.plain)),
        dio.get<String>(_kGithubPagesSigUrl,
            options: Options(responseType: ResponseType.plain)),
      ]);

      final configRaw = results[0].data ?? '';
      final sigB64    = (results[1].data ?? '').trim();

      // Верифицируем подпись
      final verified = _verifySignature(configRaw, sigB64);
      if (!verified) {
        debugPrint('[Pinning] ❌ Подпись config.json не прошла!');
        return null;
      }

      final json = jsonDecode(configRaw) as Map<String, dynamic>;

      // Извлекаем и сохраняем api_url и api_fingerprint
      final apiUrl         = json['api_url']         as String?;
      final apiFingerprint = json['api_fingerprint'] as String?;

      if (apiUrl == null || apiUrl.isEmpty) {
        debugPrint('[Pinning] ❌ api_url отсутствует в конфиге');
        return null;
      }
      if (apiFingerprint == null || apiFingerprint.isEmpty) {
        debugPrint('[Pinning] ❌ api_fingerprint отсутствует в конфиге');
        return null;
      }

      // Сохраняем в SecureStorage
      await Future.wait([
        _storage.write(key: _kStorageApiUrl,         value: apiUrl),
        _storage.write(key: _kStorageApiFingerprint, value: apiFingerprint.toUpperCase()),
      ]);

      _trustedApiUrl      = apiUrl;
      _trustedFingerprint = apiFingerprint.toUpperCase();

      debugPrint('[Pinning] ✅ Конфиг верифицирован. url=$apiUrl fp=$apiFingerprint');
      return json;
    } catch (e) {
      debugPrint('[Pinning] Ошибка загрузки конфига: $e');
      return null;
    }
  }

  // ── SSL Pinning для Dio ───────────────────────────────────────────────────

  /// Применяет SSL pinning к переданному Dio-инстансу.
  /// После вызова каждый HTTPS-запрос будет проверять SPKI fingerprint сертификата.
  void applyToDio(Dio dio) {
    (dio.httpClientAdapter as IOHttpClientAdapter).validateCertificate =
        (X509Certificate? cert, String host, int port) {
      if (cert == null) {
        debugPrint('[Pinning] ❌ Сертификат null для $host:$port');
        return false;
      }

      final fp = _trustedFingerprint;
      if (fp == null) {
        // Конфиг ещё не загружен — блокируем запрос во избежание MITM
        debugPrint('[Pinning] ❌ Fingerprint не загружен, блокируем $host');
        return false;
      }

      // SHA-256 SPKI (SubjectPublicKeyInfo) сертификата
      final spkiHash = _spkiSha256(cert.der);
      final match    = spkiHash.toUpperCase() == fp;

      if (!match) {
        debugPrint('[Pinning] ❌ Fingerprint не совпал для $host');
        debugPrint('[Pinning]   ожидали: $fp');
        debugPrint('[Pinning]   получили: ${spkiHash.toUpperCase()}');
      }

      return match;
    };
  }

  // ── Ed25519 верификация ───────────────────────────────────────────────────

  bool _verifySignature(String configJson, String sigBase64) {
    try {
      final pubKeyDer = base64.decode(_kEd25519PublicKeyB64);
      final sigBytes  = base64.decode(sigBase64);
      final msgBytes  = Uint8List.fromList(utf8.encode(configJson));

      // PKIX DER обёртка для Ed25519 = 12 байт header + 32 байта ключа
      final rawKey = pubKeyDer.length == 44
          ? pubKeyDer.sublist(12)
          : pubKeyDer; // уже сырые 32 байта

      final verifier = Ed25519Signer()
        ..init(
          false,
          PublicKeyParameter<Ed25519PublicKey>(Ed25519PublicKey(rawKey)),
        );

      return verifier.verifySignature(msgBytes, Ed25519Signature(sigBytes));
    } catch (e) {
      debugPrint('[Pinning] Ошибка верификации подписи: $e');
      return false;
    }
  }

  // ── SPKI SHA-256 ──────────────────────────────────────────────────────────

  /// Извлекает SubjectPublicKeyInfo из DER сертификата и возвращает SHA-256 hex.
  /// cert.der в Flutter — это DER всего сертификата (TBSCertificate).
  /// SPKI находится внутри TBSCertificate — парсим ASN.1 вручную.
  String _spkiSha256(Uint8List certDer) {
    try {
      final spki = _extractSpki(certDer);
      final digest = SHA256Digest();
      digest.update(spki, 0, spki.length);
      final out = Uint8List(32);
      digest.doFinal(out, 0);
      return out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      debugPrint('[Pinning] Ошибка извлечения SPKI: $e');
      // Fallback: SHA-256 всего DER (менее надёжно при обновлении сертификата)
      final digest = SHA256Digest();
      digest.update(certDer, 0, certDer.length);
      final out = Uint8List(32);
      digest.doFinal(out, 0);
      return out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
  }

  /// Минимальный ASN.1 парсер для извлечения SPKI из DER сертификата.
  /// Структура: SEQUENCE { SEQUENCE(TBS) { ... SEQUENCE(SPKI) ... } }
  Uint8List _extractSpki(Uint8List der) {
    // Certificate = SEQUENCE { tbsCertificate, signatureAlgorithm, signature }
    // tbsCertificate = SEQUENCE { version, serialNumber, signature,
    //                             issuer, validity, subject, subjectPublicKeyInfo, ... }
    // Нам нужен subjectPublicKeyInfo — 7-й элемент TBS

    var offset = 0;

    // Входим в Certificate SEQUENCE
    offset = _enterSequence(der, offset);
    // Входим в TBSCertificate SEQUENCE
    offset = _enterSequence(der, offset);

    // Пропускаем version [0] EXPLICIT (опционально)
    if (der[offset] == 0xa0) {
      offset += 2 + der[offset + 1]; // tag + length + value
    }

    // Пропускаем: serialNumber, signature alg, issuer, validity, subject
    for (var i = 0; i < 5; i++) {
      offset = _skipElement(der, offset);
    }

    // Теперь offset указывает на subjectPublicKeyInfo SEQUENCE
    final spkiStart = offset;
    final spkiLen   = _elementLength(der, offset);
    return der.sublist(spkiStart, spkiStart + spkiLen);
  }

  int _enterSequence(Uint8List der, int offset) {
    assert(der[offset] == 0x30, 'Ожидали SEQUENCE (0x30)');
    offset++; // пропускаем tag
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
    var len = 1; // tag byte
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
