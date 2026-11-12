import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../ai/application/ai_jobs.dart';
import '../../sync/application/sync_providers.dart';
import '../application/note_chat_controller.dart';
import '../application/notes_providers.dart';
import '../domain/note_chat.dart';
import '../domain/note_colors.dart';
import '../domain/note_document.dart';
import 'note_ai_desk.dart';
import 'note_ai_widgets.dart';
import 'note_app_bar.dart';
import 'note_chat_cards.dart';

/// Words to put in the message box when the chat opens, e.g. "Build it
/// again" from a website. Nothing is sent until the person sends it.
class NoteChatDraftMessage {
  const NoteChatDraftMessage(this.text);
  final String text;
}

/// The Maester's conversation about one note: writing help and the note's
/// website in one place. Each change the Maester asks for shows as a card;
/// note text changes only when the person keeps it.
class NoteChatPage extends ConsumerStatefulWidget {
  const NoteChatPage({super.key, required this.id, this.draft = ''});
  final String id;
  final String draft;

  @override
  ConsumerState<NoteChatPage> createState() => _NoteChatPageState();
}

class _NoteChatPageState extends ConsumerState<NoteChatPage> {
  late final _input = TextEditingController(text: widget.draft);
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final message = (text ?? _input.text).trim();
    if (message.isEmpty) return;
    final chat = ref.read(noteChatProvider(widget.id).notifier);
    if (text == null) _input.clear();
    final sent = await chat.send(message);
    // An unanswered message goes back in the box to try again.
    if (!sent && mounted && _input.text.isEmpty && text == null) {
      _input.text = message;
    }
  }

  void _leave() =>
      context.canPop() ? context.pop() : context.go(noteLocation(widget.id));

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Clear this conversation?'),
        content: const Text(
          'The Maester forgets it. Your note and its website stay as they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('note-chat-clear-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(noteChatProvider(widget.id).notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    // This page owns the chat's change request; leaving stops it.
    ref.watch(aiJobsProvider(noteChatScope(id)));
    final opened = ref.watch(noteDocumentProvider(id)).value;
    final note = opened?.available == true ? opened!.note : null;
    final website = ref.watch(noteWebsiteProvider(id)).value;
    final turns = ref.watch(noteChatTurnsProvider(id)).value ?? const [];
    final chat = ref.watch(noteChatProvider(id));
    final noteColor = NoteColors.fromBackground(
      Theme.of(context).colorScheme,
      note?.details.background ?? const {},
    ).background;
    return NoteAiPaletteScope(
      noteColor: noteColor,
      child: Builder(
        builder: (context) {
          final palette = NoteAiPalette.of(context);
          return Theme(
            data: palette.theme(Theme.of(context)),
            child: Builder(
              builder: (context) => Scaffold(
                appBar: _bar(context, note, website != null, turns.isNotEmpty),
                body: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: _conversation(
                          context,
                          turns: turns,
                          chat: chat,
                          note: note,
                          hasWebsite: website != null,
                        ),
                      ),
                      _Composer(
                        controller: _input,
                        focus: _focus,
                        sending: chat.sending,
                        onSend: () => _send(),
                        onStop: ref
                            .read(noteChatProvider(id).notifier)
                            .stopSending,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _bar(
    BuildContext context,
    NoteDocument? note,
    bool hasWebsite,
    bool hasTurns,
  ) {
    final theme = Theme.of(context);
    final title = note == null ? '' : noteTitle(note.text.title);
    final photos = note?.details.attachments.any((a) => a.isImage) ?? false;
    return AppBar(
      toolbarHeight: 64,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      leadingWidth: 60,
      leading: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: IconButton(
            tooltip: 'Back',
            style: noteBarButtonStyle(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _leave,
          ),
        ),
      ),
      titleSpacing: 8,
      title: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.4,
        child: Row(
          children: [
            Image.asset(
              'assets/branding/grand_maestar.png',
              width: 36,
              height: 36,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Maester',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (title.isNotEmpty)
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          key: const ValueKey('note-chat-menu'),
          tooltip: 'More',
          style: noteBarButtonStyle(context),
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (value) => switch (value) {
            'website' => context.push(noteWebsiteLocation(widget.id)),
            'photo' => showNoteAiTools(
              context,
              widget.id,
              initialTool: NoteAiTool.image,
              only: const {NoteAiTool.image},
            ),
            'clear' => _clear(),
            _ => null,
          },
          itemBuilder: (_) => [
            if (hasWebsite)
              const PopupMenuItem(
                value: 'website',
                child: ListTile(
                  leading: Icon(Icons.web_rounded),
                  title: Text('Open website'),
                ),
              ),
            if (photos)
              const PopupMenuItem(
                value: 'photo',
                child: ListTile(
                  leading: Icon(Icons.image_search_rounded),
                  title: Text('Explore a photo'),
                ),
              ),
            PopupMenuItem(
              key: const ValueKey('note-chat-clear'),
              value: 'clear',
              enabled: hasTurns,
              child: const ListTile(
                leading: Icon(Icons.delete_sweep_outlined),
                title: Text('Clear conversation'),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _conversation(
    BuildContext context, {
    required List<NoteChatTurn> turns,
    required NoteChatState chat,
    required NoteDocument? note,
    required bool hasWebsite,
  }) {
    final canEdit = ref.watch(syncCanEditProvider);
    final empty = note == null || note.text.body.trim().isEmpty;
    final latest = turns.isEmpty ? null : turns.last;
    final children = <Widget>[
      if (turns.isEmpty && !chat.sending)
        _Welcome(
          empty: empty,
          hasWebsite: hasWebsite,
          canEdit: canEdit,
          onPick: chat.sending ? null : (text) => _send(text),
        ),
      if (turns.length >= noteChatKeptTurns)
        const _Note(
          'The Maester keeps your last $noteChatKeptTurns exchanges on this device; older ones are forgotten.',
        ),
      for (final turn in turns) ...[
        NoteChatBubble(text: turn.ask, mine: true),
        if (turn.reply.isNotEmpty) _Reply(turn.reply),
        for (final action in turn.actions)
          NoteChatActionCard(
            key: ValueKey('note-chat-action-${action.call.id}'),
            noteId: widget.id,
            turn: turn,
            action: action,
            latest: identical(turn, latest),
            busy: chat.sending,
            onSend: (text) => _send(text),
          ),
      ],
      if (chat.pending case final pending?) ...[
        NoteChatBubble(text: pending, mine: true),
        const _Thinking(),
      ],
      if (chat.error case final error?)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              error,
              key: const ValueKey('note-chat-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
    ];
    // Reversed, so the newest stays in view above the message box.
    return ListView(
      key: const ValueKey('note-chat-list'),
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        for (final child in children.reversed)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: child),
      ],
    );
  }
}

/// What the Maester can do, before anything was said.
class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.empty,
    required this.hasWebsite,
    required this.canEdit,
    required this.onPick,
  });
  final bool empty, hasWebsite, canEdit;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ideas = <(String, IconData)>[
      if (empty) ...[
        ('Help me start this note', Icons.edit_note_rounded),
      ] else ...[
        ('Tidy and organise this note', Icons.format_list_bulleted_rounded),
        ('Fix grammar and clarity', Icons.spellcheck_rounded),
        ('Make it warmer and friendlier', Icons.sentiment_satisfied_rounded),
        if (canEdit && !hasWebsite)
          ('Turn this note into a website', Icons.web_rounded),
      ],
      if (canEdit && hasWebsite) ...[
        ('Give the website a darker look', Icons.dark_mode_outlined),
        ('Add a quiz to the website', Icons.quiz_outlined),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Image.asset(
            'assets/branding/grand_maestar.png',
            width: 72,
            height: 72,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          empty ? 'What shall this note be?' : 'How shall I help?',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasWebsite
              ? 'Ask me to improve the writing, or to change this note’s website. You review every change to your words.'
              : 'Ask me to improve the writing or turn it into a website. You review every change to your words.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (text, icon) in ideas)
              ActionChip(
                avatar: Icon(icon, size: 18),
                label: Text(text),
                onPressed: onPick == null ? null : () => onPick!(text),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

/// The Maester's words. Links and images in them do nothing.
class _Reply extends StatelessWidget {
  const _Reply(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: MarkdownBody(
        data: text,
        selectable: true,
        imageBuilder: (_, _, _) => const SizedBox.shrink(),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
      ),
    ),
  );
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final animate = RenderingPolicyScope.of(context).animate;
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      label: 'The Maester is thinking',
      child: Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: animate
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'The Maester is thinking…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.sending,
    required this.onSend,
    required this.onStop,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final bool sending;
  final VoidCallback onSend, onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('note-chat-input'),
                controller: controller,
                focusNode: focus,
                minLines: 1,
                maxLines: 5,
                maxLength: noteChatMessageChars,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => currentLength > maxLength! * .8
                    ? Text('$currentLength / $maxLength')
                    : null,
                decoration: const InputDecoration(
                  hintText: 'Ask the Maester…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: sending
                  ? IconButton.filledTonal(
                      key: const ValueKey('note-chat-stop'),
                      tooltip: 'Stop',
                      onPressed: onStop,
                      icon: const Icon(Icons.stop_rounded),
                    )
                  : ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => IconButton.filled(
                        key: const ValueKey('note-chat-send'),
                        tooltip: 'Send',
                        onPressed: controller.text.trim().isEmpty
                            ? null
                            : onSend,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
