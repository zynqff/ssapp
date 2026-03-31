// lib/providers/library_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/library.dart';
import '../services/api_service.dart';

final myLibraryProvider =
    StateNotifierProvider<MyLibraryNotifier, AsyncValue<LibraryState?>>((ref) {
  return MyLibraryNotifier();
});

class MyLibraryNotifier extends StateNotifier<AsyncValue<LibraryState?>> {
  MyLibraryNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  final _api = ApiService();

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _api.getMyLibrary().timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );
      if (data == null) {
        state = AsyncValue.error(
          'Не удалось загрузить библиотеку. Проверь интернет.',
          StackTrace.current,
        );
        return;
      }
      state = AsyncValue.data(LibraryState.fromJson(data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> addPoem(int poemId) async {
    final err = await _api.addPoemToLibrary(poemId);
    if (err == null) await load();
    return err;
  }

  Future<String?> addCustomPoem({
    required String title,
    required String author,
    required String text,
  }) async {
    final err = await _api.addCustomPoemToLibrary(
        title: title, author: author, text: text);
    if (err == null) await load();
    return err;
  }

  Future<String?> removePoem(int entryId) async {
    final err = await _api.removePoemFromLibrary(entryId);
    if (err == null) await load();
    return err;
  }

  Future<void> removePoems(List<int> entryIds) async {
    for (final id in entryIds) {
      await _api.removePoemFromLibrary(id);
    }
    await load();
  }

  Future<void> toggleRead(int entryId) async {
    final current = state.value;
    if (current == null) return;

    // Оптимистичное обновление
    final updated = current.poems.map((p) {
      if (p.id == entryId) return p.copyWith(isRead: !p.isRead);
      return p;
    }).toList();
    state = AsyncValue.data(current.copyWith(poems: updated));
    await _api.toggleLibraryPoemRead(entryId);
  }

  /// Закрепить/открепить через API (персистентно, макс 3)
  Future<String?> togglePin(int entryId) async {
    final res = await _api.toggleLibraryPoemPin(entryId);
    if (res == null) return 'Ошибка';

    // Если сервер вернул ошибку лимита
    if (res['error'] != null) {
      return res['error'] as String;
    }

    // Оптимистичное обновление
    final current = state.value;
    if (current != null) {
      final isPinned = res['is_pinned'] as bool? ?? false;
      final updated = current.poems.map((p) {
        if (p.id == entryId) return p.copyWith(isPinned: isPinned);
        return p;
      }).toList();
      state = AsyncValue.data(current.copyWith(poems: updated));
    }
    return null;
  }

  Future<String?> updateInfo(String name, String description) async {
    final err = await _api.updateMyLibrary(name, description);
    if (err == null) await load();
    return err;
  }

  Future<({String? error, String? status})> publish() async {
    final result = await _api.publishLibrary();
    if (result.error == null) await load();
    return result;
  }

  Future<String?> deleteLibrary() async {
    final err = await _api.deleteMyLibrary();
    if (err == null) {
      // Перезагружаем — сервер создаст новую пустую библиотеку
      await load();
    }
    return err;
  }

  /// Отсортированный список с закреплёнными наверху
  List<LibraryPoem> sorted({
    required LibrarySortBy sortBy,
    required SortDir dir,
  }) {
    var poems = List<LibraryPoem>.from(state.value?.poems ?? []);

    // Фильтр по прочитанности
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
