import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config.dart';
import '../services/api_service.dart';

final configProvider =
    AsyncNotifierProvider<ConfigNotifier, AppConfig>(ConfigNotifier.new);

class ConfigNotifier extends AsyncNotifier<AppConfig> {
  final _api = ApiService();

  @override
  Future<AppConfig> build() => _fetch();

  Future<AppConfig> _fetch() async {
    final map = await _api.fetchConfig();
    if (map == null) return AppConfig.defaults();
    return AppConfig.fromMap(map);
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}
