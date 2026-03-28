import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import '../services/api_service.dart';

const _kConfigCacheKey = 'cached_app_config';

// 🔧 Замени на свой URL после создания GitHub Pages репо
const _kFallbackConfigUrl =
    'https://zynqff.github.io/ss-config/config.json';

// Дефолт если вообще ничего не доступно
final _kDefaultConfig = AppConfig(
  maintenanceUntil: null,
  forceUpdateVersion: '0.0.0',
  registrationEnabled: true,
  aiEnabled: true,
  googleSigninEnabled: true,
  aiDailyLimit: 0,
  bannerText: 'Сервер временно недоступен. Попробуйте позже.',
  bannerColor: 'warning',
);

final configProvider =
    StateNotifierProvider<ConfigNotifier, AsyncValue<AppConfig>>(
  (ref) => ConfigNotifier(),
);

class ConfigNotifier extends StateNotifier<AsyncValue<AppConfig>> {
  ConfigNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  final _api = ApiService();
  final _fallbackDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  Timer? _retryTimer;

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    // 1. Сразу показываем кеш если есть
    final cached = await _loadCached();
    if (cached != null) state = AsyncValue.data(cached);

    // 2. Пробуем основной бэкенд (5 сек таймаут)
    final mainConfig = await _fetchMain();
    if (mainConfig != null) {
      await _saveCache(mainConfig);
      if (mounted) state = AsyncValue.data(AppConfig.fromMap(mainConfig));
      _retryTimer?.cancel();
      return;
    }

    // 3. Основной не ответил — пробуем GitHub Pages
    //    и параллельно начинаем ретраить основной в фоне
    final fallback = await _fetchFallback();
    if (fallback != null) {
      if (mounted) state = AsyncValue.data(_configFromFallback(fallback));
      _startRetryingMain();
      return;
    }

    // 4. Ничего не ответило — кеш уже показан, или показываем дефолт
    if (cached == null && mounted) {
      state = AsyncValue.data(_kDefaultConfig);
    }
    _startRetryingMain();
  }

  // Стучимся на основной каждые 30 сек пока не очнётся
  void _startRetryingMain() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final mainConfig = await _fetchMain();
      if (mainConfig != null) {
        await _saveCache(mainConfig);
        if (mounted) state = AsyncValue.data(AppConfig.fromMap(mainConfig));
        _retryTimer?.cancel();
      }
    });
  }

  Future<Map<String, String>?> _fetchMain() async {
    try {
      return await _api.fetchConfig();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchFallback() async {
    try {
      final res = await _fallbackDio.get(_kFallbackConfigUrl);
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  AppConfig _configFromFallback(Map<String, dynamic> json) {
    final maintenance = json['maintenance'] as bool? ?? false;
    final until = json['maintenance_until'] as String? ?? '';
    final message = json['message'] as String? ??
        'Технические работы. Скоро вернёмся!';

    DateTime? maintenanceUntil;
    if (maintenance && until.isNotEmpty) {
      maintenanceUntil = DateTime.tryParse(until)?.toLocal();
    }

    return AppConfig(
      maintenanceUntil: maintenanceUntil,
      forceUpdateVersion: '0.0.0',
      registrationEnabled: true,
      aiEnabled: false,
      googleSigninEnabled: true,
      aiDailyLimit: 0,
      bannerText: maintenance
          ? message
          : 'Сервер временно недоступен. Попробуйте позже.',
      bannerColor: 'warning',
    );
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
