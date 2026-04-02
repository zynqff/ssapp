import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  // ── Token ─────────────────────────────────────────────────────────────────

  Future<void> saveToken(String token) =>
      _storage.write(key: _kTokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _kTokenKey);

  Future<void> clearToken() => _storage.delete(key: _kTokenKey);

  // ── OTP ───────────────────────────────────────────────────────────────────

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

  // ── Google ────────────────────────────────────────────────────────────────

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

  // ── User ──────────────────────────────────────────────────────────────────

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

  Future<String?> requestEmailChange(String newEmail) async {
    try {
      await _dio.post('/api/change_email/request',
          data: {'new_email': newEmail.trim()});
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка запроса смены email';
    }
  }

  Future<String?> confirmOldEmailCode(String token) async {
    try {
      await _dio.post('/api/change_email/confirm_old',
          data: {'token': token.trim()});
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Неверный или истёкший код';
    }
  }

  Future<String?> confirmNewEmailCode(String newEmail, String token) async {
    try {
      await _dio.post('/api/change_email/confirm_new',
          data: {'new_email': newEmail.trim(), 'token': token.trim()});
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Неверный или истёкший код';
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

  // ── Рекомендации ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchRecommendations() async {
    try {
      final res = await _dio.get('/api/recommendations');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Библиотека ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getMyLibrary() async {
    try {
      final res = await _dio.get('/api/library/mine');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLibrary(int id) async {
    try {
      final res = await _dio.get('/api/library/$id');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> updateMyLibrary(String name, String description) async {
    try {
      await _dio.put('/api/library/mine',
          data: {'name': name, 'description': description});
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка обновления';
    }
  }

  /// Добавить стих из общей БД
  Future<String?> addPoemToLibrary(int poemId) async {
    try {
      await _dio.post('/api/library/mine/poems', data: {'poem_id': poemId});
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка добавления';
    }
  }

  /// Добавить кастомный стих
  Future<String?> addCustomPoemToLibrary({
    required String title,
    required String author,
    required String text,
  }) async {
    try {
      await _dio.post('/api/library/mine/poems', data: {
        'custom_title': title,
        'custom_author': author,
        'custom_text': text,
      });
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка добавления';
    }
  }

  Future<String?> removePoemFromLibrary(int entryId) async {
    try {
      await _dio.delete('/api/library/mine/poems/$entryId');
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка удаления';
    }
  }

  Future<Map<String, dynamic>?> toggleLibraryPoemRead(int entryId) async {
    try {
      final res = await _dio
          .post('/api/library/mine/poems/$entryId/toggle_read');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> toggleLibraryPoemPin(int entryId) async {
    try {
      final res = await _dio
          .post('/api/library/mine/poems/$entryId/toggle_pin');
      return res.data as Map<String, dynamic>;
    } catch (e) {
      if (e is DioException) {
        final msg = _extractError(e);
        if (msg != null) return {'error': msg};
      }
      return null;
    }
  }

  Future<String?> deleteMyLibrary() async {
    try {
      await _dio.delete('/api/library/mine');
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка удаления';
    }
  }

  Future<({String? error, String? status})> publishLibrary() async {
    try {
      final res = await _dio.post('/api/library/mine/publish');
      return (error: null, status: res.data['status'] as String?);
    } on DioException catch (e) {
      return (error: _extractError(e) ?? 'Ошибка публикации', status: null);
    }
  }

  /// Снять библиотеку с публикации (#2)
  Future<String?> unpublishLibrary() async {
    try {
      await _dio.post('/api/library/mine/unpublish');
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка';
    }
  }

  Future<Map<String, dynamic>?> toggleLibraryLike(int libraryId) async {
    try {
      final res = await _dio.post('/api/library/$libraryId/like');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> saveLibrary(int libraryId, {bool isDefault = false}) async {
    try {
      await _dio.post('/api/library/$libraryId/save',
          data: {'is_default': isDefault});
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка сохранения';
    }
  }

  Future<String?> unsaveLibrary(int libraryId) async {
    try {
      await _dio.delete('/api/library/$libraryId/save');
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка';
    }
  }

  Future<String?> setDefaultLibrary(int libraryId) async {
    try {
      await _dio.post('/api/library/$libraryId/set_default');
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка';
    }
  }

  Future<List<Map<String, dynamic>>> searchLibraries(String query) async {
    try {
      final res = await _dio.get('/api/library/search',
          queryParameters: {'q': query});
      return List<Map<String, dynamic>>.from(
          (res.data['libraries'] as List));
    } catch (_) {
      return [];
    }
  }

  // ── Admin — модерация ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPendingLibraries() async {
    try {
      final res = await _dio.get('/api/admin/libraries/pending');
      return List<Map<String, dynamic>>.from(
          (res.data['libraries'] as List));
    } catch (_) {
      return [];
    }
  }

  Future<String?> moderateLibrary(int libraryId,
      {required String action, String rejectReason = ''}) async {
    try {
      await _dio.post('/api/admin/libraries/$libraryId/moderate', data: {
        'action': action,
        'reject_reason': rejectReason,
      });
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? 'Ошибка модерации';
    }
  }

  Future<bool> setPoemOfDay(int poemId) async {
    try {
      await _dio
          .post('/api/admin/poem_of_day', data: {'poem_id': poemId});
      return true;
    } catch (_) {
      return false;
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
