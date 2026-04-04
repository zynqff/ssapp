import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/library.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

part 'library_provider.g.dart';

@riverpod
class MyLibrary extends _$MyLibrary {
  ApiService get _api => ref.read(apiServiceProvider);

  @override
  Future<LibraryState?> build() => _load();

  Future<LibraryState?> _load() async {
    try {
      final data = await _api.getMyLibrary().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[MyLibrary] Таймаут загрузки');
          return null;
        },
      );
      if (data == null) throw Exception('Не удалось загрузить библиотеку. Проверь интернет.');
      return LibraryState.fromJson(data);
    } catch (e) {
      debugPrint('[MyLibrary] Ошибка загрузки: $e');
      rethrow;
    }
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
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

  Future<String?> addCustomPoem({required String title, required String author, required String text}) async {
    try {
      final err = await _api.addCustomPoemToLibrary(title: title, author: author, text: text);
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

  Future<void> toggleRead(int entryId) async {
    final current = state.value;
    if (current == null) return;
    try {
      final updated = current.poems.map((p) {
        if (p.id == entryId) return p.copyWith(isRead: !p.isRead);
        return p;
      }).toList();
      state = AsyncValue.data(current.copyWith(poems: updated));
      await _api.toggleLibraryPoemRead(entryId);
    } catch (e) {
      debugPrint('[MyLibrary] toggleRead: $e');
      await reload();
    }
  }

  Future<String?> togglePin(int entryId) async {
    try {
      final res = await _api.toggleLibraryPoemPin(entryId);
      if (res == null) return 'Ошибка';
      if (res['error'] != null) return res['error'] as String;
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
    } catch (e) {
      debugPrint('[MyLibrary] togglePin: $e');
      return 'Ошибка: $e';
    }
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
      if (err == null) await reload();
      return err;
    } catch (e) {
      debugPrint('[MyLibrary] deleteLibrary: $e');
      return 'Ошибка: $e';
    }
  }

  List<LibraryPoem> sorted({required LibrarySortBy sortBy, required SortDir dir}) {
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
      case LibrarySortBy.title:  cmp = (a, b) => a.title.compareTo(b.title);
      case LibrarySortBy.author: cmp = (a, b) => a.author.compareTo(b.author);
      case LibrarySortBy.length: cmp = (a, b) => a.lineCount.compareTo(b.lineCount);
      default:                   cmp = (a, b) => a.id.compareTo(b.id);
    }
    rest.sort(cmp);
    if (dir == SortDir.desc && sortBy != LibrarySortBy.read && sortBy != LibrarySortBy.unread) {
      rest = rest.reversed.toList();
    }
    return [...pinned, ...rest];
  }
}

final myLibraryProvider = myLibraryProvider$;
