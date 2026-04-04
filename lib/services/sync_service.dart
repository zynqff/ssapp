import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
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
      final rows = await _api.fetchPoems();
      if (rows == null) {
        debugPrint('[SyncService] Не удалось загрузить стихи с сервера');
        return SyncResult.error;
      }
      final poems = rows.map((r) => Poem.fromJson(r)).toList();
      await _db.upsertPoems(poems);
      return SyncResult.success;
    } catch (e) {
      debugPrint('[SyncService] Ошибка syncPoems: $e');
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
            final poemId = (payload['poem_id'] as num).toInt();
            final result = await _api.toggleRead(poemId);
            ok = result != null;
          case 'toggle_pin':
            final poemId = (payload['poem_id'] as num).toInt();
            final result = await _api.togglePin(poemId);
            ok = result.action != null;
          case 'update_profile':
            final error = await _api.updateProfile(
              userData: payload['user_data'] as String?,
              showAllTab: payload['show_all_tab'] as bool?,
            );
            ok = error == null;
        }
      } catch (e) {
        debugPrint('[SyncService] Ошибка обработки очереди ($action): $e');
      }
      if (ok) await _db.removeSyncQueueItem(id);
    }
  }

  Future<SyncResult> fullSync(String username) async {
    if (!await isOnline()) return SyncResult.offline;
    await flushQueue(username);
    return syncPoems();
  }
}
