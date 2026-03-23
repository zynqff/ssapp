import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
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
    serverClientId: const String.fromEnvironment(
      'GOOGLE_CLIENT_ID',
      defaultValue: '72452359173-jbv8l148p17o519264i026kpdtb1vofl.apps.googleusercontent.com',
    ),
  );

  Future<void> _init() async {
    // onAuthStateChange нужен только для Google (триггер там создаёт запись)
    _supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session == null) {
        state = const AsyncValue.data(null);
      } else {
        // Для Google грузим с retry — триггер может не успеть
        await _loadUserWithRetry(session.user.id);
      }
    });

    final session = _supabase.auth.currentSession;
    if (session == null) {
      state = const AsyncValue.data(null);
      return;
    }

    final hasLocal = await _db.hasPoems();
    if (hasLocal) {
      final user = await _fetchUserRow(session.user.id);
      if (user != null) {
        final readPoems = await _db.getReadPoems(user.username);
        final pinned = await _db.getPinnedPoem(user.username);
        final localUser = user.copyWith(readPoems: readPoems, pinnedPoemId: pinned);
        state = AsyncValue.data(localUser);
        _backgroundSync(user.username);
        return;
      }
    }

    await _loadUserWithRetry(session.user.id);
  }

  Future<User?> _fetchUserRow(String uid) async {
    try {
      final data = await _supabase
          .from('user')
          .select()
          .eq('supabase_uid', uid)
          .single();
      return _userFromRow(data);
    } catch (_) {
      return null;
    }
  }

  // Retry нужен только для Google — триггер может не успеть создать запись
  Future<void> _loadUserWithRetry(String uid) async {
    for (int i = 0; i < 5; i++) {
      final user = await _fetchUserRow(uid);
      if (user != null) {
        await _db.setReadPoems(user.username, user.readPoems);
        if (mounted) state = AsyncValue.data(user);
        _backgroundSync(user.username);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }
    if (mounted) {
      state = AsyncValue.error(
        'Ошибка загрузки профиля. Проверьте интернет.',
        StackTrace.current,
      );
    }
  }

  // Простая загрузка без retry — для обычного входа/регистрации (запись уже точно есть)
  Future<void> _loadUserDirect(String uid) async {
    final user = await _fetchUserRow(uid);
    if (user != null) {
      await _db.setReadPoems(user.username, user.readPoems);
      if (mounted) state = AsyncValue.data(user);
      _backgroundSync(user.username);
    } else {
      if (mounted) {
        state = AsyncValue.error(
          'Профиль не найден. Обратитесь в поддержку.',
          StackTrace.current,
        );
      }
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
      final session = _supabase.auth.currentSession;
      if (session == null) return;
      final user = await _fetchUserRow(session.user.id);
      if (user != null) {
        await _db.setReadPoems(user.username, user.readPoems);
        if (mounted && state.value != null) state = AsyncValue.data(user);
      }
    } catch (_) {}
  }

  // ── Вход ──────────────────────────────────────────────────────────────────

  Future<String?> login(String usernameOrEmail, String password) async {
    state = const AsyncValue.loading();
    try {
      final email = usernameOrEmail.contains('@')
          ? usernameOrEmail
          : await _findEmailByUsername(usernameOrEmail);

      if (email == null) {
        state = const AsyncValue.data(null);
        return 'Пользователь не найден';
      }

      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Запись в public.user точно есть — грузим без retry
      await _loadUserDirect(res.user!.id);
      return null;
    } on AuthException catch (e) {
      state = const AsyncValue.data(null);
      return e.message;
    } catch (_) {
      state = const AsyncValue.data(null);
      return 'Ошибка входа';
    }
  }

  Future<String?> _findEmailByUsername(String username) async {
    try {
      final rows = await _supabase
          .from('user')
          .select('email')
          .eq('username', username)
          .limit(1);
      if (rows.isEmpty) return null;
      return rows.first['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Регистрация ────────────────────────────────────────────────────────────

  Future<String?> register(String email, String password, String username) async {
    if (password.length < 8) return 'Пароль не менее 8 символов';
    try {
      // Проверяем уникальность username
      final existing = await _supabase
          .from('user')
          .select('username')
          .eq('username', username)
          .limit(1);
      if (existing.isNotEmpty) return 'Имя пользователя уже занято';

      // Регистрируем в Supabase Auth
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (res.user == null) return 'Ошибка регистрации';

      // Email confirmation включён — сессии нет, просим подтвердить
      if (res.session == null) {
        return 'confirm_email:$email';
      }

      // Вставляем запись в public.user сами — без триггера
      await _supabase.from('user').insert({
        'supabase_uid': res.user!.id,
        'username': username,
        'email': email,
        'is_admin': false,
        'read_poems_json': [],
        'show_all_tab': false,
        'user_data': '',
      });

      // Грузим юзера напрямую — запись только что создали сами
      await _loadUserDirect(res.user!.id);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Ошибка регистрации: $e';
    }
  }

  // ── Google ─────────────────────────────────────────────────────────────────
  // Google оставляем через триггер — username там не передать

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

      // onAuthStateChange сам вызовет _loadUserWithRetry
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

    final action = await _db.toggleReadPoem(user.username, poemId);
    final newList = List<int>.from(user.readPoems);
    action == 'marked' ? newList.add(poemId) : newList.remove(poemId);
    state = AsyncValue.data(user.copyWith(readPoems: newList));

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
      if (newPassword != null) {
        await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      }

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
    } catch (_) {
      return 'Ошибка обновления';
    }
  }
}
