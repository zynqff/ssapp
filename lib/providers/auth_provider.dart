import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../services/api_service.dart';
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

  final _api = ApiService();
  final _db = DatabaseService();
  final _sync = SyncService();

  final _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId:
        '72452359173-jbv8l148p17o519264i026kpdtb1vofl.apps.googleusercontent.com',
  );

  Future<void> _init() async {
    if (!await _api.hasToken()) {
      state = const AsyncValue.data(null);
      return;
    }

    final username = await _api.getSavedUsername();
    if (username == null) {
      state = const AsyncValue.data(null);
      return;
    }

    final hasLocal = await _db.hasPoems();

    if (hasLocal) {
      final readPoems = await _db.getReadPoems(username);
      final pinned = await _db.getPinnedPoem(username);
      final isAdmin = await _api.getSavedIsAdmin();
      state = AsyncValue.data(User(
        username: username,
        isAdmin: isAdmin,
        readPoems: readPoems,
        pinnedPoemId: pinned,
      ));
      _backgroundSync(username);
    } else {
      await _loadUserFromServer(username, isFirstTime: true);
    }
  }

  Future<void> _loadUserFromServer(String username,
      {bool isFirstTime = false}) async {
    if (await _sync.isOnline()) {
      final me = await _api.fetchMe();
      if (me != null) {
        final user = User.fromJson(me);
        await _db.setReadPoems(username, user.readPoems);
        state = AsyncValue.data(user);
        _backgroundSync(username);
        return;
      }
    }

    if (isFirstTime) {
      state = AsyncValue.error(
        'Нет подключения к серверу.\nПроверьте интернет и попробуйте снова.',
        StackTrace.current,
      );
      return;
    }

    final readPoems = await _db.getReadPoems(username);
    final pinned = await _db.getPinnedPoem(username);
    final isAdmin = await _api.getSavedIsAdmin();
    state = AsyncValue.data(User(
      username: username,
      isAdmin: isAdmin,
      readPoems: readPoems,
      pinnedPoemId: pinned,
    ));
  }

  Future<void> _backgroundSync(String username) async {
    try {
      await _sync.fullSync(username);
      final me = await _api.fetchMe();
      if (me != null && mounted) {
        final user = User.fromJson(me);
        await _db.setReadPoems(username, user.readPoems);
        if (state.value != null) {
          state = AsyncValue.data(user);
        }
      }
    } catch (_) {}
  }

  Future<String?> login(String username, String password) async {
    state = const AsyncValue.loading();
    final result = await _api.login(username, password);
    if (result.error != null) {
      state = const AsyncValue.data(null);
      return result.error;
    }
    await _loadUserFromServer(username, isFirstTime: true);
    return null;
  }

  Future<String?> loginWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return 'Вход отменён';
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return 'Не удалось получить токен Google';
      final result = await _api.loginWithGoogle(idToken);
      if (result.error != null) return result.error;
      await _loadUserFromServer(result.username, isFirstTime: true);
      return null;
    } catch (e) {
      return 'Ошибка Google входа: $e';
    }
  }

  Future<String?> register(String username, String password) async {
    if (password.length < 4) return 'Пароль не менее 4 символов';
    return _api.register(username, password);
  }

  Future<void> logout() async {
    final username = state.value?.username;
    await _api.logout();
    await _googleSignIn.signOut();
    if (username != null) await _db.clearChatHistory(username);
    state = const AsyncValue.data(null);
  }

  Future<void> toggleRead(int poemId) async {
    final user = state.value;
    if (user == null) return;
    final action = await _db.toggleReadPoem(user.username, poemId);
    final newList = List<int>.from(user.readPoems);
    action == 'marked' ? newList.add(poemId) : newList.remove(poemId);
    state = AsyncValue.data(user.copyWith(readPoems: newList));

    if (await _sync.isOnline()) {
      await _api.toggleRead(poemId);
    } else {
      await _db.addToSyncQueue('toggle_read', jsonEncode({'poem_id': poemId}));
    }
  }

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
      await _api.togglePin(poemId);
    } else {
      await _db.addToSyncQueue('toggle_pin', jsonEncode({'poem_id': poemId}));
    }
  }

  Future<String?> updateProfile(
      {String? newPassword, String? userData, bool? showAllTab}) async {
    final user = state.value;
    if (user == null) return 'Не авторизован';

    if (await _sync.isOnline()) {
      final ok = await _api.updateProfile(
          newPassword: newPassword, userData: userData, showAllTab: showAllTab);
      if (!ok) return 'Ошибка обновления';
    } else {
      await _db.addToSyncQueue('update_profile', jsonEncode({
        if (newPassword != null) 'new_password': newPassword,
        if (userData != null) 'user_data': userData,
        if (showAllTab != null) 'show_all_tab': showAllTab,
      }));
    }

    state = AsyncValue.data(user.copyWith(
      userData: userData ?? user.userData,
      showAllTab: showAllTab ?? user.showAllTab,
    ));
    return null;
  }
}
