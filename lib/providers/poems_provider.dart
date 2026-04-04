import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/poem.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';

part 'poems_provider.g.dart';

@riverpod
class Poems extends _$Poems {
  DatabaseService get _db => ref.read(dbServiceProvider);
  SyncService get _sync => ref.read(syncServiceProvider);

  @override
  Future<List<Poem>> build() => _load();

  Future<List<Poem>> _load() async {
    try {
      final local = await _db.getAllPoems();
      if (local.isNotEmpty) {
        Future.microtask(_syncInBackground);
        return local;
      }
      final result = await _sync.syncPoems();
      if (result == SyncResult.success) return _db.getAllPoems();
      throw Exception('Нет данных. Подключитесь к интернету для первой загрузки.');
    } catch (e) {
      debugPrint('[Poems] Ошибка загрузки: $e');
      rethrow;
    }
  }

  Future<void> _syncInBackground() async {
    try {
      final result = await _sync.syncPoems();
      if (result == SyncResult.success) {
        final updated = await _db.getAllPoems();
        state = AsyncValue.data(updated);  // ← без mounted
      }
    } catch (e) {
      debugPrint('[Poems] Ошибка фоновой синхронизации: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }
}

@riverpod
String searchQuery(SearchQueryRef ref) => '';

@riverpod
List<Poem> filteredPoems(FilteredPoemsRef ref) {
  final poems = ref.watch(poemsProvider).value ?? [];
  final q = ref.watch(searchQueryProvider).toLowerCase().trim();
  if (q.isEmpty) return poems;
  return poems
      .where((p) =>
          p.title.toLowerCase().contains(q) ||
          p.author.toLowerCase().contains(q) ||
          p.text.toLowerCase().contains(q))
      .toList();
}