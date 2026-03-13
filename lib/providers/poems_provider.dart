import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/poem.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

final poemsProvider =
    StateNotifierProvider<PoemsNotifier, AsyncValue<List<Poem>>>((ref) {
  return PoemsNotifier();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredPoemsProvider = Provider<List<Poem>>((ref) {
  final poems = ref.watch(poemsProvider).value ?? [];
  final q = ref.watch(searchQueryProvider).toLowerCase().trim();
  if (q.isEmpty) return poems;
  return poems
      .where((p) =>
          p.title.toLowerCase().contains(q) ||
          p.author.toLowerCase().contains(q) ||
          p.text.toLowerCase().contains(q))
      .toList();
});

class PoemsNotifier extends StateNotifier<AsyncValue<List<Poem>>> {
  PoemsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  final _db = DatabaseService();
  final _sync = SyncService();

  Future<void> load() async {
    try {
      // Сначала — локальные данные (мгновенно)
      final local = await _db.getAllPoems();
      if (local.isNotEmpty) state = AsyncValue.data(local);

      // Потом пробуем синхронизировать
      final result = await _sync.syncPoems();
      if (result == SyncResult.success) {
        state = AsyncValue.data(await _db.getAllPoems());
      } else if (local.isEmpty) {
        state = AsyncValue.error(
            'Нет данных. Подключитесь к интернету для первой загрузки.',
            StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => load();
}
