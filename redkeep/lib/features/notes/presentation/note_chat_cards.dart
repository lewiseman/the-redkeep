import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../../core/presentation/rendering_policy.dart';
import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_job.dart';
import '../../ai/domain/ai_operation.dart';
import '../application/note_ai_sources.dart';
import '../application/note_chat_controller.dart';
import '../application/notes_providers.dart';
import '../domain/note_chat.dart';
import '../domain/note_chat_contract.dart';
import '../domain/note_document.dart';
import '../domain/note_help_contract.dart';
import '../domain/transform_contract.dart';
import 'note_ai_folio.dart';
import 'note_ai_loading.dart';
import 'note_ai_widgets.dart';

/// The person's own message.
class NoteChatBubble extends StatelessWidget {
  const NoteChatBubble({super.key, required this.text, required this.mine});
  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: mine ? scheme.primaryContainer : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SelectableText(
              text,
              style: TextStyle(
                color: mine ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tool call, drawn as the app's own card: choices to tap, a change
/// being made, a proposal to keep, or what came of it.
class NoteChatActionCard extends ConsumerStatefulWidget {
  const NoteChatActionCard({
    super.key,
    required this.noteId,
    required this.turn,
    required this.action,
    required this.latest,
    required this.busy,
    required this.onSend,
  });
  final String noteId;
  final NoteChatTurn turn;
  final NoteChatAction action;

  /// Choices can only be answered on the newest turn.
  final bool latest;

  /// A message is on its way.
  final bool busy;
  final ValueChanged<String> onSend;

  @override
  ConsumerState<NoteChatActionCard> createState() => _NoteChatActionCardState();
}

class _NoteChatActionCardState extends ConsumerState<NoteChatActionCard> {
  bool _working = false;

  /// The compare wipe: one shows the proposal, zero the original.
  double _split = 1;

  NoteChatController get _chat =>
      ref.read(noteChatProvider(widget.noteId).notifier);

  Future<void> _do(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(aiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  ({String title, IconData icon, NoteAiTool tool, String? quote}) get _what {
    final args = widget.action.call.arguments;
    String? text(String key) {
      final value = args[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return switch (widget.action.call.name) {
      NoteChatTools.editNote => (
        title:
            NoteChatTools.editOperations[args['operation']]?.label ??
            'Writing help',
        icon: Icons.edit_note_rounded,
        tool: NoteAiTool.writing,
        quote: text('instruction'),
      ),
      NoteChatTools.draftNote => (
        title: 'Draft the note',
        icon: Icons.post_add_rounded,
        tool: NoteAiTool.template,
        quote: text('idea'),
      ),
      NoteChatTools.buildWebsite => (
        title: 'Build the website',
        icon: Icons.web_rounded,
        tool: NoteAiTool.presentation,
        quote: text('brief'),
      ),
      NoteChatTools.updateWebsite => (
        title: 'Change the website',
        icon: Icons.auto_fix_high_rounded,
        tool: NoteAiTool.presentation,
        quote: text('instruction'),
      ),
      _ => (
        title: 'Maester',
        icon: Icons.auto_awesome_rounded,
        tool: NoteAiTool.writing,
        quote: null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    if (action.call.name == NoteChatTools.offerChoices) return _choices();
    // Watching keeps the card in step with its request.
    final jobs = ref.watch(aiJobsProvider(noteChatScope(widget.noteId)));
    final what = _what;
    final theme = Theme.of(context);
    final running =
        action.status == NoteChatActionStatus.running &&
        jobs.busy &&
        jobs.job?.key == widget.noteId;
    final proposal = action.status == NoteChatActionStatus.ready
        ? _chat.proposal(action)
        : null;
    final website =
        action.call.name == NoteChatTools.buildWebsite ||
        action.call.name == NoteChatTools.updateWebsite;
    return Card(
      key: ValueKey('note-chat-card-${action.status.name}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(what.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    what.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (what.quote case final quote?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '“$quote”',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            ...switch (action.status) {
              NoteChatActionStatus.running when running => _running(
                what.tool,
                jobs.job!,
              ),
              NoteChatActionStatus.ready when proposal != null => _proposal(
                proposal,
              ),
              NoteChatActionStatus.running || NoteChatActionStatus.ready => [
                _status('Set aside. Ask again to make it.', Icons.history),
              ],
              NoteChatActionStatus.kept when website => _websiteKept(),
              NoteChatActionStatus.kept => [
                _status('Kept in your note.', Icons.check_circle_outline),
                if (widget.latest)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const ValueKey('note-chat-view-note'),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(noteLocation(widget.noteId)),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('View note'),
                    ),
                  ),
              ],
              NoteChatActionStatus.discarded => [
                _status(
                  action.detail.isEmpty ? 'Discarded.' : action.detail,
                  Icons.remove_circle_outline,
                ),
              ],
              NoteChatActionStatus.stopped => [
                _status(
                  'Stopped. Nothing changed.',
                  Icons.stop_circle_outlined,
                ),
              ],
              NoteChatActionStatus.failed => [
                _status(
                  action.detail.isEmpty
                      ? 'The Maester could not finish. Nothing changed.'
                      : action.detail,
                  Icons.error_outline,
                  error: true,
                ),
                if (widget.latest)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: widget.busy
                          ? null
                          : () => widget.onSend(widget.turn.ask),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Ask again'),
                    ),
                  ),
              ],
              NoteChatActionStatus.skipped || NoteChatActionStatus.shown => [
                _status(
                  action.detail.isEmpty ? 'Not made.' : action.detail,
                  Icons.info_outline,
                ),
              ],
            },
          ],
        ),
      ),
    );
  }

  Widget _status(String text, IconData icon, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.onSurfaceVariant;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  List<Widget> _running(NoteAiTool tool, AiJob job) {
    final animate = RenderingPolicyScope.of(context).animate;
    return [
      if (animate) const LinearProgressIndicator(),
      const SizedBox(height: 8),
      Semantics(
        liveRegion: true,
        child: Text(noteAiPhaseTitle(tool, job.phase)),
      ),
      if (tool == NoteAiTool.presentation)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'A website can take a few minutes. Stay on this page.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: const ValueKey('note-chat-stop-change'),
          onPressed: _chat.stop,
          icon: const Icon(Icons.stop_rounded, size: 20),
          label: const Text('Stop'),
        ),
      ),
    ];
  }

  List<Widget> _proposal(AiJob job) {
    final note = ref.watch(noteDocumentProvider(widget.noteId)).value?.note;
    final details = note?.details ?? const NoteDetails();
    final Widget page;
    TransformSource? range;
    try {
      final source = noteTaskSource(job.source);
      range = source['range'] is String
          ? TransformSource.decode(source['range'] as String)
          : null;
      if (job.operation == AiOperation.noteDraft) {
        final draft = NoteTemplate.parse(
          job.text!,
          bodyBytes: noteDraftBodyBytes,
          lines: noteDraftLines,
        );
        page = NoteFolioPage(
          title: draft.title,
          body: draft.body,
          bodyLines: 12,
        );
      } else {
        page = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              noteTitle(note?.text.title ?? ''),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            if (range == null)
              NoteFolioText(job.text!, lines: 14)
            else
              NoteFolioCompare(
                key: const ValueKey('note-chat-compare'),
                before: range.selected,
                after: job.text!,
                split: _split,
                onChanged: (v) => setState(() => _split = v),
              ),
          ],
        );
      }
    } on FormatException {
      return [_status('This proposal could not be read.', Icons.error_outline)];
    }
    return [
      NoteFolio(details: details, status: 'Proposal', child: page),
      if (range != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => setState(() => _split = _split > .5 ? 0 : 1),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text(_split > .5 ? 'Show original' : 'Show proposal'),
          ),
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          TextButton(
            key: const ValueKey('note-chat-discard'),
            onPressed: _working
                ? null
                : () => _do(() => _chat.discard(widget.turn, widget.action)),
            child: const Text('Discard'),
          ),
          FilledButton.icon(
            key: const ValueKey('note-chat-keep'),
            onPressed: _working
                ? null
                : () => _do(() => _chat.keep(widget.turn, widget.action)),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Keep in note'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _websiteKept() {
    final page = ref.watch(noteWebsiteProvider(widget.noteId)).value;
    return [
      _status(
        widget.action.call.name == NoteChatTools.buildWebsite
            ? 'Website built.'
            : 'Website changed.',
        Icons.check_circle_outline,
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (page != null)
            FilledButton.tonalIcon(
              key: const ValueKey('note-chat-open-website'),
              onPressed: () => context.push(noteWebsiteLocation(widget.noteId)),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open website'),
            ),
          if (widget.latest && page != null && page.canUndo)
            TextButton.icon(
              key: const ValueKey('note-chat-undo-website'),
              onPressed: _working
                  ? null
                  : () => _do(() async {
                      if (!await _chat.undoWebsite()) {
                        throw const FormatException('Nothing to undo.');
                      }
                    }),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Undo'),
            ),
        ],
      ),
    ];
  }

  Widget _choices() {
    final args = widget.action.call.arguments;
    final question = args['question'] is String
        ? (args['question'] as String).trim()
        : '';
    final options = [
      for (final o in args['options'] is List ? args['options'] as List : [])
        if (o is String && o.trim().isNotEmpty) o.trim(),
    ];
    final open = widget.latest && !widget.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              question,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, option) in options.indexed)
              ActionChip(
                key: ValueKey('note-chat-choice-$i'),
                label: Text(option),
                onPressed: open ? () => widget.onSend(option) : null,
              ),
          ],
        ),
      ],
    );
  }
}
