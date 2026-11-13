import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/rendering_policy.dart';
import '../../ai/application/ai_cloud.dart';
import '../../ai/domain/ai_provider.dart';
import '../../notes/presentation/note_chat_cards.dart';
import '../../sync/presentation/sync_material.dart';
import '../application/watch_chat_controller.dart';
import '../application/watchlist_providers.dart';
import '../domain/watch_title.dart';
import 'watch_widgets.dart';

/// A first message to send as the chat opens, such as one from the match
/// screen.
class WatchChatOpening {
  const WatchChatOpening(this.text);
  final String text;
}

/// Talking with a film or show, played by the reader's own AI provider.
class WatchChatPage extends ConsumerStatefulWidget {
  const WatchChatPage({super.key, required this.watchKey, this.opening});
  final WatchKey watchKey;
  final String? opening;

  @override
  ConsumerState<WatchChatPage> createState() => _WatchChatPageState();
}

class _WatchChatPageState extends ConsumerState<WatchChatPage> {
  final _message = TextEditingController();

  @override
  void initState() {
    super.initState();
    final opening = widget.opening?.trim() ?? '';
    if (opening.isNotEmpty &&
        ref.read(aiCapabilitiesProvider).contains(AiCapability.chat)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(watchChatProvider(widget.watchKey).notifier).send(opening);
        }
      });
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text;
    if (text.trim().isEmpty) return;
    _message.clear();
    final sent = await ref
        .read(watchChatProvider(widget.watchKey).notifier)
        .send(text);
    if (!sent && mounted && _message.text.isEmpty) _message.text = text;
  }

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    final key = widget.watchKey;
    final available = ref
        .watch(aiCapabilitiesProvider)
        .contains(AiCapability.chat);
    final saved = ref.watch(watchTitleProvider(key.id)).value;
    final cached = ref.watch(catalogTitleProvider(key)).value;
    final name = cached?.title ?? saved?.title ?? '';
    final messages = ref.watch(watchChatMessagesProvider(key.id)).value ?? [];
    final chat = ref.watch(watchChatProvider(key));
    final controller = ref.read(watchChatProvider(key).notifier);
    final unanswered =
        !chat.sending && messages.isNotEmpty && messages.last.fromReader;
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: watchAppBar(
        context,
        title: name,
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear conversation',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final clear = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear this conversation?'),
                    content: const Text('It is only kept on this device.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (clear == true) await controller.clear();
              },
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !available
            ? const WatchMessage(
                title: 'Chat needs the Grand Maestar',
                body:
                    'Set up an AI provider with chat in More, Grand Maestar, '
                    'and titles can talk back.',
              )
            : Column(
                children: [
                  Expanded(
                    child: messages.isEmpty && !chat.sending
                        ? WatchMessage(
                            title: 'Say hello to $name',
                            body:
                                'An AI plays the title, from what TMDB knows '
                                'about it. No spoilers.',
                          )
                        : ListView(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            children: [
                              if (chat.sending) const _Typing(),
                              if (chat.error != null || unanswered)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chat.error ?? 'No reply yet.',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      if (unanswered)
                                        TextButton(
                                          onPressed: controller.retry,
                                          child: const Text('Retry'),
                                        ),
                                    ],
                                  ),
                                ),
                              for (final m in messages.reversed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: NoteChatBubble(
                                    text: m.body,
                                    mine: m.fromReader,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _message,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: watchChatMessageChars,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'Message $name',
                              counterText: '',
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        chat.sending
                            ? IconButton.filledTonal(
                                tooltip: 'Stop',
                                onPressed: controller.stop,
                                icon: const Icon(Icons.stop),
                              )
                            : IconButton.filled(
                                tooltip: 'Send',
                                onPressed: _send,
                                icon: const Icon(Icons.arrow_upward),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    final palette = MorePalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (RenderingPolicyScope.of(context).animate)
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(width: 8),
            Text('typing…', style: TextStyle(color: palette.muted)),
          ],
        ),
      ),
    );
  }
}
