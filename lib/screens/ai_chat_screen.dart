import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/config_provider.dart';
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
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
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
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Войдите')));
    }

    final config = ref.watch(configProvider).valueOrNull;
    final aiEnabled = config?.aiEnabled ?? true;

    final msgs = ref.watch(chatProvider(user.username));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outline, width: 0.8),
            ),
            child: Icon(Icons.arrow_back_rounded,
                color: cs.onSurface, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.smart_toy_outlined,
                size: 18, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Text('AI Ассистент',
              style: GoogleFonts.playfairDisplay(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              )),
        ]),
        actions: [
          GestureDetector(
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: cs.surfaceVariant,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  title: Text('Очистить историю?',
                      style: GoogleFonts.playfairDisplay(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Отмена',
                          style: GoogleFonts.notoSerif(
                              color: cs.onSurfaceVariant)),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Очистить',
                          style: GoogleFonts.notoSerif()),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                ref
                    .read(chatProvider(user.username).notifier)
                    .clear();
              }
            },
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: cs.outline, width: 0.8),
              ),
              child: Icon(Icons.delete_outline_rounded,
                  color: cs.onSurface, size: 18),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // AI отключён администратором
        if (!aiEnabled)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            color: cs.onSurfaceVariant.withOpacity(0.08),
            child: Row(children: [
              Icon(Icons.smart_toy_outlined, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('AI чат временно недоступен',
                  style: GoogleFonts.notoSerif(
                      color: cs.onSurfaceVariant, fontSize: 12.5)),
            ]),
          ),

        // Offline banner
        if (_offline)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            color: cs.error.withOpacity(0.1),
            child: Row(children: [
              Icon(Icons.wifi_off_rounded,
                  size: 15, color: cs.error),
              const SizedBox(width: 8),
              Text('Нет интернета — AI недоступен',
                  style: GoogleFonts.notoSerif(
                      color: cs.error, fontSize: 12.5)),
            ]),
          ),

        // Messages
        Expanded(
          child: msgs.when(
            loading: () => Center(
                child: CircularProgressIndicator(color: cs.primary)),
            error: (e, _) => Center(
                child: Text(e.toString(),
                    style: GoogleFonts.notoSerif(
                        color: cs.onSurfaceVariant))),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(Icons.smart_toy_outlined,
                              size: 36, color: cs.primary),
                        ),
                        const SizedBox(height: 16),
                        Text('Спроси что-нибудь о стихах',
                            style: GoogleFonts.notoSerif(
                              color: cs.onSurfaceVariant,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            )),
                      ]),
                );
              }
              _scrollToBottom();
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: list.length + (_sending ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == list.length) return const _TypingBubble();
                  return _Bubble(msg: list[i]);
                },
              );
            },
          ),
        ),

        // Input bar — заблокирован если AI отключён или нет интернета
        _InputBar(
          ctrl: _ctrl,
          sending: _sending,
          disabled: _offline || !aiEnabled,
          onSend: _send,
        ),
      ]),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: isUser
              ? cs.primary
              : cs.surfaceVariant,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: cs.outline, width: 0.8),
        ),
        child: Text(
          msg.content,
          style: GoogleFonts.notoSerif(
            color: isUser ? cs.onPrimary : cs.onSurface,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: cs.outline, width: 0.8),
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
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: cs.primary,
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

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending, disabled;
  final VoidCallback onSend;
  const _InputBar({
    required this.ctrl,
    required this.sending,
    required this.disabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
            top: BorderSide(
                color: cs.outline.withOpacity(0.3), width: 0.8)),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline, width: 0.8),
            ),
            child: TextField(
              controller: ctrl,
              style: GoogleFonts.notoSerif(
                  color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: disabled ? 'AI недоступен' : 'Сообщение...',
                hintStyle: GoogleFonts.notoSerif(
                    color: cs.onSurfaceVariant, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              enabled: !disabled,
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: (sending || disabled) ? null : onSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (sending || disabled)
                  ? cs.primary.withOpacity(0.3)
                  : cs.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: sending
                ? Padding(
                    padding: const EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onPrimary),
                  )
                : Icon(Icons.send_rounded,
                    color: cs.onPrimary, size: 20),
          ),
        ),
      ]),
    );
  }
}
