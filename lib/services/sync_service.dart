import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'api_service.dart';
import '../models/poem.dart';

enum SyncResult { success, offline, error }

class SyncService {
  static final SyncService _i = SyncService._();
  factory SyncService() => _i;
  SyncService._();

  final _db = DatabaseService();
  final _api = ApiService();

  Future<bool> isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none);
  }

  Future<SyncResult> syncPoems() async {
    if (!await isOnline()) return SyncResult.offline;
    try {
      final raw = await _api.fetchPoems();
      if (raw == null) return SyncResult.error;
      await _db.upsertPoems(raw.map(Poem.fromJson).toList());
      return SyncResult.success;
    } catch (_) {
      return SyncResult.error;
    }
  }

  Future<void> flushQueue(String username) async {
    if (!await isOnline()) return;
    for (final item in await _db.getSyncQueue()) {
      final id = item['id'] as int;
      final action = item['action'] as String;
      final payload =
          jsonDecode(item['payload'] as String) as Map<String, dynamic>;
      bool ok = false;
      try {
        switch (action) {
          case 'toggle_read':
            ok = await _api.toggleRead(payload['title'] as String);
          case 'toggle_pin':
            final r = await _api.togglePin(payload['title'] as String);
            ok = r != null;
          case 'update_profile':
            ok = await _api.updateProfile(
              newPassword: payload['new_password'] as String?,
              userData: payload['user_data'] as String?,
              showAllTab: payload['show_all_tab'] as bool?,
            );
        }
      } catch (_) {}
      if (ok) await _db.removeSyncQueueItem(id);
    }
  }

  Future<SyncResult> fullSync(String username) async {
    if (!await isOnline()) return SyncResult.offline;
    await flushQueue(username);
    return syncPoems();
  }
}
