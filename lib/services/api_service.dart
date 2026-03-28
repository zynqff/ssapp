import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 🔧 Замени на свой URL из Northflank после деплоя
const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://zynqochka-ssback-go.hf.space',
);

const _kTokenKey = 'jwt_token';

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  final _storage = const FlutterSecureStorage();

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: kBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));

  // ── Token ────────────────────────────────────────────────────────────────

  Future<void> saveToken(String token) =>
      _storage.write(key: _kTokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _kTokenKey);

  Future<void> clearToken() => _storage.delete(key: _kTokenKey);

  // ── OTP ──────────────────────────────────────────────────────────────────

  /// Отправить OTP код на email.
  /// [isNew]=true → регистрация (нужен [username]), false → вход.
  Future<String?> sendOtp(String email,
      {String? username, bool isNew = false}) async {
    try {
      await _dio.post('/api/auth/send_otp', data: {
        'email': email.trim(),
        'username': username?.trim() ?? '',
        'is_new': isNew,
      });
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка отправки кода';
    }
  }

  /// Подтвердить OTP для входа (пользователь уже существует).
  Future<({String? error, String? token, String? username, bool isAdmin})>
      verifyOtp(String email, String code) async {
    try {
      final res = await _dio.post('/api/auth/verify_otp', data: {
        'email': email.trim(),
        'token': code.trim(),
      });
      final token = res.data['access_token'] as String;
      final username = res.data['username'] as String;
      final isAdmin = res.data['is_admin'] as bool? ?? false;
      await saveToken(token);
      return (error: null, token: token, username: username, isAdmin: isAdmin);
    } on DioException catch (e) {
      return (
        error: _extractError(e) ?? 'Неверный или истёкший код',
        token: null,
        username: null,
        isAdmin: false,
      );
    }
  }

  /// Подтвердить OTP + создать пользователя (регистрация).
  Future<({String? error, String? token, String? username, bool isAdmin})>
      registerOtp(String email, String code, String username) async {
    try {
      final res = await _dio.post('/api/auth/register_otp', data: {
        'email': email.trim(),
        'token': code.trim(),
        'username': username.trim(),
      });
      final token = res.data['access_token'] as String;
      final uname = res.data['username'] as String;
      final isAdmin = res.data['is_admin'] as bool? ?? false;
      await saveToken(token);
      return (error: null, token: token, username: uname, isAdmin: isAdmin);
    } on DioException catch (e) {
      return (
        error: _extractError(e) ?? 'Ошибка регистрации',
        token: null,
        username: null,
        isAdmin: false,
      );
    }
  }

  /// Получить email по username (для входа по никнейму).
  Future<String?> resolveEmail(String usernameOrEmail) async {
    if (usernameOrEmail.contains('@')) return usernameOrEmail.trim();
    try {
      final res = await _dio.post('/api/auth/resolve_email',
          data: {'username': usernameOrEmail.trim()});
      return res.data['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Google ───────────────────────────────────────────────────────────────

  Future<({String? error, String? token, String? username, bool isAdmin})>
      googleMobileAuth(String idToken) async {
    try {
      final res = await _dio
          .post('/api/google/mobile-auth', data: {'id_token': idToken});
      final token = res.data['access_token'] as String;
      final username = res.data['username'] as String;
      final isAdmin = res.data['is_admin'] as bool? ?? false;
      await saveToken(token);
      return (error: null, token: token, username: username, isAdmin: isAdmin);
    } on DioException catch (e) {
      return (
        error: _extractError(e) ?? 'Ошибка Google входа',
        token: null,
        username: null,
        isAdmin: false,
      );
    }
  }

  // ── User ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final res = await _dio.get('/api/me');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> updateProfile({String? userData, bool? showAllTab}) async {
    try {
      final body = <String, dynamic>{};
      if (userData != null) body['user_data'] = userData;
      if (showAllTab != null) body['show_all_tab'] = showAllTab;
      await _dio.post('/api/profile', data: body);
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка обновления профиля';
    }
  }

  /// Смена никнейма. Сервер возвращает новый JWT — сохраняем.
  Future<({String? error, String? newUsername})> changeUsername(
      String newUsername) async {
    try {
      final res = await _dio.post('/api/change_username',
          data: {'new_username': newUsername.trim()});
      final token = res.data['access_token'] as String;
      final uname = res.data['username'] as String;
      await saveToken(token);
      return (error: null, newUsername: uname);
    } on DioException catch (e) {
      return (
        error: _extractError(e) ?? 'Ошибка смены никнейма',
        newUsername: null,
      );
    }
  }

  Future<String?> changeEmail(String newEmail) async {
    try {
      await _dio.post('/api/change_email', data: {'new_email': newEmail.trim()});
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка смены email';
    }
  }

  // ── Poems ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> fetchPoems() async {
    try {
      final res = await _dio.get('/api/poems');
      final data = res.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['poems'] as List);
    } catch (_) {
      return null;
    }
  }

  // ── Toggle ────────────────────────────────────────────────────────────────

  Future<String?> toggleRead(int poemId) async {
    try {
      final res =
          await _dio.post('/api/toggle_read', data: {'poem_id': poemId});
      return res.data['action'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<({String? action, int? pinnedPoemId})> togglePin(int poemId) async {
    try {
      final res =
          await _dio.post('/api/toggle_pin', data: {'poem_id': poemId});
      return (
        action: res.data['action'] as String?,
        pinnedPoemId: (res.data['pinned_poem_id'] as num?)?.toInt(),
      );
    } catch (_) {
      return (action: null, pinnedPoemId: null);
    }
  }

  // ── AI ────────────────────────────────────────────────────────────────────

  Future<String?> chatWithAI(String prompt) async {
    try {
      final res = await _dio.post('/api/ai/chat', data: {'prompt': prompt});
      return res.data['response'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return '__no_access__';
      if (e.response?.statusCode == 503) return '__ai_disabled__';
      if (e.response?.statusCode == 429) {
        final msg =
            e.response?.data?['error'] as String? ?? 'Лимит исчерпан';
        return '__limit__:$msg';
      }
      return null;
    }
  }

  Future<bool> verifyAiKey(String key) async {
    try {
      final res =
          await _dio.post('/api/ai/verify_key', data: {'key': key});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Admin — стихи ─────────────────────────────────────────────────────────

  Future<bool> addPoem(String title, String author, String text) async {
    try {
      final res = await _dio.post('/api/poems',
          data: {'title': title, 'author': author, 'text': text});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> editPoem(
      int id, String title, String author, String text) async {
    try {
      final res = await _dio.put('/api/poems/$id',
          data: {'title': title, 'author': author, 'text': text});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePoem(int id) async {
    try {
      final res = await _dio.delete('/api/poems/$id');
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Admin — AI ключи ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAiKeys() async {
    try {
      final res = await _dio.get('/api/ai/keys');
      return List<Map<String, dynamic>>.from(res.data as List);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> generateAiKey(
      {int expiresInHours = 0, int dailyLimit = 0}) async {
    try {
      final res = await _dio.post('/api/ai/generate_key', data: {
        'expires_in_hours': expiresInHours,
        'daily_limit': dailyLimit,
      });
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> disableAiKey(String key) async {
    try {
      final res =
          await _dio.post('/api/ai/disable_key', data: {'key': key});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Config ────────────────────────────────────────────────────────────────

  Future<Map<String, String>?> fetchConfig() async {
    try {
      final res = await _dio.get('/api/config');
      return (res.data as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['error'] as String?;
    } catch (_) {}
    return null;
  }
}
