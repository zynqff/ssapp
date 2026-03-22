import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  final _supabase = Supabase.instance.client;
  final _db = DatabaseService();
  final _sync = SyncService();

  final _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: const String.fromEnvironment('GOOGLE_CLIENT_ID'),
  );

  Future<void> _init() async {
    // Слушаем изменения сессии Supabase
    _supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session == null) {
        state = const AsyncValue.data(null);
      } else {
        await _loadUser(session.user, isFirstTime: false);
      }
    });

    // Проверяем текущую сессию
    final session = _supabase.auth.currentSession;
    if (session == null) {
      state = const AsyncValue.data(null);
      return;
    }

    final hasLocal = await _db.hasPoems();
    if (hasLocal) {
      // Есть локальные данные — показываем сразу, синхронизируем в фоне
      final user = await _loadUserFromLocal(session.user);
      if (user != null) {
        state = AsyncValue.data(user);
        _backgroundSync(user.username);
        return;
      }
    }

    await _loadUser(session.user, isFirstTime: true);
  }

  Future<void> _loadUser(User session, {bool isFirstTime = false}) async {
    try {
      final data = await _supabase
          .from('user')
          .select()
          .eq('supabase_uid', session.id)
          .single();

      final user = _userFromRow(data);
      await _db.setReadPoems(user.username, user.readPoems);
      if (mounted) state = AsyncValue.data(user);
      _backgroundSync(user.username);
    } catch (e) {
      if (isFirstTime) {
        if (mounted) {
          state = AsyncValue.error(
            'Ошибка загрузки профиля. Проверьте интернет.',
            StackTrace.current,
          );
        }
      } else {
        // Не первый запуск — пробуем локальные данные
        final user = await _loadUserFromLocal(session);
        if (user != null && mounted) state = AsyncValue.data(user);
      }
    }
  }

  Future<User?> _loadUserFromLocal(User supabaseUser) async {
    // Пробуем найти username по uid в локальной БД
    // Если нет — возвращаем null
    try {
      final data = await _supabase
          .from('user')
          .select('username, is_admin, read_poems_json, pinned_poem_id, show_all_tab, user_data')
          .eq('supabase_uid', supabaseUser.id)
          .single();
      final username = data['username'] as String;
      final readPoems = await _db.getReadPoems(username);
      final pinned = await _db.getPinnedPoem(username);
      return User(
        username: username,
        isAdmin: data['is_admin'] as bool? ?? false,
        readPoems: readPoems,
        pinnedPoemId: pinned,
        showAllTab: data['show_all_tab'] as bool? ?? false,
        userData: data['user_data'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  User _userFromRow(Map<String, dynamic> row) {
    final reads = (row['read_poems_json'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList();
    return User(
      username: row['username'] as String,
      isAdmin: row['is_admin'] as bool? ?? false,
      readPoems: reads,
      pinnedPoemId: (row['pinned_poem_id'] as num?)?.toInt(),
      showAllTab: row['show_all_tab'] as bool? ?? false,
      userData: row['user_data'] as String? ?? '',
    );
  }

  Future<void> _backgroundSync(String username) async {
    try {
      await _sync.fullSync(username);
      // Обновляем read/pin из Supabase
      final session = _supabase.auth.currentSession;
      if (session == null) return;
      final data = await _supabase
          .from('user')
          .select()
          .eq('supabase_uid', session.user.id)
          .single();
      final user = _userFromRow(data);
      await _db.setReadPoems(user.username, user.readPoems);
      if (mounted && state.value != null) {
        state = AsyncValue.data(user);
      }
    } catch (_) {}
  }

  // ── Вход по email/паролю ───────────────────────────────────────────────────

  Future<String?> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // _init слушает onAuthStateChange — state обновится автоматически
      return null;
    } on AuthException catch (e) {
      state = const AsyncValue.data(null);
      return e.message;
    } catch (e) {
      state = const AsyncValue.data(null);
      return 'Ошибка входа';
    }
  }

  // ── Регистрация ────────────────────────────────────────────────────────────

  Future<String?> register(String email, String password, String username) async {
    if (password.length < 8) return 'Пароль не менее 8 символов';
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username}, // триггер handle_new_user использует это
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Ошибка регистрации';
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  Future<String?> loginWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return 'Вход отменён';
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return 'Не удалось получить токен Google';

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Ошибка Google входа: $e';
    }
  }

  // ── Выход ──────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final username = state.value?.username;
    await _supabase.auth.signOut();
    await _googleSignIn.signOut();
    if (username != null) await _db.clearChatHistory(username);
    state = const AsyncValue.data(null);
  }

  // ── Toggle read ────────────────────────────────────────────────────────────

  Future<void> toggleRead(int poemId) async {
    final user = state.value;
    if (user == null) return;

    // Оптимистичное обновление UI
    final action = await _db.toggleReadPoem(user.username, poemId);
    final newList = List<int>.from(user.readPoems);
    action == 'marked' ? newList.add(poemId) : newList.remove(poemId);
    state = AsyncValue.data(user.copyWith(readPoems: newList));

    // Синхронизируем с Supabase
    if (await _sync.isOnline()) {
      try {
        await _supabase
            .from('user')
            .update({'read_poems_json': newList})
            .eq('supabase_uid', _supabase.auth.currentUser!.id);
      } catch (_) {
        await _db.addToSyncQueue('toggle_read', jsonEncode({'poem_id': poemId}));
      }
    } else {
      await _db.addToSyncQueue('toggle_read', jsonEncode({'poem_id': poemId}));
    }
  }

  // ── Toggle pin ─────────────────────────────────────────────────────────────

  Future<void> togglePin(int poemId) async {
    final user = state.value;
    if (user == null) return;

    final action = await _db.togglePinnedPoem(user.username, poemId);
    final newPinned = action == 'pinned' ? poemId : null;
    state = AsyncValue.data(user.copyWith(
      pinnedPoemId: newPinned,
      clearPinned: newPinned == null,
    ));

    if (await _sync.isOnline()) {
      try {
        await _supabase
            .from('user')
            .update({'pinned_poem_id': newPinned})
            .eq('supabase_uid', _supabase.auth.currentUser!.id);
      } catch (_) {
        await _db.addToSyncQueue('toggle_pin', jsonEncode({'poem_id': poemId}));
      }
    } else {
      await _db.addToSyncQueue('toggle_pin', jsonEncode({'poem_id': poemId}));
    }
  }

  // ── Обновление профиля ─────────────────────────────────────────────────────

  Future<String?> updateProfile({
    String? newPassword,
    String? userData,
    bool? showAllTab,
  }) async {
    final user = state.value;
    if (user == null) return 'Не авторизован';

    try {
      // Смена пароля через Supabase Auth
      if (newPassword != null) {
        await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      }

      // Обновление данных профиля напрямую в таблицу
      final updates = <String, dynamic>{};
      if (userData != null) updates['user_data'] = userData;
      if (showAllTab != null) updates['show_all_tab'] = showAllTab;

      if (updates.isNotEmpty) {
        await _supabase
            .from('user')
            .update(updates)
            .eq('supabase_uid', _supabase.auth.currentUser!.id);
      }

      state = AsyncValue.data(user.copyWith(
        userData: userData ?? user.userData,
        showAllTab: showAllTab ?? user.showAllTab,
      ));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Ошибка обновления';
    }
  }
}
