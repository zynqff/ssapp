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

  // ── OTP: отправить код ─────────────────────────────────────────────────────

  /// Для входа — просто отправляем OTP на email.
  /// Для регистрации — передаём [username], он сохраняется в data
  /// и используется после верификации.
  Future<String?> sendOtp(String email, {String? username}) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email.trim(),
        data: username != null ? {'username': username} : null,
        shouldCreateUser: username != null, // регистрация создаёт нового юзера
      );
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'Ошибка отправки кода. Проверьте интернет.';
    }
  }

  /// Верифицируем 6-значный код.
  /// Если это регистрация ([username] передан) — создаём запись в таблице user.
  Future<String?> verifyOtp(String email, String token, {String? username}) async {
    state = const AsyncValue.loading();
    try {
      final res = await _supabase.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.email,
      );

      if (res.user == null) {
        state = const AsyncValue.data(null);
        return 'Не удалось подтвердить код';
      }

      final uid = res.user!.id;

      // Регистрация: создаём запись в user если её ещё нет
      if (username != null) {
        final existing = await _fetchUserRow(uid);
        if (existing == null) {
          await _supabase.from('user').insert({
            'supabase_uid': uid,
            'username': username,
            'email': email.trim(),
            'is_admin': false,
            'read_poems_json': [],
            'show_all_tab': false,
            'user_data': '',
          });
        }
      }

      final error = await _loadUserDirect(uid);
      return error;
    } on AuthException catch (e) {
      state = const AsyncValue.data(null);
      return _translateAuthError(e.message);
    } catch (e) {
      state = const AsyncValue.data(null);
      return 'Ошибка подтверждения: $e';
    }
  }

  // ── Резолв username → email ────────────────────────────────────────────────

  Future<String?> resolveEmail(String usernameOrEmail) async {
    if (usernameOrEmail.contains('@')) return usernameOrEmail.trim();
    try {
      final rows = await _supabase
          .from('user')
          .select('email')
          .eq('username', usernameOrEmail.trim())
          .limit(1);
      if (rows.isEmpty) return null;
      return rows.first['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _translateAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid') && m.contains('otp')) return 'Неверный или истёкший код';
    if (m.contains('expired')) return 'Код истёк. Запросите новый.';
    if (m.contains('too many requests')) return 'Слишком много попыток. Попробуйте позже.';
    if (m.contains('user not found')) return 'Пользователь не найден';
    if (m.contains('email not confirmed')) return 'Email не подтверждён';
    return message;
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
    String? userData,
    bool? showAllTab,
  }) async {
    final user = state.value;
    if (user == null) return 'Не авторизован';

    try {
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
    } catch (_) {
      return 'Ошибка обновления';
    }
  }

  // ── Смена никнейма ─────────────────────────────────────────────────────────

  Future<String?> changeUsername(String newUsername) async {
    final user = state.value;
    if (user == null) return 'Не авторизован';

    final trimmed = newUsername.trim();
    if (trimmed.isEmpty) return 'Никнейм не может быть пустым';
    if (trimmed.length < 2) return 'Никнейм слишком короткий';
    if (trimmed == user.username) return 'Это уже ваш никнейм';

    try {
      // Проверяем что никнейм свободен
      final existing = await _supabase
          .from('user')
          .select('username')
          .eq('username', trimmed)
          .limit(1);
      if ((existing as List).isNotEmpty) return 'Этот никнейм уже занят';

      final uid = _supabase.auth.currentUser!.id;

      // Обновляем в таблице user
      await _supabase
          .from('user')
          .update({'username': trimmed})
          .eq('supabase_uid', uid);

      // Обновляем в Supabase Auth user_metadata (на всякий случай)
      await _supabase.auth.updateUser(
        UserAttributes(data: {'username': trimmed}),
      );

      // Обновляем локальное состояние
      state = AsyncValue.data(User(
        username: trimmed,
        isAdmin: user.isAdmin,
        readPoems: user.readPoems,
        pinnedPoemId: user.pinnedPoemId,
        showAllTab: user.showAllTab,
        userData: user.userData,
      ));

      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'Ошибка смены никнейма';
    }
  }

  // ── Смена email (3 шага) ───────────────────────────────────────────────────

  // Шаг 1: запрашиваем смену — Supabase пришлёт OTP на текущий email
  Future<String?> requestEmailChange(String newEmail) async {
    if (state.value == null) return 'Не авторизован';
    try {
      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail.trim()),
      );
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'Ошибка отправки кода';
    }
  }

  // Шаг 2: подтверждаем код со старого email
  // Supabase при updateUser(email) сам управляет OTP потоком —
  // пользователь просто вводит код, который пришёл на старый email,
  // затем Supabase автоматически шлёт код на новый.
  // Мы верифицируем его через verifyOTP с типом emailChange.
  Future<String?> confirmOldEmailCode(String token) async {
    final currentEmail = _supabase.auth.currentUser?.email;
    if (currentEmail == null) return 'Не авторизован';
    try {
      await _supabase.auth.verifyOTP(
        email: currentEmail,
        token: token.trim(),
        type: OtpType.emailChange,
      );
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'Ошибка подтверждения кода';
    }
  }

  // Шаг 3: подтверждаем код с нового email и обновляем таблицу user
  Future<String?> confirmNewEmailCode(String newEmail, String token) async {
    try {
      final res = await _supabase.auth.verifyOTP(
        email: newEmail.trim(),
        token: token.trim(),
        type: OtpType.emailChange,
      );

      if (res.user == null) return 'Не удалось подтвердить код';

      final uid = res.user!.id;

      // Обновляем email в таблице user
      await _supabase
          .from('user')
          .update({'email': newEmail.trim()})
          .eq('supabase_uid', uid);

      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'Ошибка подтверждения кода';
    }
  }
}
