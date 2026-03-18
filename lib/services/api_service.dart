import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String kBaseUrl = 'https://ssback-go.onrender.com';

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  final _storage = const FlutterSecureStorage();

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: kBaseUrl,
    // Render может спать — даём 30 сек на cold start
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));

  // ─── Auth ─────────────────────────────────────────────────────────────────
  Future<({String? error, bool isAdmin, String username})> login(
      String username, String password) async {
    try {
      final res = await _dio.post('/api/login',
          data: {'username': username, 'password': password});
      final token = res.data['access_token'] as String;
      final isAdmin = res.data['is_admin'] as bool? ?? false;
      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'username', value: username);
      await _storage.write(key: 'is_admin', value: isAdmin.toString());
      return (error: null, isAdmin: isAdmin, username: username);
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] as String? ?? 'Ошибка входа';
      return (error: msg, isAdmin: false, username: '');
    }
  }

  Future<String?> register(String username, String password) async {
    try {
      await _dio.post('/api/register',
          data: {'username': username, 'password': password});
      return null;
    } on DioException catch (e) {
      return e.response?.data?['error'] as String? ?? 'Ошибка регистрации';
    }
  }


  Future<({String? error, String username})> loginWithGoogle(
      String idToken) async {
    try {
      final res = await _dio.post('/api/google/mobile-auth',
          data: {'id_token': idToken});
      final token = res.data['access_token'] as String;
      final username = res.data['username'] as String;
      final isAdmin = res.data['is_admin'] as bool? ?? false;
      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'username', value: username);
      await _storage.write(key: 'is_admin', value: isAdmin.toString());
      return (error: null, username: username);
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] as String? ?? 'Ошибка Google входа';
      return (error: msg, username: '');
    }
  }
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> hasToken() async {
    final t = await _storage.read(key: 'access_token');
    return t != null && t.isNotEmpty;
  }

  Future<String?> getSavedUsername() => _storage.read(key: 'username');
  Future<bool> getSavedIsAdmin() async =>
      (await _storage.read(key: 'is_admin')) == 'true';

  // ─── User ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> fetchMe() async {
    try {
      final res = await _dio.get('/api/me');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateProfile(
      {String? newPassword, String? userData, bool? showAllTab}) async {
    try {
      final data = <String, dynamic>{};
      if (newPassword != null) data['new_password'] = newPassword;
      if (userData != null) data['user_data'] = userData;
      if (showAllTab != null) data['show_all_tab'] = showAllTab;
      await _dio.post('/api/profile', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Poems ────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>?> fetchPoems() async {
    try {
      final res = await _dio.get('/api/poems');
      return List<Map<String, dynamic>>.from(res.data['poems'] as List);
    } catch (_) {
      return null;
    }
  }

  Future<bool> toggleRead(int poemId) async {
    try {
      final res =
          await _dio.post('/api/toggle_read', data: {'poem_id': poemId});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> togglePin(int poemId) async {
    try {
      final res =
          await _dio.post('/api/toggle_pin', data: {'poem_id': poemId});
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─── AI ───────────────────────────────────────────────────────────────────
  Future<String?> chatWithAI(String prompt) async {
    try {
      final res = await _dio
          .post('/api/ai/chat', data: {'prompt': prompt});
      return res.data['response'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return '__no_access__';
      return null;
    }
  }

  Future<bool> verifyAiKey(String key) async {
    try {
      final res = await _dio.post('/api/ai/verify_key', data: {'key': key});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ─── Admin ────────────────────────────────────────────────────────────────
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
      String originalTitle, String title, String author, String text) async {
    try {
      final res = await _dio.put('/api/poems/$originalTitle',
          data: {'title': title, 'author': author, 'text': text});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePoem(String title) async {
    try {
      final res = await _dio.delete('/api/poems/$title');
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAiKeys() async {
    try {
      final res = await _dio.get('/api/ai/keys');
      return List<Map<String, dynamic>>.from(res.data as List);
    } catch (_) {
      return [];
    }
  }

  // ФИКС: был queryParameters — сервер не получал параметры
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
      final res = await _dio.post('/api/ai/disable_key', data: {'key': key});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
