import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_config.dart';

const _kConfigCacheKey = 'cached_app_config';

final configProvider =
    StateNotifierProvider<ConfigNotifier, AsyncValue<AppConfig>>(
  (ref) => ConfigNotifier(),
);

class ConfigNotifier extends StateNotifier<AsyncValue<AppConfig>> {
  ConfigNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    // 1. Сразу читаем кеш — работает даже если сервер лежит
    final cached = await _loadCached();
    if (cached != null) {
      state = AsyncValue.data(cached);
    }

    // 2. Грузим свежий конфиг напрямую из Supabase
    try {
      final rows = await Supabase.instance.client
          .from('app_config')
          .select('key, value');

      final map = <String, String>{};
      for (final row in rows) {
        map[row['key'] as String] = row['value'] as String;
      }

      await _saveCache(map);
      state = AsyncValue.data(AppConfig.fromMap(map));
    } catch (e, st) {
      if (cached == null) {
        state = AsyncValue.error(e, st);
      }
      // Если кеш есть — молча оставляем его
    }
  }

  Future<void> reload() => load();

  Future<AppConfig?> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kConfigCacheKey);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppConfig.fromMap(map.map((k, v) => MapEntry(k, v.toString())));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(Map<String, String> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kConfigCacheKey, jsonEncode(map));
    } catch (_) {}
  }
}
