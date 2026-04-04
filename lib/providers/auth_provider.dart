import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

part 'auth_provider.g.dart';

// ── Провайдеры сервисов ───────────────────────────────────────────────────────

@riverpod
ApiService apiService(ApiServiceRef ref) => ApiService();

@riverpod
DatabaseService dbService(DbServiceRef ref) => DatabaseService();

@riverpod
SyncService syncService(SyncServiceRef ref) => SyncService();

// ── 1. Auth — вход / выход / инициализация ────────────────────────────────────

@riverpod
class Auth extends _$Auth {
  ApiService get _api => ref.read(apiServiceProvider);
  DatabaseService get _db => ref.read(dbServiceProvider);
  SyncService get _sync => ref.read(syncServiceProvider);

  final _googleSignIn = GoogleSignIn(scopes: ['email']);

  @override
  Future<User?> build() async {
    return _init();
  }

  Future<User?> _init() async {
    try {
      final token = await _api.getToken();
      if (token == null) return null;

      final cached = _userFromToken(token);
      if (cached != null) {
        final readPoems = await _db.getReadPoems(cached.username);
        final pinned = await _db.getPinnedPoem(cached.username);
        Future.microtask(() => _backgroundRefresh(cached.username));
        return cached.copyWith(readPoems: readPoems, pinnedPoemId: pinned);
      }
      return _refreshFromServer();
    } catch (e) {
      debugPrint('[Auth] Ошибка инициализации: $e');
      return null;
    }
  }

  User? _userFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final username = payload['sub'] as String?;
      final isAdmin = payload['is_admin'] as bool? ?? false;
      if (username == null) return null;
      return User(username: username, isAdmin: isAdmin);
    } catch (e) {
      debugPrint('[Auth] Ошибка декодирования токена: $e');
      return null;
    }
  }

  Future<User?> _refreshFromServer() async {
    try {
      final data = await _api.getMe();
      if (data == null) {
        await _api.clearTokens();
        return null;
      }
      final user = User.fromJson(data);
      await _db.setReadPoems(user.username, user.readPoems);
      _backgroundSync(user.username);
      return user;
    } catch (e) {
      debugPrint('[Auth] Ошибка обновления с сервера: $e');
      return null;
    }
  }

  Future<void> _backgroundRefresh(String username) async {
    try {
      final data = await _api.getMe();
      if (data == null) {
        await _api.clearTokens();
        if (mounted) state = const AsyncValue.data(null);
        return;
      }
      final user = User.fromJson(data);
      await _db.setReadPoems(user.username, user.readPoems);
      if (mounted) state = AsyncValue.data(user);
      await _sync.syncPoems();
    } catch (e) {
      debugPrint('[Auth] Ошибка фонового обновления: $e');
    }
  }

  Future<void> _backgroundSync(String username) async {
    try {
      await _sync.fullSync(username);
    } catch (e) {
      debugPrint('[Auth] Ошибка фоновой синхронизации: $e');
    }
  }

  Future<String?> _afterLogin() async {
    try {
      final data = await _api.getMe();
      if (data == null) {
        await _api.clearTokens();
        if (mounted) state = const AsyncValue.data(null);
        return 'Не удалось загрузить профиль. Проверьте интернет.';
      }
      final user = User.fromJson(data);
      await _db.setReadPoems(user.username, user.readPoems);
      if (mounted) state = AsyncValue.data(user);
      _backgroundSync(user.username);
      return null;
    } catch (e) {
      debugPrint('[Auth] Ошибка после логина: $e');
      return 'Ошибка загрузки профиля: $e';
    }
  }

  // ── OTP ───────────────────────────────────────────────────────────────────

  Future<String?> sendLoginOtp(String emailOrUsername) async {
    final email = await _api.resolveEmail(emailOrUsername);
    if (email == null) return 'Пользователь не найден';
    return _api.sendOtp(email, isNew: false);
  }

  Future<String?> sendRegisterOtp(String email, String username) async {
    return _api.sendOtp(email, username: username, isNew: true);
  }

  Future<String?> verifyLoginOtp(String emailOrUsername, String code) async {
    state = const AsyncValue.loading();
    final email = await _api.resolveEmail(emailOrUsername);
    if (email == null) {
      state = const AsyncValue.data(null);
      return 'Пользователь не найден';
    }
    final result = await _api.verifyOtp(email, code);
    if (result.error != null) {
      state = const AsyncValue.data(null);
      return result.error;
    }
    return _afterLogin();
  }

  Future<String?> verifyRegisterOtp(
      String email, String code, String username) async {
    state = const AsyncValue.loading();
    final result = await _api.registerOtp(email, code, username);
    if (result.error != null) {
      state = const AsyncValue.data(null);
      return result.error;
    }
    return _afterLogin();
  }

  // ── Google ────────────────────────────────────────────────────────────────

  Future<String?> loginWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return 'Вход отменён';
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return 'Не удалось получить токен Google';
      state = const AsyncValue.loading();
      final result = await _api.googleMobileAuth(idToken);
      if (result.error != null) {
        state = const AsyncValue.data(null);
        return result.error;
      }
      return _afterLogin();
    } catch (e) {
      debugPrint('[Auth] Ошибка Google входа: $e');
      state = const AsyncValue.data(null);
      return 'Ошибка Google входа: $e';
    }
  }

  // ── Выход ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      final username = state.value?.username;
      await _api.clearTokens();
      await _googleSignIn.signOut();
      if (username != null) await _db.clearChatHistory(username);
      state = const AsyncValue.data(null);
    } catch (e) {
      debugPrint('[Auth] Ошибка выхода: $e');
      state = const AsyncValue.data(null);
    }
  }

  // ── Псевдонимы для login_screen ───────────────────────────────────────────

  Future<String?> resolveEmail(String v) => _api.resolveEmail(v);
  Future<String?> sendOtp(String email, {String? username}) =>
      username != null ? sendRegisterOtp(email, username) : _api.sendOtp(email, isNew: false);
  Future<String?> verifyOtp(String email, String code, {String? username}) =>
      username != null ? verifyRegisterOtp(email, code, username) : verifyLoginOtp(email, code);
}

// ── 2. UserProfile — профиль, никнейм, email ─────────────────────────────────

@riverpod
class UserProfile extends _$UserProfile {
  ApiService get _api => ref.read(apiServiceProvider);
  DatabaseService get _db => ref.read(dbServiceProvider);

  @override
  void build() {}

  User? get _user => ref.read(authProvider).value;
  void _updateAuth(User u) =>
      ref.read(authProvider.notifier).state = AsyncValue.data(u);

  Future<String?> updateProfile({String? userData, bool? showAllTab}) async {
    final user = _user;
    if (user == null) return 'Не авторизован';
    try {
      final err = await _api.updateProfile(userData: userData, showAllTab: showAllTab);
      if (err != null) return err;
      _updateAuth(user.copyWith(
        userData: userData ?? user.userData,
        showAllTab: showAllTab ?? user.showAllTab,
      ));
      return null;
    } catch (e) {
      debugPrint('[UserProfile] Ошибка updateProfile: $e');
      return 'Ошибка: $e';
    }
  }

  Future<String?> changeUsername(String newUsername) async {
    final user = _user;
    if (user == null) return 'Не авторизован';
    final trimmed = newUsername.trim();
    if (trimmed.isEmpty) return 'Никнейм не может быть пустым';
    if (trimmed.length < 2) return 'Никнейм слишком короткий';
    if (trimmed == user.username) return 'Это уже ваш никнейм';
    try {
      final result = await _api.changeUsername(trimmed);
      if (result.error != null) return result.error;
      await _db.migrateUsername(user.username, trimmed);
      _updateAuth(User(
        username: trimmed,
        isAdmin: user.isAdmin,
        readPoems: user.readPoems,
        pinnedPoemId: user.pinnedPoemId,
        showAllTab: user.showAllTab,
        userData: user.userData,
      ));
      return null;
    } catch (e) {
      debugPrint('[UserProfile] Ошибка changeUsername: $e');
      return 'Ошибка: $e';
    }
  }

  Future<String?> requestEmailChange(String newEmail) async {
    if (_user == null) return 'Не авторизован';
    try { return await _api.requestEmailChange(newEmail); }
    catch (e) { debugPrint('[UserProfile] requestEmailChange: $e'); return 'Ошибка: $e'; }
  }

  Future<String?> confirmOldEmailCode(String code) async {
    if (_user == null) return 'Не авторизован';
    try { return await _api.confirmOldEmailCode(code); }
    catch (e) { debugPrint('[UserProfile] confirmOldEmailCode: $e'); return 'Ошибка: $e'; }
  }

  Future<String?> confirmNewEmailCode(String newEmail, String code) async {
    if (_user == null) return 'Не авторизован';
    try { return await _api.confirmNewEmailCode(newEmail, code); }
    catch (e) { debugPrint('[UserProfile] confirmNewEmailCode: $e'); return 'Ошибка: $e'; }
  }
}

// ── 3. ReadingProgress — toggleRead / togglePin ───────────────────────────────

@riverpod
class ReadingProgress extends _$ReadingProgress {
  ApiService get _api => ref.read(apiServiceProvider);
  DatabaseService get _db => ref.read(dbServiceProvider);
  SyncService get _sync => ref.read(syncServiceProvider);

  @override
  void build() {}

  User? get _user => ref.read(authProvider).value;
  void _updateAuth(User u) =>
      ref.read(authProvider.notifier).state = AsyncValue.data(u);

  Future<void> toggleRead(int poemId) async {
    final user = _user;
    if (user == null) return;
    try {
      final localAction = await _db.toggleReadPoem(user.username, poemId);
      final newList = List<int>.from(user.readPoems);
      localAction == 'marked' ? newList.add(poemId) : newList.remove(poemId);
      _updateAuth(user.copyWith(readPoems: newList));
      if (await _sync.isOnline()) {
        final action = await _api.toggleRead(poemId);
        if (action == null) await _db.addToSyncQueue('toggle_read', '{"poem_id":$poemId}');
      } else {
        await _db.addToSyncQueue('toggle_read', '{"poem_id":$poemId}');
      }
    } catch (e) {
      debugPrint('[ReadingProgress] toggleRead: $e');
    }
  }

  Future<void> togglePin(int poemId) async {
    final user = _user;
    if (user == null) return;
    try {
      final localAction = await _db.togglePinnedPoem(user.username, poemId);
      final newPinned = localAction == 'pinned' ? poemId : null;
      _updateAuth(user.copyWith(pinnedPoemId: newPinned, clearPinned: newPinned == null));
      if (await _sync.isOnline()) {
        final result = await _api.togglePin(poemId);
        if (result.action == null) await _db.addToSyncQueue('toggle_pin', '{"poem_id":$poemId}');
      } else {
        await _db.addToSyncQueue('toggle_pin', '{"poem_id":$poemId}');
      }
    } catch (e) {
      debugPrint('[ReadingProgress] togglePin: $e');
    }
  }
}
