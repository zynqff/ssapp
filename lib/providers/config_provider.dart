import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config.dart';
import '../services/api_service.dart';

final configProvider =
    StateNotifierProvider<ConfigNotifier, AsyncValue<AppConfig>>(
  (ref) => ConfigNotifier(),
);

class ConfigNotifier extends StateNotifier<AsyncValue<AppConfig>> {
  ConfigNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final map = await ApiService().fetchConfig();
      if (map != null) {
        state = AsyncValue.data(AppConfig.fromMap(map));
      } else {
        state = AsyncValue.data(AppConfig.defaults());
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reload() => load();
}
