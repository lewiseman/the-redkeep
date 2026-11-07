import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/application/ai_jobs.dart';
import '../../../ai/domain/ai_operation.dart';
import '../../application/note_ai_controller.dart';
import '../note_ai_loading.dart';
import '../note_ai_widgets.dart';

/// Quick changes to a kept website: a label, what is asked, and an icon.
const websiteRemixIdeas = [
  ('Darker', 'Give it a darker, moodier look', Icons.dark_mode_outlined),
  ('Lighter', 'Make it lighter and airier', Icons.light_mode_outlined),
  (
    'Add a quiz',
    'Add a short quiz from the page content, with a score',
    Icons.quiz_outlined,
  ),
  (
    'Timeline',
    'Turn the main content into an interactive timeline',
    Icons.timeline_rounded,
  ),
  (
    'Fix the chart',
    'Fix the chart so it is correct, readable and fits the screen',
    Icons.insights_rounded,
  ),
  (
    'Cook mode',
    'Add a step-by-step cook mode with timers and adjustable servings',
    Icons.restaurant_outlined,
  ),
  (
    'Add timers',
    'Add timers for anything that takes time, with a sound and a tap when done',
    Icons.timer_outlined,
  ),
  (
    'Track progress',
    'Add progress tracking that is remembered next time',
    Icons.donut_large_rounded,
  ),
  (
    'Bigger text',
    'Make the text larger and easier to read',
    Icons.format_size_rounded,
  ),
  (
    'More playful',
    'Make it more playful and colourful',
    Icons.celebration_outlined,
  ),
];

/// The outcome of the change sheet.
enum WebsiteChange { remixed, rebuild }

/// Changes a kept website. A remix edits the page as asked and keeps the
/// rest; "Build again" starts over from the note's text.
Future<WebsiteChange?> showWebsiteChangeSheet(
  BuildContext context,
  String id, {
  required bool outdated,
  required bool canEdit,
}) => showModalBottomSheet<WebsiteChange>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) =>
      _WebsiteChangeSheet(id: id, outdated: outdated, canEdit: canEdit),
);

class _WebsiteChangeSheet extends ConsumerStatefulWidget {
  const _WebsiteChangeSheet({
    required this.id,
    required this.outdated,
    required this.canEdit,
  });
  final String id;
  final bool outdated, canEdit;

  @override
  ConsumerState<_WebsiteChangeSheet> createState() =>
      _WebsiteChangeSheetState();
}

class _WebsiteChangeSheetState extends ConsumerState<_WebsiteChangeSheet> {
  final _instruction = TextEditingController();
  String? _error;
  bool _applying = false;

  /// This sheet owns the request: closing it cancels the remix.
  String get _scope => noteAiScope('remix', widget.id);

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _remix() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final actions = ref.read(noteAiControllerProvider);
    try {
      await actions.start(
        AiOperation.noteWebsiteRemix,
        widget.id,
        scope: _scope,
        intent: _instruction.text,
      );
      if (!mounted) return;
      final state = ref.read(aiJobsProvider(_scope));
      final job = state.job;
      if (job == null || job.phase != 'completed') {
        setState(
          () => _error =
              state.message ??
              'The remix did not finish. Your website is unchanged.',
        );
        return;
      }
      setState(() => _applying = true);
      await actions.apply(job, scope: _scope);
      if (mounted) Navigator.pop(context, WebsiteChange.remixed);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The remix could not be applied. Your website is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiJobsProvider(_scope));
    final working = state.busy || _applying;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          key: const ValueKey('note-website-change-sheet'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Change this website', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Remix keeps the design and changes only what you ask. You can undo it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (working)
              NoteAiLoading(
                tool: NoteAiTool.presentation,
                phase: _applying ? 'saving' : state.job?.phase ?? 'running',
                onCancel: _applying
                    ? null
                    : () => ref.read(aiJobsProvider(_scope).notifier).cancel(),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, ask, icon) in websiteRemixIdeas)
                    ChoiceChip(
                      avatar: Icon(icon, size: 20),
                      label: Text(label),
                      showCheckmark: false,
                      selected: _instruction.text == ask,
                      onSelected: widget.canEdit
                          ? (_) => setState(() => _instruction.text = ask)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('note-website-remix-instruction'),
                controller: _instruction,
                enabled: widget.canEdit,
                maxLength: 240,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Or describe a change',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              FilledButton.icon(
                key: const ValueKey('note-website-remix'),
                onPressed: widget.canEdit && _instruction.text.trim().isNotEmpty
                    ? _remix
                    : null,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('Remix'),
              ),
              const SizedBox(height: 12),
              const Divider(),
              ListTile(
                key: const ValueKey('note-website-rebuild'),
                enabled: widget.canEdit,
                contentPadding: EdgeInsets.zero,
                leading: Badge(
                  isLabelVisible: widget.outdated,
                  smallSize: 8,
                  child: const Icon(Icons.refresh_rounded),
                ),
                title: const Text('Build again from your text'),
                subtitle: Text(
                  widget.outdated
                      ? 'Your text changed since this website was made.'
                      : 'Starts a new website from the note.',
                ),
                onTap: () => Navigator.pop(context, WebsiteChange.rebuild),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
