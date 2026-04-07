import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/chat_message.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';

part 'chat_provider.g.dart';

@riverpod
class Chat extends _$Chat {
  DatabaseService get _db => ref.read(dbServiceProvider);
  ApiService get _api => ref.read(apiServiceProvider);

  bool _sending = false;
  bool get isSending => _sending;
  
  late final String _username;

  @override
  Future<List<ChatMessage>> build(String username) async {
    _username = username;
    try {
      return await _db.getChatHistory(username);
    } catch (e) {
      debugPrint('[Chat] Ошибка загрузки истории: $e');
      rethrow;
    }
  }

  Future<String?> send(String prompt) async {
    try {
      if (!await SyncService().isOnline()) return 'AI-чат требует интернета';

      final userMsg = ChatMessage(
        role: 'user',
        content: prompt,
        createdAt: DateTime.now(),
      );
      await _db.saveChatMessage(_username, userMsg);
      state = AsyncValue.data([...?state.value, userMsg]);

      _sending = true;
      final response = await _api.chatWithAI(prompt);
      _sending = false;

      if (response == null) return 'Ошибка при обращении к AI';
      if (response == '__no_access__') return 'Нет доступа к AI. Введите ключ в профиле.';

      final modelMsg = ChatMessage(
        role: 'model',
        content: response,
        createdAt: DateTime.now(),
      );
      await _db.saveChatMessage(_username, modelMsg);
      state = AsyncValue.data([...?state.value, modelMsg]);
      return null;
    } catch (e) {
      _sending = false;
      debugPrint('[Chat] Ошибка отправки: $e');
      return 'Ошибка: $e';
    }
  }

  Future<void> clear() async {
    try {
      await _db.clearChatHistory(_username);
      state = const AsyncValue.data([]);
    } catch (e) {
      debugPrint('[Chat] Ошибка очистки: $e');
    }
  }
}
