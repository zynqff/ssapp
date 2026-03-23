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
    _supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session == null) {
        state = const AsyncValue.data(null);
      } else {
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

  // Retry только для Google — триггер может не успеть создать запись
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

  // Без retry — для обычного входа/регистрации (запись точно есть)
  Future<String?> _loadUserDirect(String uid) async {
    final user = await _fetchUserRow(uid);
    if (user != null) {
      await _db.setReadPoems(user.username, user.readPoems);
      if (mounted) state = AsyncValue.data(user);
      _backgroundSync(user.username);
      return null;
    } else {
      if (mounted) state = const AsyncValue.data(null);
      return 'Профиль не найден. Обратитесь в поддержку.';
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

      // signInWithPassword выбросит AuthException если пароль неверный —
      // до этой строки дойдём только при успехе
      final error = await _loadUserDirect(res.user!.id);
      return error;
    } on AuthException catch (e) {
      state = const AsyncValue.data(null);
      // Supabase возвращает английские сообщения — переводим основные
      return _translateAuthError(e.message);
    } catch (_) {
      state = const AsyncValue.data(null);
      return 'Ошибка входа. Проверьте интернет.';
    }
  }

  String _translateAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials') || m.contains('invalid credentials')) {
      return 'Неверный email или пароль';
    }
    if (m.contains('email not confirmed')) {
      return 'Email не подтверждён. Проверьте почту.';
    }
    if (m.contains('too many requests')) {
      return 'Слишком много попыток. Попробуйте позже.';
    }
    if (m.contains('user not found')) {
      return 'Пользователь не найден';
    }
    return message;
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
      final existing = await _supabase
          .from('user')
          .select('username')
          .eq('username', username)
          .limit(1);
      if (existing.isNotEmpty) return 'Имя пользователя уже занято';

      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (res.user == null) return 'Ошибка регистрации';

      if (res.session == null) {
        return 'confirm_email:$email';
      }

      await _supabase.from('user').insert({
        'supabase_uid': res.user!.id,
        'username': username,
        'email': email,
        'is_admin': false,
        'read_poems_json': [],
        'show_all_tab': false,
        'user_data': '',
      });

      final error = await _loadUserDirect(res.user!.id);
      return error;
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (e) {
      return 'Ошибка регистрации: $e';
    }
  }

  // ── Сброс пароля ───────────────────────────────────────────────────────────

  Future<String?> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      return null; // успех
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'Ошибка отправки. Проверьте интернет.';
    }
  }

  // ── Google ─────────────────────────────────────────────────────────────────

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
      return _translateAuthError(e.message);
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
      return _translateAuthError(e.message);
    } catch (_) {
      return 'Ошибка обновления';
    }
  }
}
