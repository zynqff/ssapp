import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  final _api = ApiService();
  final _db = DatabaseService();
  final _sync = SyncService();

  final _googleSignIn = GoogleSignIn(scopes: ['email']);

  // ── Инициализация — проверяем сохранённый JWT ─────────────────────────────

  Future<void> _init() async {
    final token = await _api.getToken();
    if (token == null) {
      state = const AsyncValue.data(null);
      return;
    }

    // Читаем username из JWT payload (без верификации — верификация на сервере)
    final cached = _userFromToken(token);
    if (cached != null) {
      // Показываем кешированного пользователя мгновенно
      final readPoems = await _db.getReadPoems(cached.username);
      final pinned = await _db.getPinnedPoem(cached.username);
      state = AsyncValue.data(cached.copyWith(
        readPoems: readPoems,
        pinnedPoemId: pinned,
      ));
      // Обновляем с сервера в фоне
      _backgroundRefresh(cached.username);
    } else {
      await _refreshFromServer();
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
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshFromServer() async {
    final data = await _api.getMe();
    if (data == null) {
      // Токен протух или сервер недоступен
      await _api.clearToken();
      if (mounted) state = const AsyncValue.data(null);
      return;
    }
    final user = User.fromJson(data);
    await _db.setReadPoems(user.username, user.readPoems);
    if (mounted) state = AsyncValue.data(user);
    _backgroundSync(user.username);
  }

  Future<void> _backgroundRefresh(String username) async {
    try {
      final data = await _api.getMe();
      if (data != null) {
        final user = User.fromJson(data);
        await _db.setReadPoems(user.username, user.readPoems);
        if (mounted) state = AsyncValue.data(user);
      }
      await _sync.syncPoems();
    } catch (_) {}
  }

  Future<void> _backgroundSync(String username) async {
    try {
      await _sync.fullSync(username);
    } catch (_) {}
  }

  Future<String?> _afterLogin() async {
    final data = await _api.getMe();
    if (data == null) {
      await _api.clearToken();
      if (mounted) state = const AsyncValue.data(null);
      return 'Не удалось загрузить профиль. Проверьте интернет.';
    }
    final user = User.fromJson(data);
    await _db.setReadPoems(user.username, user.readPoems);
    if (mounted) state = AsyncValue.data(user);
    _backgroundSync(user.username);
    return null;
  }

  // ── OTP: отправить код ────────────────────────────────────────────────────

  /// Вход — отправить OTP на email/username
  Future<String?> sendLoginOtp(String emailOrUsername) async {
    final email = await _api.resolveEmail(emailOrUsername);
    if (email == null) return 'Пользователь не найден';
    return _api.sendOtp(email, isNew: false);
  }

  /// Регистрация — отправить OTP на email
  Future<String?> sendRegisterOtp(String email, String username) async {
    return _api.sendOtp(email, username: username, isNew: true);
  }

  // ── OTP: подтвердить код ──────────────────────────────────────────────────

  /// Подтвердить код для входа
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

  /// Подтвердить код для регистрации
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
      state = const AsyncValue.data(null);
      return 'Ошибка Google входа: $e';
    }
  }

  // ── Выход ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final username = state.value?.username;
    await _api.clearToken();
    await _googleSignIn.signOut();
    if (username != null) await _db.clearChatHistory(username);
    state = const AsyncValue.data(null);
  }

  // ── Toggle read ───────────────────────────────────────────────────────────

  Future<void> toggleRead(int poemId) async {
    final user = state.value;
    if (user == null) return;

    final localAction = await _db.toggleReadPoem(user.username, poemId);
    final newList = List<int>.from(user.readPoems);
    localAction == 'marked' ? newList.add(poemId) : newList.remove(poemId);
    state = AsyncValue.data(user.copyWith(readPoems: newList));

    if (await _sync.isOnline()) {
      final action = await _api.toggleRead(poemId);
      if (action == null) {
        await _db.addToSyncQueue('toggle_read', '{"poem_id":$poemId}');
      }
    } else {
      await _db.addToSyncQueue('toggle_read', '{"poem_id":$poemId}');
    }
  }

  // ── Toggle pin ────────────────────────────────────────────────────────────

  Future<void> togglePin(int poemId) async {
    final user = state.value;
    if (user == null) return;

    final localAction = await _db.togglePinnedPoem(user.username, poemId);
    final newPinned = localAction == 'pinned' ? poemId : null;
    state = AsyncValue.data(user.copyWith(
      pinnedPoemId: newPinned,
      clearPinned: newPinned == null,
    ));

    if (await _sync.isOnline()) {
      final result = await _api.togglePin(poemId);
      if (result.action == null) {
        await _db.addToSyncQueue('toggle_pin', '{"poem_id":$poemId}');
      }
    } else {
      await _db.addToSyncQueue('toggle_pin', '{"poem_id":$poemId}');
    }
  }

  // ── Обновление профиля ────────────────────────────────────────────────────

  Future<String?> updateProfile({String? userData, bool? showAllTab}) async {
    final user = state.value;
    if (user == null) return 'Не авторизован';

    final error = await _api.updateProfile(
        userData: userData, showAllTab: showAllTab);
    if (error != null) return error;

    state = AsyncValue.data(user.copyWith(
      userData: userData ?? user.userData,
      showAllTab: showAllTab ?? user.showAllTab,
    ));
    return null;
  }

  // ── Смена никнейма ────────────────────────────────────────────────────────

  Future<String?> changeUsername(String newUsername) async {
    final user = state.value;
    if (user == null) return 'Не авторизован';

    final trimmed = newUsername.trim();
    if (trimmed.isEmpty) return 'Никнейм не может быть пустым';
    if (trimmed.length < 2) return 'Никнейм слишком короткий';
    if (trimmed == user.username) return 'Это уже ваш никнейм';

    final result = await _api.changeUsername(trimmed);
    if (result.error != null) return result.error;

    await _db.migrateUsername(user.username, trimmed);

    state = AsyncValue.data(User(
      username: trimmed,
      isAdmin: user.isAdmin,
      readPoems: user.readPoems,
      pinnedPoemId: user.pinnedPoemId,
      showAllTab: user.showAllTab,
      userData: user.userData,
    ));
    return null;
  }

  // ── Смена email (двухэтапная) ─────────────────────────────────────────────

  Future<String?> requestEmailChange(String newEmail) async {
    if (state.value == null) return 'Не авторизован';
    return _api.requestEmailChange(newEmail);
  }

  Future<String?> confirmOldEmailCode(String code) async {
    if (state.value == null) return 'Не авторизован';
    return _api.confirmOldEmailCode(code);
  }

  Future<String?> confirmNewEmailCode(String newEmail, String code) async {
    if (state.value == null) return 'Не авторизован';
    return _api.confirmNewEmailCode(newEmail, code);
  }

  // ── Псевдонимы для login_screen ───────────────────────────────────────────

  Future<String?> resolveEmail(String usernameOrEmail) =>
      _api.resolveEmail(usernameOrEmail);

  Future<String?> sendOtp(String email, {String? username}) {
    if (username != null) return sendRegisterOtp(email, username);
    return _api.sendOtp(email, isNew: false);
  }

  Future<String?> verifyOtp(String email, String code, {String? username}) {
    if (username != null) return verifyRegisterOtp(email, code, username);
    return verifyLoginOtp(email, code);
  }
}
