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
      final data = await _api.getMyLibrary();
      if (data == null) {
        state = const AsyncValue.data(null);
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

  // Сортировка локально
  List<LibraryPoem> sortedPoems({
    required String sortBy, // 'added' | 'author' | 'length' | 'read' | 'unread'
  }) {
    final poems = List<LibraryPoem>.from(state.value?.poems ?? []);
    switch (sortBy) {
      case 'author':
        poems.sort((a, b) => a.author.compareTo(b.author));
      case 'length':
        poems.sort((a, b) => a.lineCount.compareTo(b.lineCount));
      case 'read':
        poems.sort((a, b) {
          if (a.isRead && !b.isRead) return -1;
          if (!a.isRead && b.isRead) return 1;
          return 0;
        });
      case 'unread':
        poems.sort((a, b) {
          if (!a.isRead && b.isRead) return -1;
          if (a.isRead && !b.isRead) return 1;
          return 0;
        });
      default: // 'added' — порядок добавления, уже отсортирован
        break;
    }
    return poems;
  }
}
