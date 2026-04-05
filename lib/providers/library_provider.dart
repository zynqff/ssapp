import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/library.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';

part 'library_provider.g.dart';

@riverpod
class MyLibrary extends _$MyLibrary {
  ApiService get _api => ref.read(apiServiceProvider);
  DatabaseService get _db => ref.read(dbServiceProvider);
  SyncService get _sync => ref.read(syncServiceProvider);

  String? get _username => ref.read(authProvider).value?.username;

  @override
  Future<LibraryState?> build() => _load();

  Future<LibraryState?> _load() async {
    final username = _username;

    // 1. Сразу отдаём локальный кеш если есть
    if (username != null) {
      final cached = await _db.loadLibrary(username);
      if (cached != null) {
        Future.microtask(() => _syncInBackground(username));
        return cached;
      }
    }

    // 2. Кеша нет — пробуем загрузить с сервера
    if (!await _sync.isOnline()) return null;
    return _fetchFromServer(username);
  }

  Future<LibraryState?> _fetchFromServer(String? username) async {
    try {
      final data = await _api.getMyLibrary().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[MyLibrary] Таймаут загрузки');
          return null;
        },
      );
      if (data == null) {
        throw Exception('Не удалось загрузить библиотеку. Проверь интернет.');
      }
      final s = LibraryState.fromJson(data);
      if (username != null) await _db.saveLibrary(username, s);
      return s;
    } catch (e) {
      debugPrint('[MyLibrary] Ошибка загрузки: $e');
      rethrow;
    }
  }

  Future<void> _syncInBackground(String username) async {
    if (!await _sync.isOnline()) return;
    try {
      final data = await _api
          .getMyLibrary()
          .timeout(const Duration(seconds: 20), onTimeout: () => null);
      if (data == null) return;
      final fresh = LibraryState.fromJson(data);
      await _db.saveLibrary(username, fresh);
      if (ref.mounted) state = AsyncValue.data(fresh);
    } catch (e) {
      debugPrint('[MyLibrary] Ошибка фоновой синхронизации: $e');
    }
  }

  Future<void> load() async => reload();

  Future<void> reload() async {
    final username = _username;

    // Показываем кеш пока грузим
    if (username != null) {
      final cached = await _db.loadLibrary(username);
      if (cached != null) state = AsyncValue.data(cached);
    }

    if (!await _sync.isOnline()) return;

    try {
      final fresh = await _fetchFromServer(username);
      if (ref.mounted) state = AsyncValue.data(fresh);
    } catch (e) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  Future<String?> addPoem(int poemId) async {
    try {
      final err = await _api.addPoemToLibrary(poemId);
      if (err == null) await reload();
      return err;
    } catch (e) {
      debugPrint('[MyLibrary] addPoem: $e');
      return 'Ошибка: $e';
    }
  }

  Future<String?> addCustomPoem({
    required String title,
    required String author,
    required String text,
  }) async {
    try {
      final err = await _api.addCustomPoemToLibrary(
          title: title, author: author, text: text);
      if (err == null) await reload();
      return err;
    } catch (e) {
      debugPrint('[MyLibrary] addCustomPoem: $e');
      return 'Ошибка: $e';
    }
  }

  Future<String?> removePoem(int entryId) async {
    try {
      final err = await _api.removePoemFromLibrary(entryId);
      if (err == null) await reload();
      return err;
    } catch (e) {
      debugPrint('[MyLibrary] removePoem: $e');
      return 'Ошибка: $e';
    }
  }

  Future<void> removePoems(List<int> entryIds) async {
    try {
      for (final id in entryIds) await _api.removePoemFromLibrary(id);
      await reload();
    } catch (e) {
      debugPrint('[MyLibrary] removePoems: $e');
    }
  }

  /// toggleRead — работает офлайн, синхронизируется при наличии сети
  Future<void> toggleRead(int entryId) async {
    final current = state.value;
    if (current == null) return;
    final username = _username;

    // Оптимистичное обновление UI
    final updated = current.poems.map((p) {
      if (p.id == entryId) return p.copyWith(isRead: !p.isRead);
      return p;
    }).toList();
    state = AsyncValue.data(current.copyWith(poems: updated));

    // Локальный кеш
    if (username != null) await _db.toggleLibraryPoemRead(username, entryId);

    // Сервер
    if (await _sync.isOnline()) {
      try {
        await _api.toggleLibraryPoemRead(entryId);
      } catch (e) {
        debugPrint('[MyLibrary] toggleRead sync: $e');
        await _db.addToSyncQueue('library_toggle_read', '{"entry_id":$entryId}');
      }
    } else {
      await _db.addToSyncQueue('library_toggle_read', '{"entry_id":$entryId}');
    }
  }

  /// togglePin — работает офлайн, синхронизируется при наличии сети
  Future<String?> togglePin(int entryId) async {
    final current = state.value;
    if (current == null) return 'Ошибка';
    final username = _username;

    final entry = current.poems.firstWhere((p) => p.id == entryId,
        orElse: () => throw Exception('not found'));
    final newPinned = !entry.isPinned;

    // Проверяем лимит офлайн
    if (newPinned) {
      final count = current.poems.where((p) => p.isPinned).length;
      if (count >= 3) {
        return 'Максимум 3 закреплённых стиха. Открепите один из уже закреплённых.';
      }
    }

    // Оптимистичное обновление UI
    final updated = current.poems.map((p) {
      if (p.id == entryId) return p.copyWith(isPinned: newPinned);
      return p;
    }).toList();
    state = AsyncValue.data(current.copyWith(poems: updated));

    // Локальный кеш
    if (username != null) {
      await _db.setLibraryPoemPinned(username, entryId, newPinned);
    }

    // Сервер
    if (await _sync.isOnline()) {
      try {
        final res = await _api.toggleLibraryPoemPin(entryId);
        if (res == null) return 'Ошибка';
        if (res['error'] != null) {
          // Откатываем
          final rolled = current.poems.map((p) {
            if (p.id == entryId) return p.copyWith(isPinned: !newPinned);
            return p;
          }).toList();
          state = AsyncValue.data(current.copyWith(poems: rolled));
          if (username != null) {
            await _db.setLibraryPoemPinned(username, entryId, !newPinned);
          }
          return res['error'] as String;
        }
      } catch (e) {
        debugPrint('[MyLibrary] togglePin sync: $e');
        await _db.addToSyncQueue('library_toggle_pin', '{"entry_id":$entryId}');
      }
    } else {
      await _db.addToSyncQueue('library_toggle_pin', '{"entry_id":$entryId}');
    }
    return null;
  }

  Future<String?> updateInfo(String name, String description) async {
    try {
      final err = await _api.updateMyLibrary(name, description);
      if (err == null) await reload();
      return err;
    } catch (e) {
      debugPrint('[MyLibrary] updateInfo: $e');
      return 'Ошибка: $e';
    }
  }

  Future<({String? error, String? status})> publish() async {
    try {
      final result = await _api.publishLibrary();
      if (result.error == null) await reload();
      return result;
    } catch (e) {
      debugPrint('[MyLibrary] publish: $e');
      return (error: 'Ошибка: $e', status: null);
    }
  }

  Future<String?> unpublish() async {
    try {
      final err = await _api.unpublishLibrary();
      if (err == null) await reload();
      return err;
    } catch (e) {
      debugPrint('[MyLibrary] unpublish: $e');
      return 'Ошибка: $e';
    }
  }

  Future<String?> deleteLibrary() async {
    try {
      final err = await _api.deleteMyLibrary();
      if (err == null) {
        final username = _username;
        if (username != null) {
          final d = await _db.db;
          await d.delete('local_library',
              where: 'username=?', whereArgs: [username]);
          await d.delete('local_library_poems',
              where: 'username=?', whereArgs: [username]);
        }
        await reload();
      }
      return err;
    } catch (e) {
      debugPrint('[MyLibrary] deleteLibrary: $e');
      return 'Ошибка: $e';
    }
  }

  List<LibraryPoem> sorted({
    required LibrarySortBy sortBy,
    required SortDir dir,
  }) {
    var poems = List<LibraryPoem>.from(state.value?.poems ?? []);
    if (sortBy == LibrarySortBy.read) {
      poems = poems.where((p) => p.isRead).toList();
    } else if (sortBy == LibrarySortBy.unread) {
      poems = poems.where((p) => !p.isRead).toList();
    }
    final pinned = poems.where((p) => p.isPinned).toList();
    var rest = poems.where((p) => !p.isPinned).toList();
    int Function(LibraryPoem, LibraryPoem) cmp;
    switch (sortBy) {
      case LibrarySortBy.title:
        cmp = (a, b) => a.title.compareTo(b.title);
      case LibrarySortBy.author:
        cmp = (a, b) => a.author.compareTo(b.author);
      case LibrarySortBy.length:
        cmp = (a, b) => a.lineCount.compareTo(b.lineCount);
      default:
        cmp = (a, b) => a.id.compareTo(b.id);
    }
    rest.sort(cmp);
    if (dir == SortDir.desc &&
        sortBy != LibrarySortBy.read &&
        sortBy != LibrarySortBy.unread) {
      rest = rest.reversed.toList();
    }
    return [...pinned, ...rest];
  }
}
