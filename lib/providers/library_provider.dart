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

  // Локальные пины (хранятся только в памяти, макс 3)
  final Set<int> _pinnedIds = {};

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
      final libState = LibraryState.fromJson(data);
      // Восстанавливаем пины
      final poems = libState.poems.map((p) =>
        p.copyWith(isPinned: _pinnedIds.contains(p.id))
      ).toList();
      state = AsyncValue.data(libState.copyWith(poems: poems));
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

  /// Удалить одно стихотворение с подтверждением (подтверждение в UI)
  Future<String?> removePoem(int entryId) async {
    final err = await _api.removePoemFromLibrary(entryId);
    if (err == null) {
      _pinnedIds.remove(entryId);
      await load();
    }
    return err;
  }

  /// Удалить несколько стихотворений сразу
  Future<void> removePoems(List<int> entryIds) async {
    for (final id in entryIds) {
      await _api.removePoemFromLibrary(id);
      _pinnedIds.remove(id);
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

  /// Закрепить/открепить стих (локально, макс 3)
  String? togglePin(int entryId) {
    final current = state.value;
    if (current == null) return null;

    final poem = current.poems.firstWhere((p) => p.id == entryId,
        orElse: () => current.poems.first);

    if (poem.isPinned) {
      _pinnedIds.remove(entryId);
    } else {
      if (_pinnedIds.length >= 3) {
        return 'Максимум 3 закреплённых стиха. Открепите один из уже закреплённых.';
      }
      _pinnedIds.add(entryId);
    }

    final updated = current.poems.map((p) =>
      p.copyWith(isPinned: _pinnedIds.contains(p.id))
    ).toList();
    state = AsyncValue.data(current.copyWith(poems: updated));
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

  /// Отсортированный список с закреплёнными наверху
  List<LibraryPoem> sorted({
    required LibrarySortBy sortBy,
    required SortDir dir,
    bool filterRead = false,
    bool filterUnread = false,
  }) {
    var poems = List<LibraryPoem>.from(state.value?.poems ?? []);

    // Фильтр по прочитанности
    if (filterRead) poems = poems.where((p) => p.isRead).toList();
    if (filterUnread) poems = poems.where((p) => !p.isRead).toList();

    final pinned = poems.where((p) => p.isPinned).toList();
    var rest = poems.where((p) => !p.isPinned).toList();

    int Function(LibraryPoem, LibraryPoem) comparator;
    switch (sortBy) {
      case LibrarySortBy.title:
        comparator = (a, b) => a.title.compareTo(b.title);
      case LibrarySortBy.author:
        comparator = (a, b) => a.author.compareTo(b.author);
      case LibrarySortBy.length:
        comparator = (a, b) => a.lineCount.compareTo(b.lineCount);
      case LibrarySortBy.read:
        comparator = (a, b) {
          if (a.isRead && !b.isRead) return -1;
          if (!a.isRead && b.isRead) return 1;
          return 0;
        };
      case LibrarySortBy.unread:
        comparator = (a, b) {
          if (!a.isRead && b.isRead) return -1;
          if (a.isRead && !b.isRead) return 1;
          return 0;
        };
      default:
        comparator = (a, b) => a.id.compareTo(b.id);
    }

    rest.sort(comparator);
    if (dir == SortDir.desc &&
        sortBy != LibrarySortBy.read &&
        sortBy != LibrarySortBy.unread) {
      rest = rest.reversed.toList();
    }

    // Закреплённые всегда наверху
    return [...pinned, ...rest];
  }
}
