import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://ssback-go.onrender.com',
);

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: kBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Берём токен из Supabase Auth — он всегда актуален
        final token = Supabase.instance.client.auth.currentSession?.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));

  // ─── Poems (только для sync_service — читаем из Supabase напрямую) ────────

  Future<List<Map<String, dynamic>>?> fetchPoems() async {
    try {
      final rows = await Supabase.instance.client
          .from('poem')
          .select('id, title, author, text');
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return null;
    }
  }

  // ─── AI ───────────────────────────────────────────────────────────────────

  Future<String?> chatWithAI(String prompt) async {
    try {
      final res = await _dio.post('/api/ai/chat', data: {'prompt': prompt});
      return res.data['response'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return '__no_access__';
      if (e.response?.statusCode == 503) return '__ai_disabled__';
      if (e.response?.statusCode == 429) {
        final msg = e.response?.data?['error'] as String? ?? 'Лимит исчерпан';
        return '__limit__:$msg';
      }
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

  // ─── Admin — стихи (через бэкенд, там проверка is_admin) ─────────────────

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

  // ─── Admin — AI ключи ─────────────────────────────────────────────────────

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
      final res = await _dio.post('/api/ai/disable_key', data: {'key': key});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
