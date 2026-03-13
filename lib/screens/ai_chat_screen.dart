import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../services/sync_service.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});
  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    SyncService().isOnline().then((v) {
      if (mounted) setState(() => _offline = !v);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);
    final username = ref.read(authProvider).value?.username ?? '';
    final error =
        await ref.read(chatProvider(username).notifier).send(text);
    if (mounted) {
      setState(() => _sending = false);
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const Scaffold(body: Center(child: Text('Войдите')));
    final msgs = ref.watch(chatProvider(user.username));
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Ассистент'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Очистить историю?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Очистить')),
                  ],
                ),
              );
              if (ok == true) ref.read(chatProvider(user.username).notifier).clear();
            },
          ),
        ],
      ),
      body: Column(children: [
        if (_offline)
          _Banner(
              icon: Icons.wifi_off,
              message: 'Нет интернета — AI недоступен',
              color: t.colorScheme.errorContainer,
              textColor: t.colorScheme.onErrorContainer),

        Expanded(
          child: msgs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.smart_toy_outlined, size: 72,
                        color: t.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text('Спроси что-нибудь о стихах',
                        style: t.textTheme.bodyLarge),
                  ]),
                );
              }
              _scrollToBottom();
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: list.length + (_sending ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == list.length) return const _TypingBubble();
                  return _Bubble(msg: list[i]);
                },
              );
            },
          ),
        ),

        _InputBar(
          ctrl: _ctrl,
          sending: _sending,
          disabled: _offline,
          onSend: _send,
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color, textColor;
  const _Banner({required this.icon, required this.message, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(message, style: TextStyle(color: textColor, fontSize: 13)),
        ]),
      );
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending, disabled;
  final VoidCallback onSend;
  const _InputBar({required this.ctrl, required this.sending, required this.disabled, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
                hintText: 'Сообщение...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            enabled: !disabled,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: (sending || disabled) ? null : onSend,
          child: sending
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    final t = Theme.of(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? t.colorScheme.primary : t.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(msg.content,
            style: TextStyle(
                color: isUser
                    ? t.colorScheme.onPrimary
                    : t.colorScheme.onSecondaryContainer)),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: t.colorScheme.secondaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4),
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
              final opacity = (offset < 0.5 ? offset : 1 - offset) * 2;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Opacity(
                  opacity: opacity.clamp(0.3, 1.0),
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: t.colorScheme.onSecondaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
