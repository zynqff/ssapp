import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ⚠️ Замени на реальный URL сервера
const String kBaseUrl = 'https://ssback-th2z.onrender.com';

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  final _storage = const FlutterSecureStorage();

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: kBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
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
      final res = await _dio.post('/api/login_json',
          data: {'username': username, 'password': password});
      final token = res.data['access_token'] as String;
      final isAdmin = res.data['is_admin'] as bool? ?? false;
      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'username', value: username);
      await _storage.write(key: 'is_admin', value: isAdmin.toString());
      return (error: null, isAdmin: isAdmin, username: username);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] as String? ?? 'Ошибка входа';
      return (error: msg, isAdmin: false, username: '');
    }
  }

  Future<String?> register(String username, String password) async {
    try {
      await _dio.post('/api/register_json',
          data: {'username': username, 'password': password});
      return null;
    } on DioException catch (e) {
      return e.response?.data?['detail'] as String? ?? 'Ошибка регистрации';
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
      // используем form-эндпоинт
      await _dio.post('/profile',
          data: FormData.fromMap({
            if (newPassword != null) 'new_password': newPassword,
            if (userData != null) 'user_data': userData,
            'show_all_tab': (showAllTab ?? false) ? 'on' : '',
          }),
          options: Options(
              followRedirects: false,
              validateStatus: (s) => s != null && s < 500));
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

  Future<bool> toggleRead(String title) async {
    try {
      final res =
          await _dio.post('/toggle_read', data: {'title': title});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> togglePin(String title) async {
    try {
      final res =
          await _dio.post('/toggle_pin', data: {'title': title});
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─── AI ───────────────────────────────────────────────────────────────────
  Future<String?> chatWithAI(String prompt) async {
    try {
      final res = await _dio
          .post('/ai/chat', queryParameters: {'prompt': prompt});
      return res.data['response'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return '__no_access__';
      return null;
    }
  }

  Future<bool> verifyAiKey(String key) async {
    try {
      final res = await _dio.post('/ai/verify_key', data: {'key': key});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ─── Admin ────────────────────────────────────────────────────────────────
  Future<bool> addPoem(String title, String author, String text) async {
    try {
      final res = await _dio
          .post('/add_poem', data: {'title': title, 'author': author, 'text': text});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> editPoem(
      String originalTitle, String title, String author, String text) async {
    try {
      final res = await _dio.post('/edit_poem/$originalTitle',
          data: {'title': title, 'author': author, 'text': text});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePoem(String title) async {
    try {
      final res = await _dio.post('/delete_poem/$title');
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAiKeys() async {
    try {
      final res = await _dio.get('/ai/get_keys');
      return List<Map<String, dynamic>>.from(res.data as List);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> generateAiKey(
      {int expiresInHours = 0, int dailyLimit = 0}) async {
    try {
      final res = await _dio.post('/ai/generate_key', queryParameters: {
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
      final res = await _dio.post('/ai/disable_key/$key');
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
